#Terraform module combining a hardened EKS cluster with a secure VPC. 
# The terraform code assumes that the RDS, Elasticache operate in dedicated, private subnets. And that the workloads in private subnet communicates with EKS using security groups. A NAT gateway is used for egress. 


module "secure_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "4.1.0"

  name = "secure-health-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.107.0/24", "10.0.108.0/24"]
  database_subnets = ["10.0.11.0/24", "10.0.13.0/24"]

  enable_nat_gateway     = true
  enable_dns_hostnames   = true
  enable_dns_support     = true
  create_igw             = true

  tags = {
    Environment = "NonProd"
    Project     = "health-microservice"
  }
}

module "eks_cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.8.3"

  cluster_name    = "hipaacompliant-eks"
  cluster_version = "1.29"

  vpc_id          = module.secure_vpc.vpc_id
  subnet_ids      = module.secure_vpc.private_subnets

  enable_irsa = true

  eks_managed_node_groups = {
    baseline = {
      instance_types = ["t3.medium"]
      desired_capacity = 2
      min_size         = 4
      max_size         = 7
      subnet_ids       = module.secure_vpc.private_subnets

      tags = {
        NodeGroup = "securebaseline"
      }
    }
  }

  node_security_group_additional_rules = {
    ingress_all_worker_nodes = {
      description = "Allow node-to-node communication"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
  }

  cluster_enabled_log_types = ["api", "audit", "authenticator"]

  create_cloudwatch_log_group = true

  tags = {
    Environment = "nonprod"
    Project     = "health-microservice"
  }
}

resource "aws_security_group" "db_access" {
  name        = "rds-elasticache-access"
  description = "Allow EKS access to RDS and ElastiCache"
  vpc_id      = module.secure_vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    description = "PostgreSQL from EKS"
    security_groups = [module.eks_cluster.node_security_group_id]
  }

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    description = "Allow EKS access Redis"
    security_groups = [module.eks_cluster.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "db-cache-access"
    Environment = "health-microservice"
  }
}
