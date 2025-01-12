# ⚠️ WARNING: EXPERIMENTAL PROJECT

**THIS IS AN EXPERIMENTAL PROJECT - USE AT YOUR OWN RISK**

This project is in an experimental state and has not been extensively tested. It can potentially execute harmful commands on your system if used incorrectly. By using this plugin, you acknowledge that:

- The AI may suggest commands that could damage your system
- Command execution is done with your user privileges
- You should always review suggested commands before execution
- No warranty or liability is provided (see LICENSE)

If you're not comfortable with these risks, please do not use this plugin.

---

# AI-ZSH

An AI-powered ZSH plugin that enhances your terminal experience with natural language AI assistance.

## Features

- Special mode trigger with `]` key
- AI-powered command suggestions and explanations
- Syntax-highlighted code blocks with execution options
- Seamless integration with OpenRouter AI API
- Smart context awareness of your system environment

## Prerequisites

- Zsh shell
- curl
- jq
- An OpenRouter API key

## Installation

1. Clone this repository:
```bash
git clone https://github.com/yourusername/aizsh.git ~/.aizsh
```

2. Create the configuration file:
```bash
mkdir -p ~/.config
touch ~/.config/aizsh.env
```

3. Add your OpenRouter API configuration to `~/.config/aizsh.env`:
```bash
export OPENROUTER_API_KEY="your-api-key"
export OPENROUTER_MODEL="your-preferred-model"
```

4. Add the following to your `~/.zshrc`:
```bash
source "~/.aizsh/ai.zsh"
```

5. Restart your terminal or run:
```bash
source ~/.zshrc
```

## Usage

1. Press `]` at an empty prompt to enter special mode (indicated by ✨)
2. Type your question or command description
3. Press Enter to get AI assistance
4. Choose whether to execute suggested commands:
   - Single code block: Press Y to execute
   - Multiple blocks: Choose block number to execute
   - Press N to skip execution

## Examples

- Get command suggestions: `] how to find large files`
- System tasks: `] setup a cron job to clean temp files daily`
- Explanations: `] explain what this command does: lsof -i :8080`

## Configuration

The plugin uses OpenRouter API for AI capabilities. You can configure:

- `OPENROUTER_API_KEY`: Your OpenRouter API key
- `OPENROUTER_MODEL`: The AI model to use (e.g., "openai/gpt-3.5-turbo")

## License

MIT License