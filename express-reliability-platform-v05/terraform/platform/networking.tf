resource "aws_vpc" "main" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "main" { vpc_id = aws_vpc.main.id }

# Public subnets — the ALB lives here and receives internet traffic
# The kubernetes.io/role/elb tag is required so EKS can find these subnets
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet("10.42.0.0/16", 4, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { "kubernetes.io/role/elb" = "1" }
}

# Private subnets — worker nodes live here, hidden from the internet
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet("10.42.0.0/16", 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { "kubernetes.io/role/internal-elb" = "1" }
}

# NAT Gateways — worker nodes can reach ECR to pull images
resource "aws_eip" "nat" { count = 2; domain = "vpc" }
resource "aws_nat_gateway" "main" {
  count         = 2
  subnet_id     = aws_subnet.public[count.index].id
  allocation_id = aws_eip.nat[count.index].id
}
