# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-pradeep-azure this is s3 bucket
# AKIAXEFUNMTNK2UGHX4U access key


terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {

}

# data "aws_eks_cluster" "cluster" {
#    name = module.in28minutes-cluster.cluster_name
#  }

# data "aws_eks_cluster_auth" "cluster" {
#   name = module.in28minutes-cluster.cluster_name
# }

# data "aws_subnet_ids" "subnets" {
#   vpc_id = aws_default_vpc.default.id
# }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token

}

module "in28minutes-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "in28minutes-cluster"
  cluster_version = "1.29"
  subnet_ids        = ["subnet-01783d2ee856c94ba", "subnet-0b065fa419ec7369f", "subnet-0dc1852e40cd05101"] #CHANGE
  #subnets = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id

  #vpc_id         = "vpc-1234556abcdef"
  cluster_endpoint_public_access  = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "node-group-1"
      instance_types = ["t2.micro"]
      min_size        = 3
      max_size        = 5
      desired_size    = 3
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.in28minutes-cluster.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.in28minutes-cluster.cluster_name
}


# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "User"
    name      = "terraform-aws-user"
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = "default"
  }
}

# Needed to set the default region
provider "aws" {
  region  = "us-east-1"
}