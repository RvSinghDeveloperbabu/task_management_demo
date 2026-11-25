max_threads = ENV.fetch("RAILS_MAX_THREADS", 5).to_i

threads max_threads, max_threads
port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

# One process per pod: scale with replicas (HPA) rather than Puma workers.
workers ENV.fetch("WEB_CONCURRENCY", 0).to_i

plugin :tmp_restart
