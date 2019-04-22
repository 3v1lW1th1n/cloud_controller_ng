module VCAP::CloudController
  class RevisionModel < Sequel::Model(:revisions)
    include Serializer

    many_to_one :app,
      class: '::VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true

    many_to_one :droplet,
      class:             '::VCAP::CloudController::DropletModel',
      key: :droplet_guid,
      primary_key: :guid,
      without_guid_generation: true

    one_to_many :labels,
      class: 'VCAP::CloudController::RevisionLabelModel',
      key: :resource_guid,
      primary_key: :guid

    one_to_many :annotations,
      class: 'VCAP::CloudController::RevisionAnnotationModel',
      key: :resource_guid,
      primary_key: :guid

    one_to_many :process_commands,
      class: 'VCAP::CloudController::RevisionProcessCommandModel',
      key: :revision_guid,
      primary_key: :guid

    set_field_as_encrypted :environment_variables, column: :encrypted_environment_variables
    serializes_via_json :environment_variables

    def validate
      super
      validates_presence [:app_guid, :droplet_guid]
    end

    def add_command_for_process_type(type, command)
      add_process_command(process_type: type, process_command: command)
    end

    def commands_by_process_type
      return {} unless droplet&.process_types # Unsure if this case ever actually happens outside of specs

      # revision_process_commands are not created when the process has not changed from the
      # droplet's original process_command (would just be storing a NULL for command), so go to
      # droplet to get all process command types
      droplet.process_types.keys.
        map { |k| [k, process_commands_dataset.first(process_type: k)&.process_command] }.to_h
    end
  end
end
