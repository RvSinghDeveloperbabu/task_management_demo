Task.find_or_create_by!(title: "Welcome - delete me") do |task|
  task.status = "done"
  task.result = "Seeded"
  task.processed_at = Time.current
end
