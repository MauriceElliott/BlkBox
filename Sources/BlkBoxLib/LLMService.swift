import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Dispatch

/// Service for interacting with a local LLM (currently Ollama)
public class LLMService: LLMServiceProtocol {
    private let baseURL: URL
    public let modelName: String
    private let systemPrompt: String

    /// Initialize the LLM service with optional configuration
    public init(
        baseURL: URL = URL(string: "http://localhost:11434/api")!,
        modelName: String = "llama3",
        systemPrompt: String? = nil,
        timeoutInterval: TimeInterval = 1800
    ) {
        let defaultSystemPrompt = Self.createDefaultSystemPrompt()

        self.baseURL = baseURL
        self.modelName = modelName
        self.systemPrompt = systemPrompt ?? defaultSystemPrompt
    }

    /// Send a query to the LLM and get a response
    public func query(prompt: String) throws -> String {
        // First check if the LLM service is available
        if !isAvailable() {
            print("⚠️ Warning: LLM service appears to be unavailable.")
            throw LLMError.connectionFailed
        }

        // Check if model is available
        if !isModelAvailable() {
            print("⚠️ Warning: Model '\(modelName)' is not available.")
            print("   To install the model, run: ollama pull \(self.modelName)")
            throw LLMError.modelNotAvailable
        }

        let endpoint = baseURL.appendingPathComponent("generate")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        print("🔄 Preparing query to model: \(modelName)")

        // Create the request payload
        let payload: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "system": systemPrompt,
            "stream": false
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            print("❌ Error serializing request: \(error.localizedDescription)")
            throw LLMError.queryFailed("Failed to prepare request: \(error.localizedDescription)")
        }

        // Use a synchronous approach for simplicity
        let semaphore = DispatchSemaphore(value: 0)

        // Thread-safe variables to capture results
        var capturedData: Data?
        var capturedError: Error?
        var capturedResponse: URLResponse?

        // Create a task inside a local scope to avoid capture list warnings
        let taskHandler = { @Sendable (data: Data?, response: URLResponse?, error: Error?) -> Void in
            capturedData = data
            capturedError = error
            capturedResponse = response
            semaphore.signal()
        }

        print("🔄 Sending request to LLM...")
        let task = URLSession.shared.dataTask(with: request, completionHandler: taskHandler)
        task.resume()

        // Wait for response with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 1800)

        // Check for timeout
        if timeoutResult == .timedOut {
            print("❌ Request timed out after 1800 seconds")
            throw LLMError.timeoutError
        }

        // Handle network errors
        if let error = capturedError {
            print("❌ Network error: \(error.localizedDescription)")
            throw LLMError.queryFailed("Request failed: \(error.localizedDescription)")
        }

        // Check for HTTP errors
        if let httpResponse = capturedResponse as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            throw LLMError.queryFailed("HTTP error: \(httpResponse.statusCode)")
        }

        guard let data = capturedData else {
            print("❌ No data received from LLM service")
            throw LLMError.queryFailed("No data received")
        }

        // Parse the response
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let errorMessage = json["error"] as? String {
                    print("❌ LLM service returned error: \(errorMessage)")
                    throw LLMError.queryFailed("LLM error: \(errorMessage)")
                }

                if let response = json["response"] as? String {
                    print("✅ Successfully received response from LLM")
                    return response
                } else {
                    print("❌ Response does not contain expected 'response' field")
                    throw LLMError.responseParsingFailed
                }
            } else {
                print("❌ Could not parse JSON response")
                if let dataString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(dataString)")
                }
                throw LLMError.responseParsingFailed
            }
        } catch let jsonError as LLMError {
            throw jsonError
        } catch {
            print("❌ Failed to parse response: \(error.localizedDescription)")
            throw LLMError.queryFailed("Failed to parse response: \(error.localizedDescription)")
        }
    }

    /// Check if the LLM service is available
    public func isAvailable() -> Bool {
        print("🔄 Checking if LLM service is available...")

        // Try to reach the Ollama API
        let endpoint = baseURL.appendingPathComponent("tags")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // Short timeout for quick checking

        let semaphore = DispatchSemaphore(value: 0)

        // Use a local variable to avoid capture list warnings
        var result = false

        // Create a handler to avoid capture list warnings
        let taskHandler = { @Sendable (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if let error = error {
                print("❌ Service check failed: \(error.localizedDescription)")
                result = false
                semaphore.signal()
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                let isSuccess = (200...299).contains(httpResponse.statusCode)
                if isSuccess {
                    print("✅ LLM service is available")
                } else {
                    print("❌ LLM service returned status code: \(httpResponse.statusCode)")
                }
                result = isSuccess
            }
            semaphore.signal()
        }

        let task = URLSession.shared.dataTask(with: request, completionHandler: taskHandler)
        task.resume()

        let timeoutResult = semaphore.wait(timeout: .now() + 5)
        if timeoutResult == .timedOut {
            print("❌ LLM service check timed out")
            return false
        }

        return result
    }

    /// Check if a specific model is available
    public func isModelAvailable() -> Bool {
        print("🔄 Checking if model '\(modelName)' is available...")

        // First check if LLM service is available at all
        if !isAvailable() {
            print("❌ Cannot check for model availability since Ollama is not running")
            return false
        }

        // Use the tags endpoint instead of models
        let endpoint = baseURL.appendingPathComponent("tags")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        let semaphore = DispatchSemaphore(value: 0)
        var modelFound = false

        let taskHandler = { @Sendable (data: Data?, response: URLResponse?, error: Error?) -> Void in
            guard let data = data, error == nil,
                  let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                semaphore.signal()
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    for model in models {
                        if let name = model["name"] as? String, name == self.modelName {
                            print("✅ Model '\(self.modelName)' is available")
                            modelFound = true
                            break
                        }
                    }

                    if !modelFound {
                        print("❌ Model '\(self.modelName)' not found in available models")
                        print("   To install the model, run: ollama pull \(self.modelName)")
                    }
                }
            } catch {
                print("❌ Error parsing models response: \(error.localizedDescription)")
            }

            semaphore.signal()
        }

        let task = URLSession.shared.dataTask(with: request, completionHandler: taskHandler)
        task.resume()

        _ = semaphore.wait(timeout: .now() + 5)
        return modelFound
    }

    // MARK: - Private Helper Methods

    private static func createDefaultSystemPrompt() -> String {
        return """
        You are BlkBox, an AI assistant focused on helping users manage, organize, and gain insights from their personal notes.
        Your purpose is to serve as a "second brain" interface, helping users to:

        1. Extract insights and connections across their notes
        2. Organize and categorize new notes appropriately
        3. Retrieve relevant information when requested
        4. Identify patterns, recurring themes, and important concepts in their knowledge base

        When working with notes:
        - Always maintain a helpful, concise tone
        - Format responses cleanly with Markdown where appropriate
        - For organization tasks, use logical folder structures and filenames
        - For retrieval tasks, prioritize relevance and summarize key points
        - For insight generation, focus on meaningful patterns and connections

        You excel at understanding context and finding the most helpful information. Your goal is to make the user's personal knowledge base more useful and accessible.
        """
    }

    /// Set a custom system prompt
    public func setSystemPrompt(_ prompt: String) {
        // Since we can't modify the systemPrompt directly as it's a let property,
        // we would need to use a different approach in a real implementation
        print("✅ System prompt update requested: \(prompt)")
        print("Note: To actually update the system prompt, create a new LLMService instance with the new prompt")
    }

    /// Get diagnostic information about the LLM service
    public func getDiagnostics() -> [String: String] {
        var diagnostics: [String: String] = [:]

        diagnostics["baseURL"] = baseURL.absoluteString
        diagnostics["modelName"] = modelName
        diagnostics["serviceAvailable"] = isAvailable() ? "Yes" : "No"
        diagnostics["modelAvailable"] = isModelAvailable() ? "Yes" : "No"

        return diagnostics
    }

    /// List all available models from the Ollama API
    public func listAvailableModels() -> [String] {
        print("🔄 Listing all available models...")

        if !isAvailable() {
            print("❌ Cannot list models: Ollama service is not available")
            return []
        }

        let endpoint = baseURL.appendingPathComponent("tags")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        let semaphore = DispatchSemaphore(value: 0)
        var modelList: [String] = []

        let taskHandler = { @Sendable (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if let error = error {
                print("❌ Error fetching models: \(error.localizedDescription)")
                semaphore.signal()
                return
            }

            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                if let httpResponse = response as? HTTPURLResponse {
                    print("❌ HTTP error fetching models: \(httpResponse.statusCode)")
                }
                semaphore.signal()
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {

                    print("📋 Found \(models.count) available models:")

                    for model in models {
                        if let name = model["name"] as? String {
                            modelList.append(name)
                            print("   - \(name)")
                        }
                    }
                }
            } catch {
                print("❌ Error parsing models response: \(error.localizedDescription)")
            }

            semaphore.signal()
        }

        let task = URLSession.shared.dataTask(with: request, completionHandler: taskHandler)
        task.resume()

        _ = semaphore.wait(timeout: .now() + 5)

        return modelList
    }
}
