module VCAP::CloudController
  class UaaClient
    attr_reader :uaa_target, :client_id, :secret, :ca_file, :http_timeout

    def self.default_http_timeout
      @default_http_timeout ||= VCAP::CloudController::Config.config.get(:uaa, :client_timeout)
    end

    def auth_header
      token = UaaTokenCache.get_token(client_id)
      return token if token

      UaaTokenCache.set_token(client_id, token_info.auth_header, expires_in: token_info.info['expires_in'])
      token_info.auth_header
    end

    def initialize(uaa_target:, client_id:, secret:, ca_file:)
      @uaa_target = uaa_target
      @client_id = client_id
      @secret = secret
      @ca_file = ca_file
      @http_timeout = self.class.default_http_timeout
    end

    def get_clients(client_ids)
      client_ids.map do |id|
        begin
          get(:client, id)
        rescue CF::UAA::NotFound
          nil
        end
      end.compact
    end

    def token_info
      token_issuer.client_credentials_grant
    rescue CF::UAA::NotFound, CF::UAA::BadTarget, CF::UAA::BadResponse => e
      logger.error("UAA request for token failed: #{e.inspect}")
      raise UaaUnavailable.new
    end

    def users_for_ids(user_ids)
      fetch_users(user_ids)
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve usernames from UAA: #{e.inspect}")
      {}
    end

    def usernames_for_ids(user_ids)
      fetch_users(user_ids).map { |id, user| [id, user['username']] }.to_h
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve usernames from UAA: #{e.inspect}")
      {}
    end

    def id_for_username(username, origin: nil)
      filter_string = %(username eq "#{username}")
      filter_string = %/origin eq "#{origin}" and #{filter_string}/ if origin.present?
      results = query(:user_id, includeInactive: true, filter: filter_string)

      user = results['resources'].first
      user && user['id']
    rescue CF::UAA::TargetError
      raise UaaEndpointDisabled
    end

    def origins_for_username(username)
      filter_string = %(username eq "#{username}")
      results = query(:user_id, includeInactive: true, filter: filter_string)

      results['resources'].map { |resource| resource['origin'] }
    rescue UaaUnavailable, CF::UAA::UAAError => e
      logger.error("Failed to retrieve origins from UAA: #{e.inspect}")
      raise UaaUnavailable.new(e)
    end

    def info
      CF::UAA::Info.new(uaa_target, uaa_connection_opts)
    end

    private

    def query(type, **opts)
      with_cache_retry { scim.query(type, **opts) }
    end

    def get(type, id)
      with_cache_retry { scim.get(type, id) }
    end

    def with_cache_retry
      yield
    rescue CF::UAA::InvalidToken
      UaaTokenCache.clear_token(client_id)
      yield
    end

    def scim
      CF::UAA::Scim.new(uaa_target, auth_header, uaa_connection_opts)
    end

    def fetch_users(user_ids)
      return {} unless user_ids.present?

      filter_string = user_ids.map { |user_id| %(id eq "#{user_id}") }.join(' or ')
      results = query(:user_id, filter: filter_string)

      results['resources'].each_with_object({}) do |resource, results_hash|
        results_hash[resource['id']] = resource
        results_hash
      end
    end

    def token_issuer
      CF::UAA::TokenIssuer.new(uaa_target, client_id, secret, uaa_connection_opts)
    end

    def uaa_connection_opts
      {
        skip_ssl_validation: false,
        ssl_ca_file: ca_file,
        http_timeout: http_timeout
      }
    end

    def logger
      @logger ||= Steno.logger('cc.uaa_client')
    end
  end
end
