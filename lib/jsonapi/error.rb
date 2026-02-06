module JSONAPI
  class Error
    attr_accessor :title, :detail, :id, :href, :code, :source, :links, :status, :meta

    # Rack 3.0+ deprecated :unprocessable_entity in favor of :unprocessable_content
    # This mapping ensures compatibility across Rack versions
    DEPRECATED_STATUS_SYMBOLS = {
      unprocessable_entity: :unprocessable_content
    }.freeze

    def self.status_code_for(status_symbol)
      return nil if status_symbol.nil?

      # Try the symbol directly first
      code = Rack::Utils::SYMBOL_TO_STATUS_CODE[status_symbol]

      # If not found and it's a deprecated symbol, try the new symbol
      if code.nil? && DEPRECATED_STATUS_SYMBOLS.key?(status_symbol)
        code = Rack::Utils::SYMBOL_TO_STATUS_CODE[DEPRECATED_STATUS_SYMBOLS[status_symbol]]
      end

      code&.to_s
    end

    def initialize(options = {})
      @title          = options[:title]
      @detail         = options[:detail]
      @id             = options[:id]
      @href           = options[:href]
      @code           = if JSONAPI.configuration.use_text_errors
                          TEXT_ERRORS[options[:code]]
                        else
                          options[:code]
                        end
      @source         = options[:source]
      @links          = options[:links]

      @status         = self.class.status_code_for(options[:status])
      @meta           = options[:meta]
    end

    def to_hash
      hash = {}
      instance_variables.each {|var| hash[var.to_s.delete('@')] = instance_variable_get(var) unless instance_variable_get(var).nil? }
      hash
    end
  end

  class Warning
    attr_accessor :title, :detail, :code
    def initialize(options = {})
      @title          = options[:title]
      @detail         = options[:detail]
      @code           = if JSONAPI.configuration.use_text_errors
                          TEXT_ERRORS[options[:code]]
                        else
                          options[:code]
                        end
    end

    def to_hash
      hash = {}
      instance_variables.each {|var| hash[var.to_s.delete('@')] = instance_variable_get(var) unless instance_variable_get(var).nil? }
      hash
    end
  end
end
