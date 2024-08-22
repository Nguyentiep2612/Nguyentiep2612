terraform {
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

  }
  backend "s3" {
        bucket = "my-bucket-s3-new"
        key = "terraform.stfstate"
        region= "ap-southeast-2"
        encrypt = true
        profile = "user1"
    }
required_version = ">= 1.0.0"
}
resource "aws_s3_bucket" "main_s3" {
    bucket = "my-bucket-s3-new"
    acl = "private" # Sets the bucket's Access Control List (ACL) to private, meaning only the owner has full control.
    versioning { # Enables versioning for the bucket.
    enabled = true  # Ensures that versioning is turned on, allowing you to keep multiple versions of an object in one bucket.
        }
    
}
# Configure the AWS Provider
provider "aws" {
    region = var.aws-region
    profile = "user1"
}
#create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = var.cidr-block
  tags = {
    Name = "main-vpc"
  }
}
#create Subnet az1-2b/ az2-2c
resource "aws_subnet" "container_public_az1" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = var.container-public-az1
    availability_zone = "ap-southeast-2b"
    tags = {
        Name = "container-public-az1"
    }
}
resource "aws_subnet" "container_public_az2" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = var.container-public-az2
    availability_zone = "ap-southeast-2c"
    tags = {
        Name = "container-public-az2"
    }
}
resource "aws_subnet" "container_private_az1" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = var.container-private-az1
    availability_zone = "ap-southeast-2b"
    tags = {
        Name = "container-private-az1"
    }
}
resource "aws_subnet" "container_private_az2" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = var.container-private-az2
    availability_zone = "ap-southeast-2c"
    tags = {
        Name = "container-private-az2"
    }
}
resource "aws_subnet" "container_db_az1" {
    vpc_id = aws_vpc.main_vpc.id 
    cidr_block = var.container-db-az1
    availability_zone = "ap-southeast-2b"
    tags = {
        Name = "container-db-az1"
    }
}
resource "aws_subnet" "container_db_az2" {
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = var.container-db-az2
    availability_zone = "ap-southeast-2c"
    tags = {
        Name = "container-db-az2"
    }
}
#creater internet gateway
resource "aws_internet_gateway" "container_igw" {
    vpc_id = aws_vpc.main_vpc.id 
    tags = {
        Name = "container-IGW"
    }
}

#creater route table and get for public subnet
resource "aws_route_table" "container_public_rtb" {
    vpc_id = aws_vpc.main_vpc.id 
    route {
        cidr_block = var.container-public-rtb
        gateway_id = aws_internet_gateway.container_igw.id
    }
    tags = {
        Name = "container-public-rtb"
    }
}
#Public route table 
#select subnet associations for container_public_az1/az2
resource "aws_route_table_association" "public_rtb_association_az1" {
    subnet_id = aws_subnet.container_public_az1.id
    route_table_id = aws_route_table.container_public_rtb.id
}   
resource "aws_route_table_association" "public_rtb_association_az2" {
    subnet_id = aws_subnet.container_public_az2.id
    route_table_id = aws_route_table.container_public_rtb.id
}

#Create elastic IP for NAT Gateway
resource "aws_eip" "nat_eip_az1" {
    vpc = true
}
resource "aws_eip" "nat_eip_az2" {
    vpc = true
}
#Create NAT Gateway for private
resource "aws_nat_gateway" "nat_gateway_private_az1" {
    allocation_id = aws_eip.nat_eip_az1.id
    subnet_id = aws_subnet.container_private_az1.id
    tags = {
        Name = "nat-gateway-private-az1"
    }
}
resource "aws_nat_gateway" "nat_gateway_private_az2" {
    allocation_id = aws_eip.nat_eip_az2.id
    subnet_id = aws_subnet.container_private_az2.id
    tags = {
        Name = "nat-gateway-private-az2"
    }
}
#create private route table and aws_nat_gateway.nat_az1.id in az1
resource "aws_route_table" "container_private_rtb" {
    vpc_id = aws_vpc.main_vpc.id
    route {
        cidr_block = var.container-private-rtb
        nat_gateway_id = aws_nat_gateway.nat_gateway_private_az1.id
    }
    tags = {
            Name = "container-private-rtb"
    }
}
#create route table association for private
resource "aws_route_table_association" "private_rtb_association_az1" {
    subnet_id = aws_subnet.container_private_az1.id
    route_table_id = aws_route_table.container_private_rtb.id
}
resource "aws_route_table_association" "private_rtb_association_az2" {
    subnet_id = aws_subnet.container_private_az2.id
    route_table_id = aws_route_table.container_private_rtb.id
}

#security group for public 
resource "aws_security_group" "container_public_SG" {
    name        = "allow_container_public_SG"
    description = "Allow http, https"
    vpc_id = aws_vpc.main_vpc.id 

    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH"
  }  
    ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "container_public_SG"
  }
}
#security group for private
resource "aws_security_group" "container_private_sg" {
  name        = "allow_container_private_SG"
  description = "Allow traffic"
  vpc_id = aws_vpc.main_vpc.id
  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups  = [aws_security_group.container_public_SG.id]
    description      = "Allow all outbound traffic to public security group"
  }

  # Egress allows traffic to public security group
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all inbound traffic"
  }
  tags = {
    Name = "container_private-sg"
  }
}

# Create EC2
resource "aws_instance" "main_ec2" {
    ami = "ami-09f5ddaab17f5ff43"
    instance_type = "t2.micro"
    key_name = "demo-ec2-key"
    tags = {
        Name = "main-ec2"
    }
    
}
#Create RDS
resource "aws_security_group" "main_sg_RDS" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "main-sg2"
  }
}
# Tạo RDS instance
resource "aws_db_instance" "main_db" {
    allocated_storage    = 10
  db_name              = "mydb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro" 
  username             = var.db_username
  password             = var.db_password
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.main_sg_RDS.id]
  db_subnet_group_name   = aws_db_subnet_group.main_subnet_group.name

  tags = {
    Name = "main-db"
  }
}
# Tạo Subnet Group cho RDS
resource "aws_db_subnet_group" "main_subnet_group" {
  name       = "main-subnet-group"
  subnet_ids = [
    aws_subnet.container_db_az1.id, 
    aws_subnet.container_db_az2.id
]

  tags = {
    Name = "main-subnet-group"
  }
}