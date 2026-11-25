
resource "aws_security_group" "rds_sg" {
  name        = "task-app-rds-sg"
  description = "Allow PostgreSQL from my local machine"
  vpc_id      = aws_vpc.task_app_vpc.id

  ingress {
    description = "PostgreSQL from my public IP"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task-app-rds-sg"
  }
}

resource "aws_security_group_rule" "rds_from_eks_nodes" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = module.eks.node_security_group_id
  description              = "PostgreSQL from EKS nodes"
}