module Matching
  class SupplierResolver
    SUFFIXES = /\b(inc|llc|ltd|limited|corp|corporation|co|gmbh|pvt|plc)\b\.?/i

    def self.call(name)
      return if name.blank?

      key = normalize(name)
      Supplier.active.find { |s| normalize(s.name) == key } ||
        Supplier.active.find { |s| normalize(s.name).include?(key) || key.include?(normalize(s.name)) }
    end

    def self.normalize(name)
      name.to_s.downcase.gsub(SUFFIXES, "").gsub(/[^a-z0-9]+/, " ").squish
    end
  end
end
