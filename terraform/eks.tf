module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0" # v21 is needed for AWS provider 6.x

  name               = var.cluster_name
  kubernetes_version = "1.33"

  vpc_id     = aws_vpc.task_app_vpc.id
  subnet_ids = aws_subnet.private[*].id

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.micro"]
      min_size       = 2
      max_size       = 3
      desired_size   = 2
      key_name = "RvkSinghOutlookAWS"
    }
  }
}