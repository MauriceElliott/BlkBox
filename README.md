# BlkBox

A Swift CLI tool that helps you rediscover yourself through the notes that you've curated over your lifetime.

## Overview

BlkBox is a command-line interface tool that serves as a personal knowledge manager and insight generator. It functions as an interface between you and your notes collection (often called a "second brain"), allowing you to:

- **Generate insights** from your existing notes
- **Add new notes** with automatic categorization
- **Retrieve information** based on search queries
- **Organize knowledge** without needing to manually manage files

BlkBox leverages the power of local LLMs (like Ollama) to analyze and process your notes, providing a natural language interface to your personal knowledge base.

## Installation

### Prerequisites

- macOS 12.0 or later
- Swift 5.9 or later
- [Ollama](https://ollama.ai) with a compatible model (default: llama3)

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
blkbox summarize [--topic "topic"] [--limit 5]

# Add a new note
blkbox add "This is my note content"
blkbox add --file path/to/note.md

# Search your notes
blkbox retrieve "search query"
blkbox retrieve --type "todo" "groceries"
```

## Configuration

BlkBox stores its configuration in `~/.blkbox/config.yml`. You can edit this file directly or use the interactive shell to update settings.

Default configuration:

- Notes stored in `~/.blkbox/notes`
- Uses Ollama with the llama3 model
- Supports markdown (.md) and text (.txt) files

## System Prompt

BlkBox uses a specialized system prompt to guide the LLM's behavior when processing your notes. This prompt emphasizes:

1. Finding meaningful connections across notes
2. Organizing content logically
3. Retrieving relevant information
4. Respecting privacy by keeping all processing local

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
