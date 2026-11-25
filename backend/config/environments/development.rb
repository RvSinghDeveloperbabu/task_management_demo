require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
  config.active_support.deprecation = :log
  config.active_record.verbose_query_logs = true

  # Allow any Host header in development (docker, tunnels, etc.)
  config.hosts.clear
end
