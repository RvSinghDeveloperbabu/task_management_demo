require "socket"

class HealthController < ApplicationController
  # Liveness probe: no dependencies, just "is the process serving requests?"
  def live
    render json: { status: "ok" }
  end

  # Readiness probe: only receive traffic when Postgres and Redis are reachable.
  def ready
    checks = { database: check { ActiveRecord::Base.connection.execute("SELECT 1") },
               redis: check { Sidekiq.redis { |conn| conn.call("PING") } } }

    healthy = checks.values.all?
    render json: { status: healthy ? "ok" : "unavailable", checks: checks, pod: Socket.gethostname },
           status: healthy ? :ok : :service_unavailable
  end

  private

  def check
    yield
    true
  rescue StandardError => e
    Rails.logger.warn("Readiness check failed: #{e.class}: #{e.message}")
    false
  end
end
