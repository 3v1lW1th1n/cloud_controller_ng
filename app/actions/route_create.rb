module VCAP::CloudController
  class RouteCreate
    class Error < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(message:, space:, domain:)
      route = Route.new(
        host: message.host || '',
        path: message.path || '',
        space_guid: message.space_guid,
        domain_guid: message.domain_guid
      )

      Route.db.transaction do
        route.save

        MetadataUpdate.update(route, message)
      end

      Repositories::RouteEventRepository.new.record_route_create(
        route,
        @user_audit_info,
        message.audit_hash,
        manifest_triggered: false,
      )
      route
    rescue Sequel::ValidationFailed => e
      validation_error!(e, route.host, route.path, space, domain)
    end

    private

    def validation_error!(error, host, path, space, domain)
      if error.errors.on(:domain)&.include?(:invalid_relation)
        error!("Invalid domain. Domain '#{domain.name}' is not available in organization '#{space.organization.name}'.")
      end

      if error.errors.on(:space)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for space '#{space.name}'.")
      end

      if error.errors.on(:organization)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for organization '#{space.organization.name}'.")
      end

      validation_error_host!(error, host, domain)
      validation_error_path!(error, host, path, domain)

      error!(error.message)
    end

    def validation_error_host!(error, host, domain)
      if error.errors.on(:host)&.include?(:domain_conflict)
        error!("Route conflicts with domain '#{host}.#{domain.name}'.")
      end

      if error.errors.on(:host)&.include?(:system_hostname_conflict)
        error!('Route conflicts with a reserved system route.')
      end

      if error.errors.on(:host)&.include?(:wildcard_host_not_supported_for_internal_domain)
        error!('Wildcard hosts are not supported for internal domains.')
      end

      if error.errors.on(:host)&.include?('is required for shared-domains')
        error!('Missing host. Routes in shared domains must have a host defined.')
      end

      if error.errors.on(:host)&.include?('combined with domain name must be no more than 253 characters')
        error!('Host combined with domain name must be no more than 253 characters.')
      end

      if error.errors.on([:host, :domain_id])&.include?(:unique)
        if host.empty?
          error!("Route already exists for domain '#{domain.name}'.")
        else
          error!("Route already exists with host '#{host}' for domain '#{domain.name}'.")
        end
      end
    end

    def validation_error_path!(error, host, path, domain)
      if error.errors.on(:path)&.include?(:path_not_supported_for_internal_domain)
        error!('Paths are not supported for internal domains.')
      end

      if error.errors.on(:path)&.include?(:invalid_path)
        error!('Path is invalid.')
      end

      if error.errors.on(:path)&.include?(:path_exceeds_valid_length)
        error!('Path exceeds 128 characters.')
      end

      if error.errors.on(:path)&.include?(:single_slash)
        error!("Path cannot be a single '/'.")
      end

      if error.errors.on(:path)&.include?(:missing_beginning_slash)
        error!("Path is missing the beginning '/'.")
      end

      if error.errors.on(:path)&.include?(:path_contains_question)
        error!("Path cannot contain '?'.")
      end
      if error.errors.on([:host, :domain_id, :path])&.include?(:unique)
        if host.empty?
          error!("Route already exists with path '#{path}' for domain '#{domain.name}'.")
        else
          error!("Route already exists with host '#{host}' and path '#{path}' for domain '#{domain.name}'.")
        end
      end
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
