
resource "aws_db_subnet_group" "task_app_db" {
  name = "task-app-db-subnet-group"

  subnet_ids          = aws_subnet.private[*].id   # in aws_db_subnet_group

  tags = {
    Name = "task-app-db-subnet-group"
  }
}

resource "aws_db_instance" "task_app_db" {
  identifier = "task-app-postgres"

  allocated_storage = 20
  storage_type      = "gp3"

  engine         = "postgres"
  engine_version = "17.11"
  instance_class = "db.t3.micro"

  db_name  = "task_app_db"
  username = var.db_username
  password = var.db_password

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.task_app_db.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = true
  multi_az             = false

  backup_retention_period = 1

  storage_encrypted = true

  skip_final_snapshot = true
  deletion_protection  = false

  tags = {
    Name        = "task-app-postgres"
    Environment = "development"
  }
}
