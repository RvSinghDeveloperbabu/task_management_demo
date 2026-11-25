
output "rds_endpoint" {
  value = aws_db_instance.task_app_db.address
}

output "rds_port" {
  value = aws_db_instance.task_app_db.port
}

output "rds_database_url" {
  description = "Rails PostgreSQL connection URL"
  sensitive   = true

  value = format(
    "postgresql://%s:%s@%s:%d/%s?sslmode=verify-full&sslrootcert=/app/config/certs/global-bundle.pem",
    var.db_username,
    urlencode(var.db_password),
    aws_db_instance.task_app_db.address,
    aws_db_instance.task_app_db.port,
    aws_db_instance.task_app_db.db_name
  )
}

output "cluster_name"    { value = module.eks.cluster_name }
output "lb_controller_role_arn" { value = module.lb_controller_role.iam_role_arn }