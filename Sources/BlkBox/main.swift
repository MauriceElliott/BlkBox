import Foundation
import ArgumentParser
import BlkBoxLib
import Rainbow

@main
struct BlkBox: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A CLI tool for managing and gaining insights from your notes using local or remote LLMs",
        version: "0.1.0",
        subcommands: [
            Summarize.self,
            Shell.self,
            AddNote.self,
            Retrieve.self,
            Configure.self
        ],
        defaultSubcommand: Shell.self
    )
}

// Command to configure LLM settings
struct Configure: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Configure LLM settings and preferences (local or remote)"
    )

    @Flag(name: [.customShort("s"), .long], help: "Show the current configuration")
    var show: Bool = false

    @Flag(name: [.customShort("T"), .long], help: "Test connection to the configured LLM service")
    var test: Bool = false

    @Option(name: [.customShort("S"), .long], help: "Select LLM service type: 'local' (Ollama) or 'remote' (OpenAI)")
    var service: String?

    @Option(name: [.customShort("m"), .long], help: "Set the model name")
    var model: String?

    @Option(name: [.customShort("k"), .long], help: "Set the API key for remote services")
    var apiKey: String?

    @Option(name: [.customShort("t"), .long], help: "Set timeout in seconds")
    var timeout: Int?

    func run() throws {
        // Path to the configuration file
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".blkbox")
        let configPath = configDir.appendingPathComponent("config.json").path

        // Create config directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: configDir.path) {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        }

        // Default configuration
        var config: [String: Any] = [
            "service": "local",
            "model": "llama3",
            "timeout": 1800,
            "baseURL": "http://localhost:11434/api"
        ]

        // Load existing configuration if available
        if FileManager.default.fileExists(atPath: configPath) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)),
               let loadedConfig = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (key, value) in loadedConfig {
                    config[key] = value
                }
            }
        }

        // Just show current configuration
        if show {
            print("📋 ".blue.bold + "Current Configuration:".bold)
            print("Service: ".blue + "\(config["service"] ?? "local")")
            print("Model: ".blue + "\(config["model"] ?? "llama3")")
            print("Timeout: ".blue + "\(config["timeout"] ?? 600) seconds")
            print("Base URL: ".blue + "\(config["baseURL"] ?? "http://localhost:11434/api")")

            if let apiKey = config["apiKey"] as? String, !apiKey.isEmpty {
                print("API Key: ".blue + "****" + String(apiKey.suffix(4)))
            } else {
                print("API Key: ".blue + "Not set")
            }
            return
        }

        // Test connection to configured LLM
        if test {
            print("🔄 ".blue.bold + "Testing connection to LLM service...")

            let llmService: LLMServiceProtocol
            let serviceType = config["service"] as? String ?? "local"

            if serviceType == "remote" {
                guard let apiKey = config["apiKey"] as? String, !apiKey.isEmpty else {
                    print("❌ ".red.bold + "Error: API key not configured for remote service")
                    print("Use 'blkbox configure --api-key YOUR_API_KEY' to set it".yellow)
                    throw ExitCode.failure
                }

                llmService = LLMServiceFactory.createRemoteService(apiKey: apiKey)
                print("Using remote service (OpenAI API)")
            } else {
                llmService = LLMServiceFactory.createLocalService()
                print("Using local service (Ollama)")
            }

            if llmService.isAvailable() {
                print("✅ ".green.bold + "Successfully connected to LLM service!")

                if llmService.isModelAvailable() {
                    print("✅ ".green.bold + "Model '\(llmService.modelName)' is available")

                    print("🔄 Testing with a simple prompt...")
                    do {
                        let response = try llmService.query(prompt: "Respond with 'Connection test successful' and nothing else.")
                        print("📝 Response received:")
                        print(response)
                        print("\n✅ ".green.bold + "Test completed successfully!")
                    } catch {
                        print("❌ ".red.bold + "Error during query test: \(error.localizedDescription)".red)
                    }
                } else {
                    print("❌ ".red.bold + "Model '\(llmService.modelName)' is not available".red)

                    if serviceType == "local" {
                        print("Try running: ollama pull \(llmService.modelName)".yellow)
                    } else {
                        print("Check that you're using a valid model name for OpenAI API".yellow)
                    }
                }
            } else {
                print("❌ ".red.bold + "Failed to connect to LLM service".red)

                if serviceType == "local" {
                    print("Make sure Ollama is running (ollama serve)".yellow)
                } else {
                    print("Check your internet connection and API key".yellow)
                }
            }

            return
        }

        // Update configuration based on provided options
        if let service = service {
            if service == "local" || service == "remote" {
                config["service"] = service
                print("✅ Service type set to: \(service)")
            } else {
                print("❌ Invalid service type. Use 'local' or 'remote'".red)
                throw ExitCode.failure
            }
        }

        if let model = model {
            config["model"] = model
            print("✅ Default model set to: \(model)")
        }

        if let apiKey = apiKey {
            config["apiKey"] = apiKey
            print("✅ API key set successfully")
        }

        if let timeout = timeout {
            if timeout > 0 {
                config["timeout"] = timeout
                print("✅ Timeout set to: \(timeout) seconds")
            } else {
                print("❌ Timeout must be greater than 0".red)
                throw ExitCode.failure
            }
        }

        // Save configuration
        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try data.write(to: URL(fileURLWithPath: configPath))
            print("✅ ".green.bold + "Configuration saved successfully to \(configPath)")
        } else {
            print("❌ Failed to save configuration".red)
            throw ExitCode.failure
        }
    }
}

// Command to summarize existing notes and provide insights
struct Summarize: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Summarize your notes and provide insights using LLM"
    )

    @Option(name: .shortAndLong, help: "Topics to focus on for insights")
    var topic: String?

    @Option(name: .shortAndLong, help: "Maximum number of insights to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "Path to the notes directory")
    var path: String?

    @Flag(name: .long, help: "Use remote LLM service (OpenAI)")
    var remote: Bool = false

    @Option(name: .long, help: "OpenAI API key (required for remote LLM)")
    var apiKey: String?

    func run() throws {
        let notesManager = NotesManager(path: path)
        let llmService: LLMServiceProtocol

        // Determine which LLM service to use
        if remote {
            // Get API key from parameter or environment variable
            var key = apiKey
            if key == nil || key!.isEmpty {
                key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            }

            guard let finalApiKey = key, !finalApiKey.isEmpty else {
                print("Error: OpenAI API key is required when using remote LLM".red)
                print("Provide it with --api-key or set the OPENAI_API_KEY environment variable".yellow)
                throw ExitCode.failure
            }

            llmService = LLMServiceFactory.createRemoteService(apiKey: finalApiKey)
            print("🌐 Using OpenAI API for LLM service")
        } else {
            llmService = LLMServiceFactory.createLocalService()
            print("🖥️  Using local Ollama for LLM service")
        }

        print("🔍 ".blue.bold + "Analyzing your notes for insights...")

        do {
            let insights = try notesManager.generateInsights(
                usingLLM: llmService,
                topic: topic,
                limit: limit ?? 5
            )

            print("\n" + "📊 INSIGHTS FROM YOUR NOTES".green.bold)
            print("══════════════════════════════\n".green)

            for (index, insight) in insights.enumerated() {
                print("[\(index+1)] ".blue.bold + insight)
                if index < insights.count - 1 {
                    print("---")
                }
            }
        } catch {
            print("Error generating insights: \(error.localizedDescription)".red)
        }
    }
}

// Interactive shell mode
struct Shell: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Start an interactive BlkBox shell with LLM-powered features"
    )

    @Option(name: .shortAndLong, help: "Path to the notes directory")
    var path: String?

    @Flag(name: .long, help: "Use remote LLM service (OpenAI)")
    var remote: Bool = false

    @Option(name: .long, help: "OpenAI API key (required for remote LLM)")
    var apiKey: String?

    func run() throws {
        // Validate API key if using remote LLM
        var finalApiKey = apiKey
        if remote && (finalApiKey == nil || finalApiKey!.isEmpty) {
            // Try to get API key from environment variable
            finalApiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]

            if finalApiKey == nil || finalApiKey!.isEmpty {
                print("Error: OpenAI API key is required when using remote LLM".red)
                print("Provide it with --api-key or set the OPENAI_API_KEY environment variable".yellow)
                throw ExitCode.failure
            }
        }

        let shell = BlkBoxShell(notesPath: path, useRemoteLLM: remote, apiKey: finalApiKey)

        print("Welcome to ".blue + "BlkBox".white.bold.onBlue + " Shell 📦".blue)
        print("Type 'help' for available commands or 'exit' to quit\n".italic)

        shell.start()
    }
}

// Add a new note
struct AddNote: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new note to your collection"
    )

    @Option(name: .shortAndLong, help: "Path to the notes directory")
    var path: String?

    @Option(name: .shortAndLong, help: "Path to a file containing the note")
    var file: String?

    @Flag(name: .long, help: "Use remote LLM service (OpenAI)")
    var remote: Bool = false

    @Option(name: .long, help: "OpenAI API key (required for remote LLM)")
    var apiKey: String?

    @Argument(help: "Note content (if not provided via file)")
    var content: [String] = []

    func run() throws {
        let notesManager = NotesManager(path: path)
        let llmService: LLMServiceProtocol

        // Determine which LLM service to use
        if remote {
            // Get API key from parameter or environment variable
            var key = apiKey
            if key == nil || key!.isEmpty {
                key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            }

            guard let finalApiKey = key, !finalApiKey.isEmpty else {
                print("Error: OpenAI API key is required when using remote LLM".red)
                print("Provide it with --api-key or set the OPENAI_API_KEY environment variable".yellow)
                throw ExitCode.failure
            }

            llmService = LLMServiceFactory.createRemoteService(apiKey: finalApiKey)
            print("🌐 Using OpenAI API for LLM service")
        } else {
            llmService = LLMServiceFactory.createLocalService()
            print("🖥️  Using local Ollama for LLM service")
        }

        do {
            let noteContent: String

            if let filePath = file {
                // Read from file
                noteContent = try String(contentsOfFile: filePath, encoding: .utf8)
            } else if !content.isEmpty {
                // Use content from command line
                noteContent = content.joined(separator: " ")
            } else {
                // Interactive mode
                print("Enter your note (press Ctrl+D when finished):")
                noteContent = readMultilineInput() ?? ""
            }

            if noteContent.isEmpty {
                print("No note content provided.".red)
                return
            }

            print("📝 ".blue.bold + "Processing your note...")
            try notesManager.addNote(content: noteContent, usingLLM: llmService)
            print("✅ ".green.bold + "Note added successfully!")
        } catch {
            print("Error adding note: \(error.localizedDescription)".red)
        }
    }

    private func readMultilineInput() -> String? {
        var lines = [String]()
        while let line = readLine() {
            lines.append(line)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }
}

// Retrieve notes
struct Retrieve: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Retrieve notes based on query"
    )

    @Option(name: .shortAndLong, help: "Path to the notes directory")
    var path: String?

    @Option(name: .shortAndLong, help: "Type of information to retrieve (e.g., 'todo', 'shopping', etc.)")
    var type: String?

    @Flag(name: .long, help: "Use remote LLM service (OpenAI)")
    var remote: Bool = false

    @Option(name: .long, help: "OpenAI API key (required for remote LLM)")
    var apiKey: String?

    @Argument(help: "Search query")
    var query: [String] = []

    func run() throws {
        let notesManager = NotesManager(path: path)
        let llmService: LLMServiceProtocol

        // Determine which LLM service to use
        if remote {
            // Get API key from parameter or environment variable
            var key = apiKey
            if key == nil || key!.isEmpty {
                key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]
            }

            guard let finalApiKey = key, !finalApiKey.isEmpty else {
                print("Error: OpenAI API key is required when using remote LLM".red)
                print("Provide it with --api-key or set the OPENAI_API_KEY environment variable".yellow)
                throw ExitCode.failure
            }

            llmService = LLMServiceFactory.createRemoteService(apiKey: finalApiKey)
            print("🌐 Using OpenAI API for LLM service")
        } else {
            llmService = LLMServiceFactory.createLocalService()
            print("🖥️  Using local Ollama for LLM service")
        }

        let searchQuery = query.joined(separator: " ")

        print("🔍 ".blue.bold + "Searching your notes...")

        do {
            let results = try notesManager.retrieveNotes(
                query: searchQuery,
                type: type,
                usingLLM: llmService
            )

            if results.isEmpty {
                print("No matching notes found.".yellow)
                return
            }

            print("\n" + "📄 SEARCH RESULTS".green.bold)
            print("═══════════════════\n".green)

            for (index, result) in results.enumerated() {
                print("[\(index+1)] ".blue.bold + result.title.bold)
                print(result.excerpt)
                if index < results.count - 1 {
                    print("---")
                }
            }
        } catch {
            print("Error retrieving notes: \(error.localizedDescription)".red)
        }
    }
}
