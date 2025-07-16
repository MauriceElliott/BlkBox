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
            } else if llmService is RemoteLLMService {
                print("Make sure your internet connection and API key are valid".yellow)
            }

            print("Continuing in limited mode...\n".yellow)
        } else {
            // Check if the model is available
            if !llmService.isModelAvailable() {
                print("⚠️  ".yellow.bold + "Warning: Model '\(llmService.modelName)' may not be available")

                if llmService is LLMService {
                    print("Try running: ollama pull \(llmService.modelName)".yellow)
                } else if llmService is RemoteLLMService {
                    print("Make sure you're using a valid model name for the API".yellow)
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
        print("  exit".blue.bold + "                  Exit BlkBox shell")
        print("\nFor any command, you can type a question or request and BlkBox will try to help.\n")
    }

    private func generateInsights(args: [String]) {
        do {
            // Check if LLM is available before proceeding
            if !llmService.isAvailable() {
                print("❌ ".red.bold + "Error: LLM service is not available")
                print("Make sure Ollama is running with your model installed.".yellow)
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
        } catch {
            print("❌ ".red.bold + "Error generating insights: \(error.localizedDescription)".red)
            print("Try running 'status' to check if the LLM service is working properly.".yellow)
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
                print("Make sure Ollama is running locally.".yellow)
            } else if llmService is RemoteLLMService {
                print("Check your internet connection and API key.".yellow)
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
