module VCAP::CloudController
  class AppUsageEventAccess < BaseAccess
    def index?(object_class, params=nil)
      admin_user? || admin_read_only_user?
    end

    def reset?(_)
      admin_user?
    end

    def reset_with_token?(_)
      admin_user?
    end
  end
end