terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.3"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {}

# VPC & SUBNETS

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidr[0]
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-a-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidr[1]
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet-public-b-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[0]
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "subnet-private-a-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets_cidr[1]
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "subnet-private-b-${var.project_name}-${terraform.workspace}"
  }
}

# GATEWAYS

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "igw-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_eip" "nat_a" {
  domain = "vpc"
  tags = {
    Name = "eip-nat-a-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id
  tags = {
    Name = "nat-a-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags = {
    Name = "eip-nat-b-${var.project_name}-${terraform.workspace}"
  }
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id
  tags = {
    Name = "nat-b-${var.project_name}-${terraform.workspace}"
  }
}


locals {
  env = terraform.workspace # Esto tomará "default", "dev", "qa", o "prod"
  prefix = "img-proc-${local.env}"
}

