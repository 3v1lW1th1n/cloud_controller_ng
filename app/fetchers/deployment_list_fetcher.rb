module VCAP::CloudController
  class DeploymentListFetcher
    def initialize(message:)
      @message = message
    end

    def fetch_all
      filter(AppModel.select(:id))
    end

    def fetch_for_spaces(space_guids:)
      app_dataset = AppModel.where(space_guid: space_guids)
      filter(app_dataset)
    end

    private

    attr_reader :message

    def filter(app_dataset)
      dataset = filter_deployment_dataset(DeploymentModel.dataset)

      if message.requested? :app_guids
        app_dataset = app_dataset.where(guid: message.app_guids)
      end

      dataset.where(app: app_dataset)
    end

    def filter_deployment_dataset(dataset)
      if message.requested? :states
        dataset = dataset.where(state: message.states)
      end

      if message.requested? :status_reasons
        dataset = NullFilterQueryGenerator.add_filter(dataset, :status_reason, message.status_reasons)
      end

      if message.requested? :status_values
        dataset = dataset.where(status_value: message.status_values)
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: DeploymentLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: DeploymentModel,
        )
      end

      dataset
    end
  end
end
