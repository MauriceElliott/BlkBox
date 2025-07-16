# BlkBox LLM Integration Guide

BlkBox now supports both local and remote LLM (Large Language Model) integrations, giving you flexibility in how you interact with AI models. This guide explains how to set up and use each option.

## LLM Integration Options

### Option 1: Local LLM with Ollama (Default)

BlkBox uses [Ollama](https://ollama.ai/) as the default local LLM service. This option:
- Runs models locally on your machine
- Provides privacy (no data sent to external services)
- Works offline
- Has no usage costs

#### Setup for Local LLM

1. Install Ollama from [https://ollama.ai/download](https://ollama.ai/download)
2. Start Ollama:
   ```bash
   ollama serve
   ```
3. Pull the default model:
   ```bash
   ollama pull llama3
   ```
4. Run BlkBox without any special flags (it defaults to local mode)

### Option 2: Remote LLM with OpenAI API

For more powerful capabilities or if your local hardware can't run models efficiently, you can connect to OpenAI's API:
- Access to powerful models like GPT-3.5 and GPT-4
- No local hardware requirements
- Faster responses on less powerful hardware
- Enhanced capabilities

#### Setup for Remote LLM

1. Create an [OpenAI API account](https://platform.openai.com/) and get an API key
2. Set your API key using one of these methods:
   - Environment variable: `export OPENAI_API_KEY="your-api-key"`
   - Configuration command: `blkbox configure --api-key "your-api-key"`
   - Pass directly via command: `blkbox shell --remote --api-key "your-api-key"`

## Using Different LLM Options

### Command Line Flags

Use `--remote` to use the remote OpenAI service:
```bash
blkbox shell --remote
blkbox add --remote "This is my note"
blkbox find --remote "search query"
blkbox summarize --remote
```

### Configuration

Configure your preferred LLM service as the default:

```bash
# Set service type (local or remote)
blkbox configure --service remote

# Set API key for remote services
blkbox configure --api-key "your-api-key"

# Set default model
blkbox configure --model "gpt-3.5-turbo"  # for remote
blkbox configure --model "llama3"         # for local

# Set timeout (useful for slower local machines)
blkbox configure --timeout 1200  # 20 minutes

# Show current configuration
blkbox configure --show
```

### Available Models

#### Local Models (Ollama)
- llama3 (default)
- llama3:8b
- llama3:70b
- mistral
- codellama
- And [many more](https://ollama.ai/library)

#### Remote Models (OpenAI)
- gpt-3.5-turbo (default)
- gpt-4
- gpt-4-turbo
- And [other OpenAI models](https://platform.openai.com/docs/models)

## Troubleshooting

### Local LLM Issues

- **Timeouts**: If your machine is slower, increase the timeout: `blkbox configure --timeout 1800` (30 minutes)
- **Memory issues**: Try a smaller model like `llama3:8b` with `blkbox configure --model llama3:8b`
- **Connection errors**: Ensure Ollama is running with `ollama serve`

### Remote LLM Issues

- **API Key errors**: Check that your API key is correctly set
- **Quota exceeded**: Check your OpenAI account for usage limits or billing issues
- **Connection errors**: Ensure you have an active internet connection

## Advanced Configuration

The configuration is stored in `~/.blkbox/config.json` and can be edited directly if needed, though using the `configure` command is recommended.

## Best Practices

- **Local Development**: Use local LLM for regular use and development
- **Important Tasks**: Switch to remote LLM for critical analyses or when you need the most accurate responses
- **Low-Power Devices**: Use remote LLM on devices with limited resources
- **Privacy-Sensitive Data**: Use local LLM when working with confidential information
