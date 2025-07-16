import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Dispatch

/// Service for interacting with a remote LLM (OpenAI API)
public class RemoteLLMService: LLMServiceProtocol {
    private let apiKey: String
    private let baseURL: URL
    public let modelName: String
    private let systemPrompt: String
    private let timeout: TimeInterval

    /// Initialize the Remote LLM service with required configuration
    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        modelName: String = "gpt-3.5-turbo",
        systemPrompt: String? = nil,
        timeoutInterval: TimeInterval = 600
    ) {
        let defaultSystemPrompt = Self.createDefaultSystemPrompt()

        self.apiKey = apiKey
        self.baseURL = baseURL
        self.modelName = modelName
        self.systemPrompt = systemPrompt ?? defaultSystemPrompt
        self.timeout = timeoutInterval
    }

    /// Send a query to the LLM and get a response
    public func query(prompt: String) throws -> String {
        // First check if we can connect to the API
        if !isAvailable() {
            print("⚠️ Warning: Remote LLM service appears to be unavailable.")
            throw LLMError.connectionFailed
        }

        let endpoint = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        print("🔄 Preparing query to model: \(modelName)")

        // Create the request payload
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": prompt]
        ]

        let payload: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 2048
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

        print("🔄 Sending request to OpenAI...")
        let task = URLSession.shared.dataTask(with: request, completionHandler: taskHandler)
        task.resume()

        // Wait for response with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + timeout)

        // Check for timeout
        if timeoutResult == .timedOut {
            print("❌ Request timed out after \(Int(timeout)) seconds")
            throw LLMError.timeoutError
        }

        // Check for HTTP errors
        if let httpResponse = capturedResponse as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            if let data = capturedData, let body = String(data: data, encoding: .utf8) {
                print("Response body: \(body)")
            }
            throw LLMError.queryFailed("HTTP error: \(httpResponse.statusCode)")
        }

        // Handle response
        if let error = capturedError {
            print("❌ Network error: \(error.localizedDescription)")
            throw LLMError.queryFailed("Request failed: \(error.localizedDescription)")
        }

        guard let data = capturedData else {
            print("❌ No data received from OpenAI service")
            throw LLMError.queryFailed("No data received")
        }

        // Parse the response
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let errorInfo = json["error"] as? [String: Any],
                   let errorMessage = errorInfo["message"] as? String {
                    print("❌ OpenAI API returned error: \(errorMessage)")
                    throw LLMError.queryFailed("API error: \(errorMessage)")
                }

                if let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    print("✅ Successfully received response from OpenAI")
                    return content
                } else {
                    print("❌ Response does not contain expected format")
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(dataString)")
                    }
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

    /// Check if the OpenAI API is available
    public func isAvailable() -> Bool {
        print("🔄 Checking if OpenAI API is available...")

        // Try to reach the OpenAI API with a simple request
        let endpoint = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // Short timeout for quick checking
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
                    print("✅ OpenAI API is available")
                } else {
                    print("❌ OpenAI API returned status code: \(httpResponse.statusCode)")
                }
                result = isSuccess
            }
            semaphore.signal()
        }

        let task = URLSession.shared.dataTask(with: request, completionHandler: taskHandler)
        task.resume()

        let timeoutResult = semaphore.wait(timeout: .now() + 5)
        if timeoutResult == .timedOut {
            print("❌ OpenAI API check timed out")
            return false
        }

        return result
    }

    /// Check if a specific model is available
    public func isModelAvailable() -> Bool {
        print("🔄 Checking if model '\(modelName)' is available...")

        let endpoint = baseURL.appendingPathComponent("models")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

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
                   let models = json["data"] as? [[String: Any]] {
                    for model in models {
                        if let id = model["id"] as? String, id == self.modelName {
                            print("✅ Model '\(self.modelName)' is available")
                            modelFound = true
                            break
                        }
                    }

                    if !modelFound {
                        print("❌ Model '\(self.modelName)' not found in available models")
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
        print("Note: To actually update the system prompt, create a new RemoteLLMService instance with the new prompt")
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
}
