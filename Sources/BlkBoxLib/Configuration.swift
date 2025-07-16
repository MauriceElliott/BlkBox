import Foundation
import Yams

/// Configuration for the BlkBox application
public struct BlkBoxConfig: Codable {
    /// Path to the notes directory
    public var notesPath: String

    /// LLM configuration
    public var llm: LLMConfig

    /// UI configuration
    public var ui: UIConfig

    /// Default file extensions to look for
    public var fileExtensions: [String]

    /// Default categories for notes organization
    public var defaultCategories: [String]

    /// Initialize with default values
    public init(
        notesPath: String? = nil,
        llm: LLMConfig = LLMConfig(),
        ui: UIConfig = UIConfig(),
        fileExtensions: [String] = [".md", ".txt"],
        defaultCategories: [String] = ["daily", "projects", "reference", "tasks", "personal"]
    ) {
        self.notesPath = notesPath ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.blkbox/notes"
        self.llm = llm
        self.ui = ui
        self.fileExtensions = fileExtensions
        self.defaultCategories = defaultCategories
    }
}

/// Configuration for the LLM service
public struct LLMConfig: Codable {
    /// Base URL for LLM API
    public var baseURL: String

    /// Model name to use
    public var modelName: String

    /// System prompt for the LLM
    public var systemPrompt: String?

    /// Initialize with default values
    public init(
        baseURL: String = "http://localhost:11434/api",
        modelName: String = "llama3",
        systemPrompt: String? = nil
    ) {
        self.baseURL = baseURL
        self.modelName = modelName
        self.systemPrompt = systemPrompt
    }
}

/// Configuration for the UI
public struct UIConfig: Codable {
    /// Whether to use colors in terminal output
    public var useColors: Bool

    /// Whether to use emojis in terminal output
    public var useEmoji: Bool

    /// Whether to show detailed error messages
    public var verboseErrors: Bool

    /// Initialize with default values
    public init(
        useColors: Bool = true,
        useEmoji: Bool = true,
        verboseErrors: Bool = false
    ) {
        self.useColors = useColors
        self.useEmoji = useEmoji
        self.verboseErrors = verboseErrors
    }
}

/// Manager for BlkBox configuration
public class ConfigManager {
    private let configFilePath: String
    private var config: BlkBoxConfig

    /// Initialize with default or provided config path
    public init(configPath: String? = nil) {
        self.configFilePath = configPath ?? "\(FileManager.default.homeDirectoryForCurrentUser.path)/.blkbox/config.yml"

        // Try to load config from file or use defaults
        if let loadedConfig = try? ConfigManager.loadFromFile(path: configFilePath) {
            self.config = loadedConfig
        } else {
            self.config = BlkBoxConfig()
            try? self.saveConfig() // Create default config file
        }
    }

    /// Get the current configuration
    public func getConfig() -> BlkBoxConfig {
        return config
    }

    /// Update the configuration
    public func updateConfig(_ newConfig: BlkBoxConfig) throws {
        self.config = newConfig
        try saveConfig()
    }

    /// Save the configuration to file
    public func saveConfig() throws {
        let encoder = YAMLEncoder()
        let yaml = try encoder.encode(config)

        // Ensure directory exists
        let directoryPath = (configFilePath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directoryPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Write config file
        try yaml.write(toFile: configFilePath, atomically: true, encoding: .utf8)
    }

    /// Load configuration from file
    public static func loadFromFile(path: String) throws -> BlkBoxConfig {
        let yaml = try String(contentsOfFile: path, encoding: .utf8)
        let decoder = YAMLDecoder()
        return try decoder.decode(BlkBoxConfig.self, from: yaml)
    }

    /// Get the path to the configuration file
    public func getConfigFilePath() -> String {
        return configFilePath
    }

    /// Update the LLM model name
    public func updateLLMModel(_ modelName: String) throws {
        var updatedConfig = config
        updatedConfig.llm.modelName = modelName
        try updateConfig(updatedConfig)
    }

    /// Update the notes path
    public func updateNotesPath(_ path: String) throws {
        var updatedConfig = config
        updatedConfig.notesPath = path
        try updateConfig(updatedConfig)
    }

    /// Update the system prompt
    public func updateSystemPrompt(_ prompt: String?) throws {
        var updatedConfig = config
        updatedConfig.llm.systemPrompt = prompt
        try updateConfig(updatedConfig)
    }
}
