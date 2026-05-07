terraform {
  backend "s3" {
    # Terraform forbids variables in `backend` blocks. Either replace
    # YOUR_ACCOUNT_ID below to match your AWS account, or pass
    # `-backend-config="bucket=..."` at `terraform init` time. tf_deploy_v7.sh
    # does the latter — it reads the bucket name from bootstrap output and
    # threads it in, so this literal is a fallback for manual runs.
    bucket         = "reliability-platform-v07-tfstate-YOUR_ACCOUNT_ID"
    key            = "shared/v7/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-v07"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ----------------------------------------------------------------------------
# Shared layer — the network foundation.
#
# Built once, changed rarely. Owns the VPC, public + private subnets across
# two AZs, IGW, and the public route table. Outputs are consumed by `live`
# via `terraform_remote_state` — no other layer may write to this state file.
#
# Two public + two private subnets is the EKS minimum for a multi-AZ cluster.
# The cluster-discovery tags on the public subnets let the in-tree
# LoadBalancer controller find them when web-ui's `Service type=LoadBalancer`
# provisions a Classic ELB.
# ----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "${var.project_name}-vpc"
    ManagedBy = "terraform"
    Layer     = "shared"
    Version   = var.version_suffix
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name      = "${var.project_name}-igw"
    ManagedBy = "terraform"
    Layer     = "shared"
  }
}

# Two public subnets in two AZs. EKS minimum for a highly-available cluster.
# `kubernetes.io/cluster/<name> = shared` and `kubernetes.io/role/elb = 1`
# tags are required by the in-tree LoadBalancer controller — without them,
# `Service type=LoadBalancer` stays in `<pending>` forever.
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                        = "${var.project_name}-public-${count.index + 1}"
    ManagedBy                                   = "terraform"
    Layer                                       = "shared"
    Type                                        = "public"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# Two private subnets in two AZs. Reserved for future internal-only workloads
# — V7 still runs the EKS node group on public subnets so worker nodes can
# pull from ECR without a NAT gateway. Live consumes both via remote state.
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 11)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                        = "${var.project_name}-private-${count.index + 1}"
    ManagedBy                                   = "terraform"
    Layer                                       = "shared"
    Type                                        = "private"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name      = "${var.project_name}-public-rt"
    ManagedBy = "terraform"
    Layer     = "shared"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}
