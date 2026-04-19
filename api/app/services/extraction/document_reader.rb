module Extraction
  # Turns an attachment into something an extractor can consume: plain text
  # when the document has a text layer, otherwise the raw bytes for a vision model.
  class DocumentReader
    Payload = Struct.new(:text, :bytes, :content_type, :filename, keyword_init: true) do
      def text? = text.present?
    end

    MAX_TEXT_CHARS = 30_000

    def initialize(attachment)
      @attachment = attachment
    end

    def call
      content_type = attachment.blob.content_type
      bytes = attachment.download

      text = case content_type
             when "application/pdf" then pdf_text(bytes)
             when "text/plain" then bytes.force_encoding("UTF-8").scrub
             end

      Payload.new(text: text&.strip&.slice(0, MAX_TEXT_CHARS), bytes: bytes, content_type: content_type,
                  filename: attachment.blob.filename.to_s)
    end

    private

    attr_reader :attachment

    def pdf_text(bytes)
      reader = PDF::Reader.new(StringIO.new(bytes))
      text = reader.pages.first(10).map(&:text).join("\n\n")
      text.gsub(/[ \t]+/, " ").presence
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError
      nil
    end
  end
end
