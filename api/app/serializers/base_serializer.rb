class BaseSerializer
  attr_reader :object, :options

  def initialize(object, **options)
    @object = object
    @options = options
  end

  def self.collection(records, **options)
    records.map { |r| new(r, **options).as_json }
  end

  def money(value)
    value&.to_s("F")
  end
end
