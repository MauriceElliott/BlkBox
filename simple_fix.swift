// The issue is with the Ollama API endpoint in LLMService.swift

/*
1. The problem:
   BlkBox is using "/api/models" to check for available models in Ollama,
   but Ollama actually uses "/api/tags" for this purpose.

2. The fix:
   In LLMService.swift, we need to modify the API endpoint in two places:

   a) In isModelAvailable():
      Change:
      let endpoint = baseURL.appendingPathComponent("models")
      To:
      let endpoint = baseURL.appendingPathComponent("tags")

   b) In listAvailableModels():
      Change:
      let endpoint = baseURL.appendingPathComponent("models")
      To:
      let endpoint = baseURL.appendingPathComponent("tags")
*/

// This fixes the 404 error when checking for model availability
// and ensures BlkBox can properly detect models installed in Ollama.
