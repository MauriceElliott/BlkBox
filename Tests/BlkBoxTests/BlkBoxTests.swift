import XCTest
@testable import BlkBoxLib

final class BlkBoxTests: XCTestCase {
    func testNotesManagerInitialization() throws {
        let notesManager = NotesManager()
        XCTAssertNotNil(notesManager)
    }

    func testLLMServiceInitialization() throws {
        let llmService = LLMService()
        XCTAssertNotNil(llmService)
    }

    func testBlkBoxShellInitialization() throws {
        let shell = BlkBoxShell()
        XCTAssertNotNil(shell)
    }

    func testConfigManagerInitialization() throws {
        let configManager = ConfigManager()
        XCTAssertNotNil(configManager)

        let config = configManager.getConfig()
        XCTAssertFalse(config.notesPath.isEmpty)
        XCTAssertFalse(config.llm.baseURL.isEmpty)
        XCTAssertFalse(config.llm.modelName.isEmpty)
    }

    func testSystemPromptGeneration() {
        let defaultPrompt = SystemPrompt.getDefaultPrompt()
        XCTAssertFalse(defaultPrompt.isEmpty)
        XCTAssertTrue(defaultPrompt.contains("BlkBox"))

        let insightsPrompt = SystemPrompt.getInsightsPrompt()
        XCTAssertFalse(insightsPrompt.isEmpty)
        XCTAssertTrue(insightsPrompt.contains("insights"))

        let categorizationPrompt = SystemPrompt.getCategorizationPrompt()
        XCTAssertFalse(categorizationPrompt.isEmpty)
        XCTAssertTrue(categorizationPrompt.contains("categorizing"))

        let retrievalPrompt = SystemPrompt.getRetrievalPrompt()
        XCTAssertFalse(retrievalPrompt.isEmpty)
        XCTAssertTrue(retrievalPrompt.contains("searching"))
    }

    func testParseInsightsResponse() {
        // This is a simple test to check if the parsing logic works
        // In a real test suite, you would have more comprehensive tests
        let mockResponse = """
        Here are some insights from your notes:

        1. You've been consistently interested in Swift programming since 2022.
        2. There are several recurring themes in your project ideas: AI, productivity, and data visualization.

        Additional observations:
        - You often take notes about books but rarely follow up on them.
        - Most of your task lists are for short-term projects.
        """

        let notesManager = NotesManager()
        // This test is calling a private method which isn't ideal for unit testing
        // In a real project, you might want to refactor to make this more testable
        let insights = notesManager.parseInsightsResponse(mockResponse)

        XCTAssertEqual(insights.count, 4)
        XCTAssertTrue(insights[0].contains("Swift programming"))
        XCTAssertTrue(insights[1].contains("recurring themes"))
    }
}
