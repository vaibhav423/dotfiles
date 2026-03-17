return {
  "yetone/avante.nvim",
  optional = true,
  opts = {
    provider = "gemini",
    auto_suggestions_provider = "gemini",
    providers = {
      gemini = {
        endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
        model = "gemini-3-flash-preview",
        timeout = 30000,
        extra_request_body = {
          temperature = 0.75,
          maxOutputTokens = 8192,
        },
      },
    },
  },
}
