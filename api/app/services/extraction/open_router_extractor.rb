module Extraction
  class OpenRouterExtractor
    class Error < StandardError; end

    ENDPOINT = "https://openrouter.ai/api/v1/chat/completions".freeze
    DEFAULT_MODEL = "openai/gpt-4o-mini".freeze

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You extract structured data from supplier invoices for an accounts payable team.
      Return only values that are printed on the document; use null when a field is absent.
      Dates must be ISO 8601. Amounts are plain numbers without currency symbols or thousands separators.
      po_number is the buyer's purchase order reference if the invoice quotes one (labels like "PO", "P.O. #", "Your order").
      Each line item is one billed product or service; skip subtotal, tax and total rows.
      Set confidence lower when the document is blurry, handwritten, or fields are ambiguous.
    PROMPT

    def self.available?
      ENV["OPENROUTER_API_KEY"].present?
    end

    def initialize(api_key: ENV.fetch("OPENROUTER_API_KEY"), model: ENV.fetch("OPENROUTER_MODEL", DEFAULT_MODEL))
      @api_key = api_key
      @model = model
    end

    def call(payload)
      response = connection.post(ENDPOINT, request_body(payload))
      raise Error, "OpenRouter returned #{response.status}: #{response.body.to_s[0, 300]}" unless response.success?

      content = response.body.dig("choices", 0, "message", "content")
      raise Error, "Empty response from model" if content.blank?

      Result.from_raw(JSON.parse(content), source: "openrouter:#{model}")
    rescue JSON::ParserError => e
      raise Error, "Model returned invalid JSON: #{e.message}"
    rescue Faraday::Error => e
      raise Error, "OpenRouter request failed: #{e.message}"
    end

    private

    attr_reader :api_key, :model

    def request_body(payload)
      {
        model: model,
        temperature: 0,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: user_content(payload) }
        ],
        response_format: {
          type: "json_schema",
          json_schema: { name: "invoice", strict: true, schema: Schema::FIELDS }
        }
      }
    end

    def user_content(payload)
      if payload.text?
        [{ type: "text", text: "Extract the invoice fields from this document text:\n\n#{payload.text}" }]
      elsif payload.content_type == "application/pdf"
        [{ type: "text", text: "Extract the invoice fields from the attached PDF." },
         { type: "file", file: { filename: payload.filename, file_data: data_url(payload) } }]
      else
        [{ type: "text", text: "Extract the invoice fields from this invoice image." },
         { type: "image_url", image_url: { url: data_url(payload) } }]
      end
    end

    def data_url(payload)
      "data:#{payload.content_type};base64,#{Base64.strict_encode64(payload.bytes)}"
    end

    def connection
      Faraday.new do |f|
        f.request :json
        f.response :json
        f.options.timeout = 60
        f.options.open_timeout = 5
        f.headers["Authorization"] = "Bearer #{api_key}"
        f.headers["HTTP-Referer"] = ENV.fetch("APP_URL", "http://localhost:5173")
        f.headers["X-Title"] = "SpendFlow"
      end
    end
  end
end
