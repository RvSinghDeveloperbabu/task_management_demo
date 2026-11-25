require "socket"
require "sidekiq/api"

# Shows which pod answered and how many Sidekiq workers are alive.
# Handy for watching load-balancing and scaling in Kubernetes.
class InfoController < ApplicationController
  def show
    render json: {
      pod: Socket.gethostname,
      environment: Rails.env,
      sidekiq: sidekiq_stats
    }
  end

  private

  def sidekiq_stats
    stats = Sidekiq::Stats.new
    {
      processes: stats.processes_size,
      enqueued: stats.enqueued,
      processed: stats.processed,
      failed: stats.failed
    }
  rescue StandardError => e
    Rails.logger.warn("Sidekiq stats unavailable: #{e.class}: #{e.message}")
    nil
  end
end
