require "socket"

# Simulates slow background work. Safe to retry: it exits early if the task
# was deleted or is already done, so Sidekiq retries never double-process.
class TaskProcessorJob
  include Sidekiq::Job

  sidekiq_options queue: "default", retry: 3

  PROCESSING_SECONDS = Integer(ENV.fetch("TASK_PROCESSING_SECONDS", 5))

  def perform(task_id)
    task = Task.find_by(id: task_id)
    return if task.nil? || task.done?

    task.update!(status: "processing")
    sleep PROCESSING_SECONDS

    task.update!(
      status: "done",
      result: "Processed by worker pod #{Socket.gethostname}",
      processed_at: Time.current
    )
  end
end
