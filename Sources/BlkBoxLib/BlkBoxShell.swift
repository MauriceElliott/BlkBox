import Foundation
import Rainbow

/// Interactive shell for BlkBox
public class BlkBoxShell {
    private let notesManager: NotesManager
    private let llmService: LLMServiceProtocol
    private var isRunning = false

    public init(notesPath: String? = nil, useRemoteLLM: Bool = false, apiKey: String? = nil) {
        self.notesManager = NotesManager(path: notesPath)

        if useRemoteLLM {
            // When explicitly using remote LLM, use a compatible model (GPT)
            self.llmService = LLMServiceFactory.createRemoteService(
                apiKey: apiKey,
                modelName: "gpt-3.5-turbo"
            )
        } else {
            // Use configuration-based service creation by default
            self.llmService = LLMServiceFactory.createFromConfig(apiKey: apiKey)
        }
    }

    /// Start the interactive shell
    public func start() {
        isRunning = true

        // Check if LLM service is available
        if !llmService.isAvailable() {
            print("⚠️  ".yellow.bold + "Warning: Unable to connect to LLM service")

            if llmService is LLMService {
                print("Make sure Ollama is running locally (http://localhost:11434)".yellow)
                print("To install Ollama: https://ollama.ai/download".yellow)
                print("After installing, run 'ollama serve' in a separate terminal window".yellow)
            } else if llmService is RemoteLLMService {
                print("Make sure your internet connection and API key are valid".yellow)
            }

            print("\nYou can:")
            print("1. Try again after starting Ollama".yellow)
            print("2. Use '--remote' flag with an API key to use OpenAI instead".yellow)
            print("3. Continue in limited mode (some features won't work)\n".yellow)

            // Ask if they want to continue
            print("Continue in limited mode? [Y/n] ", terminator: "")
            if let response = readLine()?.lowercased(), response == "n" {
                print("Exiting BlkBox. Please start Ollama and try again.")
                isRunning = false
                return
            }

            print("Continuing in limited mode...\n".yellow)
        } else {
            // Check if the model is available
            if !llmService.isModelAvailable() {
                print("⚠️  ".yellow.bold + "Warning: Model '\(llmService.modelName)' may not be available")

                if llmService is LLMService {
                    print("To install the model, run this command:".yellow)
                    print("  ollama pull \(llmService.modelName)".yellow.bold)
                } else if llmService is RemoteLLMService {
                    print("Make sure you're using a valid model name for the API".yellow)
                    print("Valid models include: gpt-3.5-turbo, gpt-4".yellow)
                }

                print("Continuing, but LLM features may not work correctly...\n".yellow)
            } else {
                if llmService is LLMService {
                    print("✅ Connected to Ollama with model: \(llmService.modelName)".green)
                } else if llmService is RemoteLLMService {
                    print("✅ Connected to OpenAI API with model: \(llmService.modelName)".green)
                }
            }
        }

        while isRunning {
            // Display prompt
            print("blkbox> ".blue.bold, terminator: "")

            // Read command
            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                break
            }

            // Process command
            processCommand(input)
        }

        print("\nThank you for using BlkBox! Goodbye. 👋")
    }

    /// Process a shell command
    private func processCommand(_ input: String) {
        // Skip empty commands
        guard !input.isEmpty else { return }

        // Split the input into command and arguments
        let components = input.components(separatedBy: .whitespaces)
        let command = components[0]
        let args = Array(components.dropFirst())

        switch command {
        case "exit", "quit":
            isRunning = false

        case "help":
            displayHelp()

        case "insights":
            generateInsights(args: args)

        case "note":
            addNote(args: args)

        case "find":
            findNotes(args: args)

        case "list":
            listCategories()

        case "status":
            showStatus()

        case "llm":
            showLLMInfo()

        case "models":
            manageModels(args: args)

        default:
            // Pass to LLM for interpretation
            handleUnknownCommand(command: command, args: args, fullInput: input)
        }
    }

    // MARK: - Command Handlers

    private func displayHelp() {
        print("\n" + "AVAILABLE COMMANDS".green.bold)
        print("═════════════════".green)
        print("  help".blue.bold + "                 Show this help message")
        print("  insights".blue.bold + " [topic]      Generate insights from your notes")
        print("  note".blue.bold + " [content]        Add a new note (opens input mode if no content provided)")
        print("  find".blue.bold + " <query>          Search for notes matching the query")
        print("  list".blue.bold + "                  List note categories and counts")
        print("  status".blue.bold + "                Show system status")
        print("  llm".blue.bold + "                   Show LLM service information")
        print("  models".blue.bold + " [pull|list]    Manage available LLM models")
        print("  exit".blue.bold + "                  Exit BlkBox shell")
        print("\nFor any command, you can type a question or request and BlkBox will try to help.\n")
    }

    private func generateInsights(args: [String]) {
        do {
            // Check if LLM is available before proceeding
            if !llmService.isAvailable() {
                print("❌ ".red.bold + "Error: LLM service is not available")

                if llmService is LLMService {
                    print("To use Ollama:".yellow)
                    print("1. Make sure Ollama is installed (https://ollama.ai/download)".yellow)
                    print("2. Run 'ollama serve' in a separate terminal".yellow)
                    print("3. Try again after Ollama is running".yellow)
                } else {
                    print("Check your internet connection and API key.".yellow)
                }
                return
            }

            // Check if the model is available
            if !llmService.isModelAvailable() {
                print("❌ ".red.bold + "Error: Model '\(llmService.modelName)' is not available")

                if llmService is LLMService {
                    print("To install the model:".yellow)
                    print("  ollama pull \(llmService.modelName)".yellow.bold)
                } else {
                    print("Make sure you're using a valid model name for the API.".yellow)
                }
                return
            }

            let topic = args.isEmpty ? nil : args.joined(separator: " ")

            print("🔍 ".blue.bold + "Analyzing your notes...")
            let insights = try notesManager.generateInsights(usingLLM: llmService, topic: topic, limit: 5)

            print("\n" + "📊 INSIGHTS".green.bold)
            print("═════════════".green)

            if insights.isEmpty {
                print("No insights were found. This might happen if your notes collection is empty or very small.".yellow)
            } else {
                for (index, insight) in insights.enumerated() {
                    print("[\(index+1)] ".blue.bold + insight)
                    if index < insights.count - 1 {
                        print("---")
                    }
                }
            }
            print("")

        } catch let llmError as LLMError {
            print("❌ ".red.bold + "Error: \(llmError)".red)

            // Handle specific LLM errors
            switch llmError {
            case .connectionFailed:
                if llmService is LLMService {
                    print("\nTo fix:".yellow)
                    print("1. Make sure Ollama is running with 'ollama serve'".yellow)
                    print("2. Check that you can access http://localhost:11434 in your browser".yellow)
                } else {
                    print("\nTo fix:".yellow)
                    print("1. Check your internet connection".yellow)
                    print("2. Verify your API key is correct".yellow)
                }
            case .modelNotAvailable:
                if llmService is LLMService {
                    print("\nTo fix:".yellow)
                    print("  Run: ollama pull \(llmService.modelName)".yellow.bold)
                } else {
                    print("\nTo fix:".yellow)
                    print("  Use a valid OpenAI model like 'gpt-3.5-turbo'".yellow)
                    print("  Run: blkbox configure -m gpt-3.5-turbo".yellow)
                }
            case .timeoutError:
                print("\nThe request timed out. This could happen because:".yellow)
                print("1. Your hardware is too slow for this model".yellow)
                print("2. The model is still loading (first run can be slow)".yellow)
                print("\nTo fix:".yellow)
                print("1. Try a smaller model or increase the timeout:".yellow)
                print("   blkbox configure --timeout 1800  # 30 minutes".yellow)
                print("2. Use the remote API instead:".yellow)
                print("   blkbox shell --remote --api-key YOUR_API_KEY".yellow)
            default:
                print("Try running 'status' or 'llm' to check if the LLM service is working properly.".yellow)
            }
        } catch {
            print("❌ ".red.bold + "Error generating insights: \(error.localizedDescription)".red)
            print("Try running 'status' or 'llm' to check if the LLM service is working properly.".yellow)
        }
    }

    private func addNote(args: [String]) {
        // Check if LLM is available before proceeding
        if !llmService.isAvailable() {
            print("⚠️ ".yellow.bold + "Warning: LLM service is not available")
            print("Your note will be saved, but won't be categorized properly.".yellow)
        }

        // If no arguments, enter interactive mode
        if args.isEmpty {
            print("Enter your note (press Ctrl+D when finished):")
            if let content = readMultilineInput(), !content.isEmpty {
                saveNote(content)
            } else {
                print("Note cancelled - no content provided.".yellow)
            }
        } else {
            // Use arguments as note content
            let content = args.joined(separator: " ")
            saveNote(content)
        }
    }

    private func saveNote(_ content: String) {
        do {
            print("📝 ".blue.bold + "Processing your note...")
            try notesManager.addNote(content: content, usingLLM: llmService)
            print("✅ ".green.bold + "Note added successfully!")
        } catch let llmError as LLMError {
            print("⚠️ ".yellow.bold + "Warning: \(llmError)".yellow)
            print("Trying to save note with default categorization...".yellow)

            // Fallback to basic note saving without LLM categorization
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: Date())
                let filePath = "unsorted/note-\(dateString).md"
                let fullPath = "\(notesManager.notesPath)/\(filePath)"

                // Create directory
                let directoryPath = (fullPath as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(
                    atPath: directoryPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                // Format content with timestamp
                let formattedContent = "# Note from \(dateString)\n\n\(content)"

                // Write to file
                try formattedContent.write(toFile: fullPath, atomically: true, encoding: .utf8)
                print("✅ ".green.bold + "Note saved without categorization.")
            } catch {
                print("❌ ".red.bold + "Error saving note: \(error.localizedDescription)".red)
            }
        } catch {
            print("❌ ".red.bold + "Error adding note: \(error.localizedDescription)".red)
        }
    }

    private func findNotes(args: [String]) {
        guard !args.isEmpty else {
            print("Please provide a search query.".yellow)
            return
        }

        // Check if LLM is available before proceeding
        if !llmService.isAvailable() {
            print("❌ ".red.bold + "Error: LLM service is not available")
            print("Make sure Ollama is running with your model installed.".yellow)
            return
        }

        let query = args.joined(separator: " ")

        do {
            print("🔍 ".blue.bold + "Searching your notes...")
            let results = try notesManager.retrieveNotes(query: query, usingLLM: llmService)

            if results.isEmpty {
                print("No matching notes found.".yellow)
                return
            }

            print("\n" + "📄 SEARCH RESULTS".green.bold)
            print("═══════════════════".green)

            for (index, result) in results.enumerated() {
                print("[\(index+1)] ".blue.bold + result.title.bold)
                print(result.excerpt)
                if index < results.count - 1 {
                    print("---")
                }
            }
            print("")

        } catch let llmError as LLMError {
            print("❌ ".red.bold + "Error: \(llmError)".red)
        } catch {
            print("❌ ".red.bold + "Error searching notes: \(error.localizedDescription)".red)
            print("Try running 'status' to check if the LLM service is working properly.".yellow)
        }
    }

    private func listCategories() {
        do {
            print("📂 ".blue.bold + "Analyzing your notes collection...")

            // Create a prompt to get categories and counts
            let prompt = """
            You are a helpful assistant organizing notes. Please analyze the following notes collection and list the main categories and subcategories with counts of files in each.
            Format your response as a hierarchical list with categories, subcategories, and file counts.
            """

            let response = try llmService.query(prompt: prompt)
            print("\n" + "📁 CATEGORIES".green.bold)
            print("═════════════".green)
            print(response)
            print("")

        } catch {
            print("Error listing categories: \(error.localizedDescription)".red)
        }
    }

    private func showStatus() {
        print("\n" + "📊 BLKBOX STATUS".green.bold)
        print("═══════════════".green)

        // LLM status
        let isConnected = llmService.isAvailable()
        print("LLM Service: " + (isConnected ? "Connected ✅".green : "Not Connected ❌".red))

        // Show more details if connected
        if isConnected {
            let diagnostics = llmService.getDiagnostics()
            print("Model: \(diagnostics["modelName"] ?? "unknown")")
            print("Model Available: " + ((diagnostics["modelAvailable"] == "Yes") ? "Yes ✅".green : "No ❌".red))
            print("Base URL: \(diagnostics["baseURL"] ?? "unknown")")

            if llmService is RemoteLLMService {
                print("Service Type: Remote (OpenAI API)")
            } else if llmService is LLMService {
                print("Service Type: Local (Ollama)")
            }
        } else {
            if llmService is LLMService {
                print("Make sure Ollama is running locally (http://localhost:11434)".yellow)
                print("Try: ollama serve".yellow)
            } else if llmService is RemoteLLMService {
                print("Make sure your internet connection and API key are valid".yellow)
            }
        }

        // Display notes path and count
        let fileManager = FileManager.default
        let notesPath = notesManager.getNotesPath()

        print("\nNotes Information:")
        print("Notes Directory: \(notesPath)")

        var noteCount = 0
        var categoryCount = Set<String>()

        if let enumerator = fileManager.enumerator(atPath: notesPath) {
            while let file = enumerator.nextObject() as? String {
                if file.hasSuffix(".md") || file.hasSuffix(".txt") {
                    noteCount += 1

                    // Count unique categories (first-level directories)
                    if let firstSlash = file.firstIndex(of: "/") {
                        let category = String(file[..<firstSlash])
                        categoryCount.insert(category)
                    }
                }
            }
        }

        print("Total Notes: \(noteCount)")
        print("Categories: \(categoryCount.count)")

        // Directory check
        if !fileManager.fileExists(atPath: notesPath) {
            print("\n⚠️  ".yellow.bold + "Warning: Notes directory doesn't exist yet.".yellow)
            print("It will be created when you add your first note.".yellow)
        } else if noteCount == 0 {
            print("\n⚠️  ".yellow.bold + "Warning: No notes found.".yellow)
            print("Try adding a note with 'note' command.".yellow)
        }

        print("")
    }

    private func handleUnknownCommand(command: String, args: [String], fullInput: String) {
        // Check if LLM is available before trying to process the command
        if !llmService.isAvailable() {
            print("I don't understand the command '\(command)'. Type 'help' for available commands.".yellow)
            print("Note: LLM service is not available, so natural language commands won't work.".yellow)

            if llmService is LLMService {
                print("\nTo enable natural language commands:".yellow)
                print("1. Install Ollama from https://ollama.ai/download".yellow)
                print("2. Run 'ollama serve' in a separate terminal".yellow)
                print("3. Install a model with 'ollama pull llama3'".yellow)
                print("\nOr use OpenAI's API:".yellow)
                print("blkbox shell --remote --api-key YOUR_API_KEY".yellow)
            } else if llmService is RemoteLLMService {
                print("\nTo fix:".yellow)
                print("1. Check your internet connection".yellow)
                print("2. Verify your API key is correct".yellow)
                print("3. Make sure the API is not being rate limited".yellow)
            }

            return
        }

        // Check if model is available
        if !llmService.isModelAvailable() {
            print("I don't understand the command '\(command)'. Type 'help' for available commands.".yellow)
            print("Note: The required model is not available, so natural language commands won't work.".yellow)

            if llmService is LLMService {
                print("\nTo install the model:".yellow)
                print("  ollama pull \(llmService.modelName)".yellow.bold)
            } else {
                print("\nMake sure you're using a valid model name for the API.".yellow)
            }

            return
        }

        do {
            // Create a prompt for the LLM to interpret the command
            let prompt = """
            The user has entered this command in the BlkBox shell: "\(fullInput)"

            This doesn't match any built-in commands. Please interpret what the user is trying to do and provide a helpful response.
            If it's a question about their notes, try to answer it.
            If it sounds like they want to perform an action similar to a built-in command, suggest the correct command.

            Keep your response conversational and helpful.
            """

            print("💭 ".blue + "Processing your request...")
            let response = try llmService.query(prompt: prompt)
            print(response)
        } catch let llmError as LLMError {
            print("❌ ".red.bold + "Error: \(llmError)".red)
            print("I don't understand the command '\(command)'. Type 'help' for available commands.".yellow)
        } catch {
            print("I don't understand the command '\(command)'. Type 'help' for available commands.".yellow)
            print("Error details: \(error.localizedDescription)".red)
        }
    }

    /// Manage LLM models (list, pull, etc)
    private func manageModels(args: [String]) {
        // Only applies to local LLM services
        guard let localService = llmService as? LLMService else {
            print("❌ Model management is only available for local LLM (Ollama)")
            print("You're currently using a remote LLM service.".yellow)
            return
        }

        // Process command
        if args.isEmpty || args[0] == "list" {
            // List available models
            print("🔄 ".blue.bold + "Fetching available models...")
            let models = localService.listAvailableModels()

            if models.isEmpty {
                print("❌ No models found. Make sure Ollama is running.")
                print("To install a model, use:".yellow)
                print("  models pull MODEL_NAME".yellow.bold)
            } else {
                print("\n" + "📋 AVAILABLE MODELS".green.bold)
                print("════════════════════".green)

                for model in models {
                    let isCurrentModel = (model == llmService.modelName)
                    let modelText = isCurrentModel ? "\(model) (current)".green.bold : model
                    print("  • \(modelText)")
                }

                print("\nTo use a model:".blue)
                print("  models use MODEL_NAME".blue)
            }
        } else if args[0] == "pull" {
            // Pull a new model
            if args.count < 2 {
                print("❌ Please specify a model name to pull")
                print("Usage: models pull MODEL_NAME".yellow)
                print("\nPopular models:".blue)
                print("  • llama3 - Standard Llama 3 model".blue)
                print("  • llama3:8b - Smaller, faster Llama 3 model".blue)
                print("  • mistral - Alternative high-quality model".blue)
                print("  • phi3:mini - Very small, fast model".blue)
                return
            }

            let modelName = args[1]
            print("🔄 ".blue.bold + "Requesting Ollama to pull model '\(modelName)'...")
            print("This operation runs in Ollama and may take several minutes.")
            print("You can check progress in the Ollama terminal window.\n")

            // Use terminal command to execute ollama pull
            let terminal = Process()
            terminal.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            terminal.arguments = ["ollama", "pull", modelName]

            let pipe = Pipe()
            terminal.standardOutput = pipe
            terminal.standardError = pipe

            do {
                try terminal.run()
                print("✅ Pull request sent to Ollama.")
                print("Once the model is downloaded, you can use it with:".blue)
                print("  models use \(modelName)".blue.bold)
            } catch {
                print("❌ Failed to run ollama pull: \(error.localizedDescription)")
                print("Make sure ollama is installed and in your PATH".yellow)
            }
        } else if args[0] == "use" {
            // Change to a different model
            if args.count < 2 {
                print("❌ Please specify a model name to use")
                print("Usage: models use MODEL_NAME".yellow)
                return
            }

            let modelName = args[1]
            print("🔄 ".blue.bold + "Changing to model '\(modelName)'...")

            // Save the setting
            let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".blkbox")
            let configPath = configDir.appendingPathComponent("config.json").path

            // Create config directory if it doesn't exist
            if !FileManager.default.fileExists(atPath: configDir.path) {
                do {
                    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
                } catch {
                    print("❌ Failed to create config directory: \(error.localizedDescription)")
                    return
                }
            }

            // Load existing configuration if available
            var config: [String: Any] = [
                "service": "local",
                "model": modelName,
                "timeout": 600,
                "baseURL": "http://localhost:11434/api"
            ]

            if FileManager.default.fileExists(atPath: configPath) {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
                   let loadedConfig = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    for (key, value) in loadedConfig {
                        if key != "model" { // Only keep non-model settings
                            config[key] = value
                        }
                    }
                }
            }

            // Update model setting
            config["model"] = modelName

            // Save configuration
            if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
                do {
                    try data.write(to: URL(fileURLWithPath: configPath))
                    print("✅ ".green.bold + "Model changed to \(modelName)")
                    print("Note: This change will take effect next time you restart BlkBox.".yellow)
                    print("      To apply immediately, exit and restart BlkBox.".yellow)
                } catch {
                    print("❌ Failed to save configuration: \(error.localizedDescription)")
                }
            } else {
                print("❌ Failed to serialize configuration")
            }
        } else {
            // Unknown subcommand
            print("❌ Unknown models subcommand: \(args[0])")
            print("Available subcommands:".yellow)
            print("  • models list - List available models".yellow)
            print("  • models pull MODEL_NAME - Download a new model".yellow)
            print("  • models use MODEL_NAME - Switch to a different model".yellow)
        }
    }

    // MARK: - Helper Methods

    /// Show information about the current LLM service
    private func showLLMInfo() {
        print("\n" + "🤖 LLM SERVICE INFORMATION".green.bold)
        print("═════════════════════════".green)

        // Check if service is available
        let isAvailable = llmService.isAvailable()
        print("Service Status: " + (isAvailable ? "Connected ✅".green : "Not Connected ❌".red))

        // Show LLM type
        if llmService is LLMService {
            print("Service Type: Local (Ollama)")
        } else if llmService is RemoteLLMService {
            print("Service Type: Remote (OpenAI API)")
        }

        // Show model info
        print("Model: \(llmService.modelName)")
        if isAvailable {
            let modelAvailable = llmService.isModelAvailable()
            print("Model Available: " + (modelAvailable ? "Yes ✅".green : "No ❌".red))

            if !modelAvailable {
                if llmService is LLMService {
                    print("\nTo install the model, run: ".yellow)
                    print("  ollama pull \(llmService.modelName)".yellow.bold)
                } else if llmService is RemoteLLMService {
                    print("\nCheck that you're using a valid model name for OpenAI API".yellow)
                }
            }

            // List available models
            if llmService is LLMService {
                print("\nAvailable Models:")
                if let localService = llmService as? LLMService {
                    let models = localService.listAvailableModels()
                    if models.isEmpty {
                        print("  No models found. Try running 'ollama pull llama3'")
                    } else {
                        for model in models {
                            let isCurrentModel = (model == llmService.modelName)
                            let modelText = isCurrentModel ? "\(model) (current)".green.bold : model
                            print("  - \(modelText)")
                        }
                        print("\nTo use a different model: ".blue)
                        print("  blkbox configure -m \"model-name\"".blue.italic)
                    }
                }
            } else if llmService is RemoteLLMService {
                print("\nRecommended OpenAI Models:")
                print("  - gpt-3.5-turbo (fast, economical)")
                print("  - gpt-4 (more capable)")
                print("  - gpt-4-turbo (latest version)")
            }
        }

        // Show configuration tips
        print("\nConfiguration:")
        print("  To change LLM settings, use 'blkbox configure' outside the shell")
        print("  Configuration File: ~/.blkbox/config.json")

        // Show LLM diagnostics
        if isAvailable {
            let diagnostics = llmService.getDiagnostics()
            print("\nConnection Details:")
            print("  Base URL: \(diagnostics["baseURL"] ?? "unknown")")
        }

        print("")
    }

    private func readMultilineInput() -> String? {
        var lines = [String]()
        while let line = readLine() {
            lines.append(line)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// No extension needed as the method will be added to the NotesManager class directly
