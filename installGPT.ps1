param (
    [string]$file,
    [string]$action
)

$MODEL = "gpt-4o-mini"
$SYSTEM_MESSAGE = @'
Your task is to perform the specified action on the provided file using PowerShell. Take as many turns as you need. Make educated assumptions about the intended outcome, even if it requires taking some risks. Ensure that you keep your workspace tidy by using the Temp folder effectively, and make sure to clean up after you're done. Write efficient and smart PowerShell code, avoiding multiple commands in place of one if achievable. Here's an example of an effective command:

$tempPath = (New-Item -Path (Join-Path $env:TEMP "file") -ItemType Directory -Force).FullName
Expand-Archive -Path .\file.zip -DestinationPath $tempPath `
&& Get-ChildItem -Path $tempPath -Recurse -File | ForEach-Object { $_.FullName }

Once the task is complete, and you've confirmed that everything is as it should be, as much as reasonable, communicate to the user by sending an exit message using the exit command.
'@
$OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

$key = $env:OPENAI_API_KEY

if (!$key) {
    Write-Host "Please set the OPENAI_API_KEY environment variable"
    exit
}

class Tool {
    [string]$name;
    [string]$description;
    [pscustomobject]$properties;

    static [System.Collections.Generic.List[Tool]] $tools = @();

    Tool ($name, $description, $properties) {
        $this.name = $name;
        $this.description = $description;
        $this.properties = $properties;

        [Tool]::tools.Add($this);
    }

    [hashtable] getObject() {
        $object = @{
            type     = "function";
            function = @{
                name        = $this.name;
                description = $this.description;
                parameters  = @{
                    type                 = "object";
                    properties           = $this.properties;
                    additionalProperties = $false;
                }
            }
        }

        return $object;
    }

    static [array] getTools() {
        $toolList = @();
        foreach ($tool in [Tool]::tools) {
            $toolList += $tool.getObject();
        }

        return $toolList;
    }
}

[Tool]::new(
    "command", 
    "Executes a command in PowerShell and returns the result.", 
    [PSCustomObject]@{
        command = @{
            type        = "string";
            description = "A valid PowerShell command to execute.";
        }
    }) | Out-Null

[Tool]::new(
    "exit",
    "Exits the interaction with a message.", 
    [PSCustomObject]@{
        message = @{
            type        = "string";
            description = "A message to display upon exiting the interaction.";
        }
    }) | Out-Null

[Tool]::new(
    "error",
    "Exits the interaction due to an error.", 
    [PSCustomObject]@{
        message = @{
            type        = "string";
            description = "A message to display upon exiting the interaction due to an error.";
        }
    }) | Out-Null

[Tool]::new(
    "query",
    "Asks the user a question. Should only be used if absolutely necessary.", 
    [PSCustomObject]@{
        message = @{
            type        = "string";
            description = "A question to ask the user.";
        }
    }) | Out-Null

# prepare messages array
$messages = @(
    @{
        role    = "system";
        content = $SYSTEM_MESSAGE;
    },
    @{
        role    = "user";
        content = @(
            @{
                text = "File: $file`nRequested action: $action";
                type = "text";
            }
        );
    }
)

$finished = $false

# main loop
do {
    $body = @{
        model               = $MODEL;
        messages            = $messages;
        tools               = [Tool]::getTools();
        parallel_tool_calls = $true;
    }

    $bodyJson = $body | ConvertTo-Json -Depth 20

    # query the OpenAI API
    try {
        $response = Invoke-RestMethod -Uri $OPENAI_CHAT_URL -Method Post -Headers @{ 'Content-Type' = 'application/json'; 'Authorization' = "Bearer $key" } -Body $bodyJson
    }
    catch {
        Write-Error "Failed to call OpenAI API: $_"
        exit
    }

    $reply = $response.choices[0].message

    # add the assistant's reply to messages (even if content is null)
    $messages += $reply

    # check if the assistant wants to call a function/tool (tool_calls)
    if ($reply.tool_calls) {
        foreach ($tool_call in $reply.tool_calls) {
            $functionName = $tool_call.function.name
            $arguments = ($tool_call.function.arguments | ConvertFrom-Json)
            $tool_call_id = $tool_call.id

            # handle the function call
            switch ($functionName) {
                "command" {
                    # execute the command and capture the output to give to the bot
                    try {
                        $commandResult = Invoke-Expression -Command $arguments.command
                        $commandOutput = $commandResult | Out-String
                    }
                    catch {
                        $commandOutput = $_.Exception.Message
                    }

                    # add the function result to messages
                    $messages += @{
                        role         = 'tool';
                        content      = @(
                            @{
                                text = $commandOutput;
                                type = 'text'
                            }
                        );
                        tool_call_id = $tool_call_id
                    }
                }
                "exit" {
                    # display the exit message and exit the loop
                    Write-Host $arguments.message
                    $finished = $true
                    break
                }
                "error" {
                    # bot fucked up
                    Write-Error $arguments.message
                    $finished = $true
                    break
                }
                "query" {
                    # ask the user a question and get input
                    $userResponse = Read-Host $arguments.message

                    # add the function result to messages as a 'tool' message
                    $messages += @{
                        role         = 'tool';
                        content      = @(
                            @{
                                text = $userResponse;
                                type = 'text'
                            }
                        );
                        tool_call_id = $tool_call_id
                    }
                }
                default {
                    Write-Error "Unknown function: $functionName"
                    $finished = $true
                    break
                }
            }
        }
    }
    else {
        # if the assistant provides a regular reply
        if ($reply.content) {
            # display the assistant's message
            foreach ($part in $reply.content) {
                if ($part.type -eq 'text') {
                    Write-Host $part.text
                }
            }

            # check if the assistant indicates the end of the interaction
            if ($reply.role -eq 'assistant' -and $reply.content -match 'exit') {
                $finished = $true
            }
        }
    }

    # check if we should exit the loop
    if ($finished) {
        break
    }

} while ($true)