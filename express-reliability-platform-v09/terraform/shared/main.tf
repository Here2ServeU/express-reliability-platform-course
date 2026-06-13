terraform {
  backend "s3" {
    bucket         = "reliability-platform-v08-tfstate-730335276920"
    key            = "shared/v8/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-v08"
  }
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}

provider "aws" { region = "us-east-1" }

data "aws_availability_zones" "available" { state = "available" }

# The VPC — your private neighborhood inside AWS
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "reliability-platform-vpc", ManagedBy = "terraform" }
}

# Public subnets — Load Balancer and internet-facing resources live here
# kubernetes.io/role/elb tag is required for EKS Load Balancer discovery
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.0.0.0/16", 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name                     = "public-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

# Private subnets — EKS worker nodes live here, hidden from direct internet access
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.0.0.0/16", 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name                              = "private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Internet gateway — lets the VPC communicate with the internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "reliability-igw" }
}

# Route table: traffic not inside the VPC goes to the internet gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# These three outputs are the whiteboard values the live layer reads
output "vpc_id"             { value = aws_vpc.main.id }
output "public_subnet_ids"  { value = aws_subnet.public[*].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
