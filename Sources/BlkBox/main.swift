import Foundation
import ArgumentParser
import BlkBoxLib
import Rainbow

@main
struct BlkBox: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A CLI tool for managing and gaining insights from your notes",
        version: "0.1.0",
        subcommands: [
            Summarize.self,
            Shell.self,
            AddNote.self,
            Retrieve.self
        ],
        defaultSubcommand: Shell.self
    )
}

// Command to summarize existing notes and provide insights
struct Summarize: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Summarize your notes and provide insights"
    )

    @Option(name: .shortAndLong, help: "Topics to focus on for insights")
    var topic: String?

    @Option(name: .shortAndLong, help: "Maximum number of insights to return")
    var limit: Int?

    @Option(name: .shortAndLong, help: "Path to the notes directory")
    var path: String?

    func run() throws {
        let notesManager = NotesManager(path: path)
        let llmService = LLMService()

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
        abstract: "Start an interactive BlkBox shell"
    )

    @Option(name: .shortAndLong, help: "Path to the notes directory")
    var path: String?

    func run() throws {
        let shell = BlkBoxShell(notesPath: path)

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

    @Argument(help: "Note content (if not provided via file)")
    var content: [String] = []

    func run() throws {
        let notesManager = NotesManager(path: path)
        let llmService = LLMService()

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

    @Argument(help: "Search query")
    var query: [String] = []

    func run() throws {
        let notesManager = NotesManager(path: path)
        let llmService = LLMService()
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
