# main.tf - EKS module

terraform {
    required_providers {
        aws = "~> 2.68.0"
        local = "~> 1.4"

        kubernetes = "~> 1.11"
        random = "~> 2.1"
        null = "~> 2.1"
        template = "~> 2.1"
    }
}

data "aws_eks_cluster" "cluster" {
    name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
    name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {
}

resource "random_string" "suffix" {
    length  = 4
    special = false
}

locals {
    #cluster_name = "${var.eks["cluster_name"]}-${random_string.suffix.result}"
    cluster_name = var.eks["cluster_name"]
}

resource "aws_security_group" "jarvice_system" {
    name_prefix = "jarvice_system"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"

        cidr_blocks = [
            "10.0.0.0/8",
        ]
    }
}

resource "aws_security_group" "jarvice_compute" {
    name_prefix = "jarvice_compute"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"

        cidr_blocks = [
            "192.168.0.0/16",
        ]
    }
}

resource "aws_security_group" "jarvice" {
    name_prefix = "jarvice"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"

        cidr_blocks = [
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
        ]
    }
}

resource "aws_eip" "nat" {
    count = 1

    vpc = true
}

module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "2.6.0"

    name = "${local.cluster_name}-vpc"
    cidr = "10.0.0.0/16"
    azs = var.eks["availability_zones"] != null ? var.eks["availability_zones"] : data.aws_availability_zones.available.names
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    public_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    enable_nat_gateway = true
    single_nat_gateway = true
    enable_dns_hostnames = true

    reuse_nat_ips = true
    external_nat_ip_ids = "${aws_eip.nat.*.id}"

    public_subnet_tags = {
        "kubernetes.io/cluster/${local.cluster_name}" = "shared"
        "kubernetes.io/role/elb" = "1"
    }

    private_subnet_tags = {
        "kubernetes.io/cluster/${local.cluster_name}" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

locals {
    system_nodes = [
        {
            "name" = "jarvice-system",
            "instance_type" = local.system_node_instance_type
            "asg_desired_capacity" = local.system_node_asg_desired_capacity
            "asg_min_size" = local.system_node_asg_desired_capacity
            "asg_max_size" = local.system_node_asg_desired_capacity
            "additional_security_group_ids" = [aws_security_group.jarvice_system.id]
            "kubelet_extra_args" = "--node-labels=node-role.kubernetes.io/jarvice-system=true --register-with-taints=node-role.kubernetes.io/jarvice-system=true:NoSchedule"
            "public_ip" = true
        }
    ]
    compute_nodes = length(var.eks["compute_node_pools"]) == 0 ? null : [
        for index, pool in var.eks["compute_node_pools"]:
            {
                "name" = "jarvice-compute-${index}"
                "instance_type" = pool.instance_type
                "asg_desired_capacity" = pool.asg_desired_capacity
                "asg_min_size" = pool.asg_min_size
                "asg_max_size" = pool.asg_max_size
                "additional_security_group_ids" = [aws_security_group.jarvice_compute.id]
                "kubelet_extra_args" = "--node-labels=node-role.kubernetes.io/jarvice-compute=true --register-with-taints=node-role.kubernetes.io/jarvice-compute=true:NoSchedule"
                "public_ip" = true
            }
    ]
}

module "eks" {
    source = "terraform-aws-modules/eks/aws"
    cluster_name = local.cluster_name
    cluster_version = var.eks["kubernetes_version"]
    subnets = module.vpc.private_subnets

    tags = {
        cluster_name = var.eks["cluster_name"]
    }

    vpc_id = module.vpc.vpc_id

    worker_groups = concat(local.system_nodes, local.compute_nodes)

    worker_additional_security_group_ids = [aws_security_group.jarvice.id]
}

