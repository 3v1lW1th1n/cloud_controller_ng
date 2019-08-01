class PortsPolicy
  def initialize(process)
    @process          = process
    @errors           = process.errors
  end

  def validate
    return if @process.ports.nil? || @process.ports.empty?
    return @errors.add(:base, 'Processes may have at most 10 exposed ports.') if ports_limit_exceeded?
    return @errors.add(:base, 'Ports must be integers.') unless all_ports_are_integers?
    return @errors.add(:base, 'Ports must be in the 1024-65535 range.') unless all_ports_are_in_range?

    unless verify_ports
      @errors.add(:base,
        'App ports may not be removed while routes are mapped to them. '\
        'To change the app port a route is mapped to add the new ports to your app, '\
        'change the app port the route is mapped to, then remove unused app ports.'
      )
    end
  end

  private

  def verify_ports
    @process.route_mappings.each do |m|
      if m.app_port.blank?
        return false unless @process.ports.include?(VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
      elsif !@process.ports.include?(m.app_port)
        return false if m.app_port != VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED
      end
    end
  end

  def all_ports_are_integers?
    @process.ports.all? { |port| port.is_a? Integer }
  end

  def all_ports_are_in_range?
    @process.ports.all? do |port|
      port > 1023 && port <= 65535
    end
  end

  def ports_limit_exceeded?
    @process.ports.length > 10
  end
end
