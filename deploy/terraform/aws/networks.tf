resource "aws_vpc" "cm_net" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name      = "cm_net"
    yor_trace = "cfbc0362-5d68-48a6-b135-33d7387d1714"
  }
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.cm_net.id

  tags = {
    "Name"    = "cm_igw"
    yor_trace = "d6315dc4-a3ce-46c2-8f42-a36a5838a1bb"
  }
}

# public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.cm_net.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    "Name"    = "subnet 1 - 10.0.1.0/24"
    yor_trace = "66e900e9-2fc2-453c-906d-cc98770155d1"
  }
}

#public subnet 2
resource "aws_subnet" "public_subnet2" {
  vpc_id                  = aws_vpc.cm_net.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  tags = {
    "Name"    = "subnet 2 - 10.0.2.0/24"
    yor_trace = "4342c093-3e2c-4746-aa97-5479d740c43d"
  }
}

# Routing tables to route traffic for Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cm_net.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name      = "ciphertrust-public-subnet-route-table"
    yor_trace = "6babbaba-b19e-46ad-8d8e-b11712825eef"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.public_subnet2.id
  route_table_id = aws_route_table.public.id
}

## Security Groups (AKA Firewall)
resource "aws_security_group" "cm_firewall" {
  name        = "cm_server_sg"
  description = "Allow inbound and outbound traffic from EC2 instances"
  vpc_id      = aws_vpc.cm_net.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH to server"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name      = "ciphertrust-manager-firewall"
    yor_trace = "ea058c4e-54aa-4644-b766-8a77fa90ff69"
  }
}
