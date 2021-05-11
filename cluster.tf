locals {
  cluster_name = "my-eks-cluster"
  cluster_version = "1.18"
}

module "vpc" {
  source = "git::ssh://git@github.com/reactiveops/terraform-vpc.git?ref=v5.0.1"

  aws_region = "us-east-2"
  az_count   = 3
  aws_azs    = "us-east-2a, us-east-2b, us-east-2c"

  global_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }
}

module "eks" {
  source       = "git::https://github.com/terraform-aws-modules/terraform-aws-eks.git?ref=v12.2.0"
  cluster_name = local.cluster_name
  cluster_version = local.cluster_version
  vpc_id       = module.vpc.aws_vpc_id
  subnets      = module.vpc.aws_subnet_private_prod_ids

  node_groups = {
    eks_nodes = {
      desired_capacity = 3
      max_capacity     = 3
      min_capaicty     = 3

      instance_type = "t2.small"
    }
  }
  manage_aws_auth = false
}

resource "aws_iam_role" "iam_role_fargate" {
  name = "eks-fargate-profile-example"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}
resource "aws_iam_role_policy_attachment" "example-AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.iam_role_fargate.name
}
resource "aws_eks_fargate_profile" "aws_eks_fargate_profile1" {

  depends_on = [module.eks]

  cluster_name           = local.cluster_name
  fargate_profile_name   = "fg_profile_default_namespace"
  pod_execution_role_arn = aws_iam_role.iam_role_fargate.arn
  subnet_ids             = module.vpc.aws_subnet_private_prod_ids
  selector {
    namespace = "default"
  }
}