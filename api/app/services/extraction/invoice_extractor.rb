module Extraction
  class InvoiceExtractor
    Error = Class.new(StandardError)

    def initialize(invoice, backend: self.class.default_backend)
      @invoice = invoice
      @backend = backend
    end

    def self.default_backend
      OpenRouterExtractor.available? ? OpenRouterExtractor.new : HeuristicExtractor.new
    end

    def call
      raise Error, "Invoice has no document attached" unless invoice.document.attached?

      payload = DocumentReader.new(invoice.document).call
      backend.call(payload)
    rescue OpenRouterExtractor::Error, HeuristicExtractor::Error, Result::Invalid => e
      raise Error, e.message
    end

    private

    attr_reader :invoice, :backend
  end
end
