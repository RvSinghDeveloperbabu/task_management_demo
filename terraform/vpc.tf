
resource "aws_vpc" "task_app_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "task-app-vpc"
  }
}

resource "aws_internet_gateway" "task_app_igw" {
  vpc_id = aws_vpc.task_app_vpc.id

  tags = {
    Name = "task-app-igw"
  }
}
