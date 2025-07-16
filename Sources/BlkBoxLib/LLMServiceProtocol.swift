import Foundation

/// Protocol defining the interface for LLM services
public protocol LLMServiceProtocol {
    /// The model name used by the service
    var modelName: String { get }

    /// Send a query to the LLM and get a response
    func query(prompt: String) throws -> String

    /// Check if the LLM service is available
    func isAvailable() -> Bool

    /// Check if a specific model is available
    func isModelAvailable() -> Bool

    /// Set a custom system prompt
    func setSystemPrompt(_ prompt: String)

    /// Get diagnostic information about the LLM service
    func getDiagnostics() -> [String: String]
}

/// Common error types for LLM services
public enum LLMError: Error, CustomStringConvertible {
    case queryFailed(String)
    case modelNotAvailable
    case responseParsingFailed
    case connectionFailed
    case timeoutError

    public var description: String {
        switch self {
        case .queryFailed(let reason):
            return "Query failed: \(reason)"
        case .modelNotAvailable:
            return "LLM model is not available. Make sure the model is installed/accessible."
        case .responseParsingFailed:
            return "Failed to parse the response from the LLM."
        case .connectionFailed:
            return "Failed to connect to the LLM service. Make sure the service is running and accessible."
        case .timeoutError:
            return "Request timed out. The LLM service took too long to respond."
        }
    }
}

/// Factory for creating LLM services
public enum LLMServiceFactory {
    /// Create a local LLM service (Ollama)
    public static func createLocalService(
        baseURL: URL = URL(string: "http://localhost:11434/api")!,
        modelName: String = "llama3",
        systemPrompt: String? = nil,
        timeoutInterval: TimeInterval = 1800
    ) -> LLMServiceProtocol {
        // Try to load config from file
        let config = loadConfiguration()
        let serviceType = config["service"] as? String ?? "local"

        let configURL = config["baseURL"] as? String ?? "http://localhost:11434/api"
        // Only use config model if service type matches
        let configModel = (serviceType == "local" && config["model"] != nil) ? (config["model"] as? String ?? "llama3") : "llama3"

        // Override with explicit parameters if provided
        let finalBaseURL = baseURL.absoluteString != "http://localhost:11434/api" ? baseURL : URL(string: configURL)!
        let finalModel = modelName != "llama3" ? modelName : configModel
        let configTimeout = config["timeout"] as? Double ?? 1800.0
        let finalTimeout = timeoutInterval != 1800 ? timeoutInterval : configTimeout

        return LLMService(baseURL: finalBaseURL, modelName: finalModel, systemPrompt: systemPrompt, timeoutInterval: finalTimeout)
    }

    /// Create a remote LLM service (OpenAI)
        public static func createRemoteService(
            apiKey: String? = nil,
            baseURL: URL = URL(string: "https://api.openai.com/v1")!,
            modelName: String = "gpt-3.5-turbo",
            systemPrompt: String? = nil,
            timeoutInterval: TimeInterval = 600
        ) -> LLMServiceProtocol {
            // Try to load config from file
            let config = loadConfiguration()
            let serviceType = config["service"] as? String ?? "local"

            let configApiKey = config["apiKey"] as? String
            // Only use config model if service type matches and it's not a local model
            let configModel: String
            if serviceType == "remote" && config["model"] != nil {
                configModel = config["model"] as? String ?? "gpt-3.5-turbo"
            } else {
                configModel = "gpt-3.5-turbo"  // Default for OpenAI
            }

            let configTimeout = config["timeout"] as? Double ?? 600.0

            // Use provided API key or config, or throw error if none exists
            guard let finalApiKey = apiKey ?? configApiKey else {
                fatalError("API key is required for remote LLM service")
            }

            // Override with explicit parameters if provided
            var finalModel = modelName != "gpt-3.5-turbo" ? modelName : configModel

            // Ensure we're using a compatible model for remote API
            finalModel = ensureRemoteCompatibleModel(finalModel)

            let finalTimeout = timeoutInterval != 600 ? timeoutInterval : configTimeout

            return RemoteLLMService(apiKey: finalApiKey, baseURL: baseURL, modelName: finalModel,
                                   systemPrompt: systemPrompt, timeoutInterval: finalTimeout)
        }

    /// Create the appropriate service based on configuration
    public static func createFromConfig(
        apiKey: String? = nil,
        systemPrompt: String? = nil
    ) -> LLMServiceProtocol {
        // Load configuration
        let config = loadConfiguration()
        let serviceType = config["service"] as? String ?? "local"

        if serviceType == "remote" {
            // For remote service, force a remote-compatible model
            let defaultRemoteModel = "gpt-3.5-turbo"
            return createRemoteService(apiKey: apiKey, modelName: defaultRemoteModel, systemPrompt: systemPrompt)
        } else {
            // For local service, force a local-compatible model
            let defaultLocalModel = "llama3"
            return createLocalService(modelName: defaultLocalModel, systemPrompt: systemPrompt, timeoutInterval: 1800)
        }
    }

    /// Ensure that model name is compatible with remote API
    private static func ensureRemoteCompatibleModel(_ modelName: String) -> String {
        // List of known local-only models
        let localModels = ["llama3", "llama3:8b", "llama3:70b", "mistral", "mixtral", "codellama"]

        // If model name is a known local-only model, use a default remote model
        if localModels.contains(modelName.lowercased()) {
            print("⚠️ Model '\(modelName)' is not compatible with remote API, using 'gpt-3.5-turbo' instead")
            return "gpt-3.5-turbo"
        }

        return modelName
    }

    /// Load configuration from file
    private static func loadConfiguration() -> [String: Any] {
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".blkbox")
        let configPath = configDir.appendingPathComponent("config.json").path

        // Default configuration
        var config: [String: Any] = [
            "service": "local",
            "model": "llama3",
            "timeout": 600,
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

        return config
    }
}
