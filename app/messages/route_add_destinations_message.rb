module VCAP::CloudController
  class RouteAddDestinationsMessage < BaseMessage
    register_allowed_keys [:destinations]

    validates_with NoAdditionalKeysValidator

    validates :destinations, array: true, allow_nil: false, presence: true
    validate :destinations_valid?

    private

    ERROR_MESSAGE = 'Destinations must have the structure "destinations": [{"app": {"guid": "app_guid"}}]'.freeze

    def destinations_valid?
      unless destinations.is_a?(Array) && (1...100).cover?(destinations.length)
        errors.add(:base, 'Destinations must be an array containing between 1 and 100 destination objects')
        return
      end

      validate_destination_contents
    end

    def validate_destination_contents
      destinations.each do |dst|
        unless dst.is_a?(Hash) && dst.keys == [:app]
          errors.add(:base, ERROR_MESSAGE)
          break
        end

        break unless valid_app?(dst[:app])
      end
    end

    def valid_app?(app)
      unless app.is_a?(Hash) && valid_guid?(app[:guid])
        errors.add(:base, ERROR_MESSAGE)
        return false
      end

      unless valid_process?(app[:process])
        errors.add(:base, 'Process must have the structure "process": {"type": "type"}')
        return false
      end
    end

    def valid_process?(process)
      if process.nil?
        return true
      end

      process.is_a?(Hash) && process.keys == [:type] && process[:type].is_a?(String)
    end

    def valid_guid?(guid)
      guid.is_a?(String) && (1...200).cover?(guid.size)
    end
  end
end
