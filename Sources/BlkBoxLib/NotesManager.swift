import Foundation

/// Represents a search result for note retrieval
public struct NoteSearchResult {
    public let title: String
    public let excerpt: String
    public let filePath: String

    public init(title: String, excerpt: String, filePath: String) {
        self.title = title
        self.excerpt = excerpt
        self.filePath = filePath
    }
}

/// Manages the notes collection and operations
public class NotesManager {
    public let notesPath: String
    private let defaultNotesPath = "\(FileManager.default.homeDirectoryForCurrentUser.path)/.blkbox/notes"

    /// Get the path to the notes directory
    public func getNotesPath() -> String {
        return notesPath
    }

    /// Initialize with an optional custom path
    public init(path: String? = nil) {
        self.notesPath = path ?? defaultNotesPath

        // Ensure notes directory exists
        try? FileManager.default.createDirectory(
            atPath: self.notesPath,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Generate insights from existing notes using the provided LLM service
    public func generateInsights(usingLLM llm: LLMService, topic: String? = nil, limit: Int = 5) throws -> [String] {
        do {
            // Collect notes content
            let notesContent = try collectNotesContent()

            if notesContent.isEmpty {
                return ["No notes found to analyze."]
            }

            // Create a prompt for the LLM
            let prompt = createInsightsPrompt(notesContent: notesContent, topic: topic, limit: limit)

            // Get response from LLM
            let response = try llm.query(prompt: prompt)

            // Parse response into individual insights
            let insights = parseInsightsResponse(response)
            return insights.prefix(limit).map { $0 }
        } catch let llmError as LLMError {
            print("LLM Error: \(llmError)")
            throw llmError
        } catch {
            print("Error in generateInsights: \(error.localizedDescription)")
            throw error
        }
    }

    /// Add a new note, using LLM to categorize and place it appropriately
    public func addNote(content: String, usingLLM llm: LLMService) throws {
        do {
            // Create a prompt to analyze and categorize the note
            let prompt = createNoteCategorizationPrompt(content: content)

            // Get response from LLM
            let response = try llm.query(prompt: prompt)

            // Parse the response to get file path and formatted content
            let (filePath, formattedContent) = try parseNoteAdditionResponse(response, originalContent: content)

            // Create full path
            let fullPath = "\(notesPath)/\(filePath)"

            // Ensure directory exists
            let directoryPath = (fullPath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(
                atPath: directoryPath,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Write note to file
            try formattedContent.write(toFile: fullPath, atomically: true, encoding: .utf8)

            print("Note saved to: \(filePath)")
        } catch let llmError as LLMError {
            print("LLM Error in addNote: \(llmError)")
            throw llmError
        } catch {
            print("Error in addNote: \(error.localizedDescription)")
            throw error
        }
    }

    /// Retrieve notes based on query and optional type
    public func retrieveNotes(query: String, type: String? = nil, usingLLM llm: LLMService) throws -> [NoteSearchResult] {
        do {
            // Collect notes content
            let notesContent = try collectNotesContent()

            if notesContent.isEmpty {
                print("No notes found in collection")
                return []
            }

            // Create a prompt for the LLM
            let prompt = createNoteRetrievalPrompt(notesContent: notesContent, query: query, type: type)

            // Get response from LLM
            print("Sending query to LLM...")
            let response = try llm.query(prompt: prompt)

            // Parse response into search results
            let results = parseNoteRetrievalResponse(response)
            print("Found \(results.count) matching notes")
            return results
        } catch let llmError as LLMError {
            print("LLM Error in retrieveNotes: \(llmError)")
            throw llmError
        } catch {
            print("Error in retrieveNotes: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private Helper Methods

    private func collectNotesContent() throws -> [String: String] {
        var notesContent = [String: String]()

        // Recursively enumerate all files in the notes directory
        let fileManager = FileManager.default

        // Check if directory exists
        if !fileManager.fileExists(atPath: notesPath) {
            print("Notes directory doesn't exist yet. Creating it...")
            try fileManager.createDirectory(
                atPath: notesPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            return notesContent
        }

        guard let enumerator = fileManager.enumerator(atPath: notesPath) else {
            print("Warning: Could not enumerate files in \(notesPath)")
            return notesContent
        }

        while let file = enumerator.nextObject() as? String {
            // Only consider markdown and text files
            if file.hasSuffix(".md") || file.hasSuffix(".txt") {
                let filePath = "\(notesPath)/\(file)"

                do {
                    // Read file content
                    let content = try String(contentsOfFile: filePath, encoding: .utf8)
                    notesContent[file] = content
                } catch {
                    print("Warning: Could not read file \(file): \(error.localizedDescription)")
                    // Continue with other files instead of failing
                }
            }
        }

        return notesContent
    }

    private func createInsightsPrompt(notesContent: [String: String], topic: String?, limit: Int) -> String {
        var prompt = "You are an insightful assistant analyzing a collection of notes. "

        if let topic = topic {
            prompt += "Focus on the topic: \(topic). "
        }

        prompt += """
        Please analyze the following notes and provide \(limit) interesting insights, patterns, or connections you notice.
        Format your response as a numbered list of concise insights.

        NOTES COLLECTION:
        """

        // Add notes content (with reasonable limits to avoid token issues)
        for (file, content) in notesContent {
            let truncatedContent = content.prefix(1000) // Limit each note to first 1000 chars
            prompt += "\n\nFILE: \(file)\nCONTENT:\n\(truncatedContent)"
        }

        prompt += "\n\nINSIGHTS:"

        return prompt
    }

    private func parseInsightsResponse(_ response: String) -> [String] {
        // Simple parsing assuming numbered list format
        let lines = response.split(separator: "\n")
        var insights = [String]()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Look for numbered list items or bullet points
            if trimmed.range(of: #"^\d+[\.\)]"#, options: .regularExpression) != nil ||
               trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                // Remove the number/bullet and add to insights
                let content = trimmed.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                                     .replacingOccurrences(of: #"^[- *]\s*"#, with: "", options: .regularExpression)
                insights.append(content)
            } else if !insights.isEmpty && !trimmed.isEmpty {
                // If not a new list item but not empty, append to the last insight
                insights[insights.count - 1] += " \(trimmed)"
            }
        }

        return insights
    }

    private func createNoteCategorizationPrompt(content: String) -> String {
        return """
        You are an expert note organizer. Analyze this note and determine the best category and filename for it.

        NOTE CONTENT:
        \(content)

        Please provide:
        1. A category folder path (e.g., "projects/coding" or "personal/health")
        2. A suitable filename with .md extension (e.g., "swift-cli-ideas.md")
        3. Optionally, a formatted version of the note with proper Markdown, including a title, tags, and date

        FORMAT YOUR RESPONSE LIKE THIS:
        FILE_PATH: category/subcategory/filename.md
        CONTENT:
        # Title

        [formatted note content]
        """
    }

    private func parseNoteAdditionResponse(_ response: String, originalContent: String) throws -> (String, String) {
        let lines = response.split(separator: "\n", omittingEmptySubsequences: false)
        var filePath = ""
        var content = originalContent

        // Find the file path line
        for line in lines {
            if line.hasPrefix("FILE_PATH:") {
                filePath = line.replacingOccurrences(of: "FILE_PATH:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // If we found a content section, use it
        if let contentStart = response.range(of: "CONTENT:") {
            content = String(response[contentStart.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // If no file path found, use a default
        if filePath.isEmpty {
            print("Warning: LLM didn't provide a file path, using default")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            filePath = "unsorted/note-\(dateString).md"
        }

        // Sanitize file path to prevent directory traversal attacks
        if filePath.contains("..") {
            print("Warning: Invalid file path detected, sanitizing")
            filePath = filePath.replacingOccurrences(of: "..", with: "")
        }

        // Ensure .md extension
        if !filePath.hasSuffix(".md") {
            filePath += ".md"
        }

        // If content is empty, use original content with a title
        if content.isEmpty || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("Warning: LLM didn't provide formatted content, using original")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateString = dateFormatter.string(from: Date())
            content = "# Note from \(dateString)\n\n\(originalContent)"
        }

        return (filePath, content)
    }

    private func createNoteRetrievalPrompt(notesContent: [String: String], query: String, type: String?) -> String {
        var prompt = "You are a helpful assistant searching through a collection of notes. "

        if let type = type {
            prompt += "The user is specifically looking for \(type) information. "
        }

        prompt += """
        Search for information relevant to this query: "\(query)"

        NOTES COLLECTION:
        """

        // Add notes content (with reasonable limits to avoid token issues)
        for (file, content) in notesContent {
            let truncatedContent = content.prefix(1000) // Limit each note to first 1000 chars
            prompt += "\n\nFILE: \(file)\nCONTENT:\n\(truncatedContent)"
        }

        prompt += """

        For each relevant note, provide:
        1. A clear title summarizing the content
        2. A brief excerpt containing the most relevant information
        3. The file path

        FORMAT YOUR RESPONSE LIKE THIS:
        TITLE: [Title of note]
        EXCERPT: [Relevant excerpt]
        PATH: [File path]

        TITLE: [Title of another note]
        EXCERPT: [Relevant excerpt]
        PATH: [File path]

        Provide up to 5 most relevant results. If no results are found, return an empty response.
        """

        return prompt
    }

    private func parseNoteRetrievalResponse(_ response: String) -> [NoteSearchResult] {
        var results = [NoteSearchResult]()
        let sections = response.components(separatedBy: "\n\n")

        for section in sections {
            var title = ""
            var excerpt = ""
            var path = ""

            let lines = section.components(separatedBy: "\n")
            for line in lines {
                if line.hasPrefix("TITLE:") {
                    title = line.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("EXCERPT:") {
                    excerpt = line.replacingOccurrences(of: "EXCERPT:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if line.hasPrefix("PATH:") {
                    path = line.replacingOccurrences(of: "PATH:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                } else if !line.isEmpty && !excerpt.isEmpty {
                    // Append to excerpt if it's already started and the line isn't a new field
                    excerpt += "\n" + line
                }
            }

            if !title.isEmpty && !excerpt.isEmpty && !path.isEmpty {
                results.append(NoteSearchResult(title: title, excerpt: excerpt, filePath: path))
            }
        }

        return results
    }
}
