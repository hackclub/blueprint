RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "")
  config.openrouter_api_key = ENV.fetch("OPENROUTER_API_KEY", "")
end
