# BlkBox

A Swift CLI tool that helps you rediscover yourself through the notes that you've curated over your lifetime, powered by both local and remote LLMs.

## Overview

BlkBox is a command-line interface tool that serves as a personal knowledge manager and insight generator. It functions as an interface between you and your notes collection (often called a "second brain"), allowing you to:

- **Generate insights** from your existing notes
- **Add new notes** with automatic categorization
- **Retrieve information** based on search queries
- **Organize knowledge** without needing to manually manage files
- **Choose your LLM** with support for both local (Ollama) and remote (OpenAI) services

BlkBox leverages the power of LLMs to analyze and process your notes, providing a natural language interface to your personal knowledge base. Use local LLMs for privacy or remote services for better performance.

## Installation

### Prerequisites

- macOS 12.0 or later
- Swift 5.9 or later
- One of the following:
  - [Ollama](https://ollama.ai) with a compatible model (default: llama3) for local processing
  - OpenAI API key for remote processing

### Building from Source

```bash
git clone https://github.com/yourusername/BlkBox.git
cd BlkBox
swift build -c release
cp -f .build/release/blkbox /usr/local/bin/blkbox
```

## Usage

### Interactive Shell Mode

```bash
blkbox
```

This launches the BlkBox shell, where you can interact with your notes using natural language commands.

### Direct Commands

```bash
# Generate insights from your notes
blkbox summarize [--topic "topic"] [--limit 5] [--remote] [--api-key "your-api-key"]

# Add a new note
blkbox add "This is my note content" [--remote] [--api-key "your-api-key"]
blkbox add --file path/to/note.md

# Search your notes
blkbox retrieve "search query" [--remote] [--api-key "your-api-key"]
blkbox retrieve --type "todo" "groceries"

# Configure LLM settings
blkbox configure --service remote --api-key "your-api-key"
blkbox configure --service local --model "llama3"
blkbox configure --timeout 1200
blkbox configure --show
blkbox configure --test
```

## Configuration

BlkBox stores its configuration in `~/.blkbox/config.json`. You can edit this file directly or use the `configure` command to update settings.

Default configuration:

- Notes stored in `~/.blkbox/notes`
- Uses Ollama with the llama3 model (local LLM)
- Supports markdown (.md) and text (.txt) files
- 10-minute timeout for LLM responses

## LLM Integration

BlkBox supports two modes of LLM integration:

### Local LLM (Default)

- Uses Ollama to run models locally on your machine
- Complete privacy (no data leaves your computer)
- Works offline
- No usage costs
- May require more powerful hardware

### Remote LLM (OpenAI)

- Uses OpenAI's API for powerful models like GPT-3.5 and GPT-4
- Better performance on less powerful hardware
- Enhanced capabilities
- Requires internet connection and API key
- Has associated costs

See `LLM_INTEGRATION_GUIDE.md` for detailed setup instructions.

## System Prompt

BlkBox uses a specialized system prompt to guide the LLM's behavior when processing your notes. This prompt emphasizes:

1. Finding meaningful connections across notes
2. Organizing content logically
3. Retrieving relevant information
4. Providing consistent responses regardless of LLM provider

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
