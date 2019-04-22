require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class DomainsListMessage < ListMessage
    register_allowed_keys [
      :names,
      :organization_guids
    ]

    validates_with NoAdditionalParamsValidator
    validates :names, allow_nil: true, array: true
    validates :organization_guids, allow_nil: true, array: true

    def self.from_params(params)
      super(params, %w(names organization_guids))
    end
  end
end
