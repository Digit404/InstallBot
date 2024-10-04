# InstallBot

InstallBot is an intelligent PowerShell-based installer that uses OpenAI's GPT model to perform various installation and file-related tasks. It's designed to be flexible, efficient, and capable of handling a wide range of installation scenarios.

## Features

- AI-powered file manipulation and system operations
- Safe mode for command execution approval
- Customizable system messages and instructions
- Logging of executed commands

## Prerequisites

- PowerShell 5.1 or later
- OpenAI API key

## Setup

1. Set the `OPENAI_API_KEY` environment variable with your OpenAI API key.
2. (Optional) Create an `instructions.txt` file in the same directory as the script to provide additional instructions to the AI.
3. (Optional) Works best when added as an alias to your PSProfile.

## Usage

```powershell
.\InstallBot.ps1 -file <path_to_file> [-SafeMode] [-action <action_description>]
```

### Example

```powershell
.\InstallBot.ps1 -file ".\audacity-win-3.6.4-64bit.zip" -SafeMode -action "install to .\audacity"
```

### Parameters

- `-file`: (Mandatory) Path to the file to be processed. It can also be a url to file on the internet.
- `-SafeMode`: (Optional) If specified, prompts for user approval before executing commands.
- `-action`: (Optional) Description of the action to be performed. Defaults to "install (default)".

## Safety Considerations

- Use the `-SafeMode` parameter to review and approve commands before execution.
- The script logs all executed commands for review.

## Customization

- Modify the `$SYSTEM_MESSAGE` variable to change the AI's base instructions.
- Add an `instructions.txt` file for additional context-specific instructions, such as default installation locations.

## Disclaimer

This script executes commands based on AI-generated instructions. Use with caution and always review the actions being performed, especially in production environments.
