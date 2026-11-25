
resource "aws_subnet" "rds_public" {
  count = 2

  vpc_id = aws_vpc.task_app_vpc.id

  availability_zone = [
    "ap-southeast-2a",
    "ap-southeast-2b"
  ][count.index]

  cidr_block = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ][count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "task-app-rds-public-${count.index + 1}"
  }
}

resource "aws_route_table" "rds_public" {
  vpc_id = aws_vpc.task_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task_app_igw.id
  }

  tags = {
    Name = "task-app-rds-public-rt"
  }
}

resource "aws_route_table_association" "rds_public" {
  count = 2

  subnet_id      = aws_subnet.rds_public[count.index].id
  route_table_id = aws_route_table.rds_public.id
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.task_app_vpc.id
  availability_zone = ["ap-southeast-2a", "ap-southeast-2b"][count.index]
  cidr_block        = ["10.0.11.0/24", "10.0.12.0/24"][count.index]

  tags = {
    Name                              = "task-app-private-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.rds_public[0].id
  depends_on    = [aws_internet_gateway.task_app_igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.task_app_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "task-app-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}