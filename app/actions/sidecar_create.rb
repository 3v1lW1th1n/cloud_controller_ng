module VCAP::CloudController
  class SidecarCreate
    class InvalidSidecar < StandardError
    end

    class << self
      def create(app_guid, message)
        logger = Steno.logger('cc.action.sidecar_create')

        validate_memory_allocation!(app_guid, message) if message.requested?(:memory_in_mb) || message.requested?(:memory)

        sidecar = SidecarModel.new(
          app_guid: app_guid,
          name:     message.name,
          command:  message.command,
          memory:  message.memory_in_mb,
        )

        SidecarModel.db.transaction do
          sidecar.save
          message.process_types.each do |process_type|
            SidecarProcessTypeModel.create(type: process_type, sidecar_guid: sidecar.guid, app_guid: sidecar.app_guid)
          end
        end

        logger.info("Finished creating sidecar #{sidecar.guid}")
        sidecar
      rescue Sequel::ValidationFailed => e
        error = InvalidSidecar.new(e.message)
        error.set_backtrace(e.backtrace)
        raise error
      end

      private

      def validate_memory_allocation!(app_guid, message)
        processes = ProcessModel.where(
          app_guid: app_guid,
          type: message.process_types,
        )

        processes.each do |process|
          total_sidecar_memory = process.sidecars.sum(&:memory) + message.memory_in_mb

          if total_sidecar_memory >= process.memory
            raise InvalidSidecar.new("The memory allocation defined is too large to run with the dependent \"#{process.type}\" process")
          end
        end
      end
    end
  end
end
