class TasksController < ApplicationController
  def index
    tasks = Task.order(created_at: :desc).limit(50)
    render json: tasks.map { |task| serialize(task) }
  end

  def create
    task = Task.new(task_params)

    if task.save
      # The slow work happens in a Sidekiq worker, not in the web request.
      TaskProcessorJob.perform_async(task.id)
      render json: serialize(task), status: :created
    else
      render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    Task.find(params[:id]).destroy!
    head :no_content
  end

  private

  def task_params
    params.require(:task).permit(:title)
  end

  def serialize(task)
    task.as_json(only: %i[id title status result processed_at created_at])
  end
end
