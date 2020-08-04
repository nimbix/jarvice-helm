# main.tf - EKS module

terraform {
    required_providers {
        aws = "~> 2.68.0"

        null = "~> 2.1"
        local = "~> 1.4"
        template = "~> 2.1"
        random = "~> 2.3"
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

#resource "aws_eip" "nat" {
#    count = 1
#
#    vpc = true
#}

module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "~> 2.44.0"

    name = "${var.cluster["cluster_name"]}-vpc"
    cidr = "10.0.0.0/16"
    azs = var.cluster["availability_zones"] != null ? var.cluster["availability_zones"] : data.aws_availability_zones.available.names
    public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
    private_subnets = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
    enable_dns_hostnames = true

    #enable_nat_gateway = true
    #single_nat_gateway = true

    #reuse_nat_ips = true
    #external_nat_ip_ids = "${aws_eip.nat.*.id}"

    public_subnet_tags = {
        "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "shared"
        "kubernetes.io/role/elb" = "1"
    }

    private_subnet_tags = {
        "kubernetes.io/cluster/${var.cluster["cluster_name"]}" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
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

locals {
    default_nodes = [
        {
            "name" = "default",
            "instance_type" = "t2.nano"
            "asg_desired_capacity" = 2
            "asg_min_size" = 2
            "asg_max_size" = 2
            "kubelet_extra_args" = "--node-labels=node-role.jarvice.io/default=true,node-role.kubernetes.io/default=true"
            "public_ip" = true
            "key_name" = ""
            "pre_userdata" = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${local.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
        }
    ]
    system_nodes = [
        {
            "name" = "jarvice-system",
            "instance_type" = local.system_node_instance_type
            "asg_desired_capacity" = local.system_node_asg_desired_capacity
            "asg_min_size" = local.system_node_asg_desired_capacity
            "asg_max_size" = local.system_node_asg_desired_capacity
            "kubelet_extra_args" = "--node-labels=node-role.jarvice.io/jarvice-system=true,node-role.kubernetes.io/jarvice-system=true --register-with-taints=node-role.kubernetes.io/jarvice-system=true:NoSchedule"
            "public_ip" = true
            "key_name" = ""
            "pre_userdata" = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${local.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
        }
    ]
    compute_nodes = length(var.cluster["compute_node_pools"]) == 0 ? null : [
        for index, pool in var.cluster["compute_node_pools"]:
            {
                "name" = "jarvice-compute-${index}"
                "instance_type" = pool.instance_type
                "asg_desired_capacity" = pool.asg_desired_capacity
                "asg_min_size" = pool.asg_min_size
                "asg_max_size" = pool.asg_max_size
                "kubelet_extra_args" = "--node-labels=node-role.jarvice.io/jarvice-compute=true,node-role.kubernetes.io/jarvice-compute=true --register-with-taints=node-role.kubernetes.io/jarvice-compute=true:NoSchedule"
                "public_ip" = true
                "key_name" = ""
                "pre_userdata" = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${local.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys

# Disable hyper-threading.  Visit the following link for details:
# https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-linux/
for n in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d, -f2- | tr ',' '\n' | sort -un); do
    echo "Disabling cpu$n..."
    echo 0 > /sys/devices/system/cpu/cpu$n/online
done
EOF
                "additional_userdata" = <<EOF
# additional_userdata (executed after kubelet bootstrap and cluster join)
EOF
                "tags" = [
                    {
                        "key" = "k8s.io/cluster-autoscaler/enabled"
                        "propagate_at_launch" = "false"
                        "value" = "true"
                    },
                    {
                        "key" = "k8s.io/cluster-autoscaler/${var.cluster["cluster_name"]}"
                        "propagate_at_launch" = "false"
                        "value" = "true"
                    }
                ]

            }
    ]
}

module "eks" {
    source = "terraform-aws-modules/eks/aws"
    version = "~> 12.2.0"

    cluster_name = var.cluster["cluster_name"]
    cluster_version = var.cluster["kubernetes_version"]

    vpc_id = module.vpc.vpc_id
    enable_irsa = true

    subnets = module.vpc.public_subnets
    #subnets = module.vpc.private_subnets

    worker_groups = concat(local.default_nodes, local.system_nodes, local.compute_nodes)
    worker_additional_security_group_ids = [aws_security_group.jarvice.id]

    tags = {
        cluster_name = var.cluster["cluster_name"]
    }
}

data "aws_iam_policy_document" "cluster_autoscaler" {
    statement {
        sid = "clusterAutoscalerAll"
        effect = "Allow"

        actions = [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:DescribeLaunchConfigurations",
            "autoscaling:DescribeTags",
            "ec2:DescribeLaunchTemplateVersions",
        ]

        resources = ["*"]
    }

    statement {
        sid = "clusterAutoscalerOwn"
        effect = "Allow"

        actions = [
            "autoscaling:SetDesiredCapacity",
            "autoscaling:TerminateInstanceInAutoScalingGroup",
            "autoscaling:UpdateAutoScalingGroup",
        ]

        resources = ["*"]

        condition {
            test = "StringEquals"
            variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_id}"
            values = ["owned"]
        }

        condition {
            test = "StringEquals"
            variable = "autoscaling:ResourceTag/k8s.io/cluster-autoscaler/enabled"
            values = ["true"]
        }
    }
}

resource "aws_iam_policy" "cluster_autoscaler" {
    name_prefix = "cluster-autoscaler"
    description = "EKS cluster-autoscaler policy for cluster ${module.eks.cluster_id}"
    policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

locals {
    k8s_service_account_namespace = "kube-system"
    k8s_service_account_name = "cluster-autoscaler-aws-cluster-autoscaler"
}

module "iam_assumable_role_admin" {
    source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
    version = "~> 2.12.0"

    create_role = true
    role_name = "${var.cluster["cluster_name"]}-cluster-autoscaler"
    provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
    role_policy_arns = [aws_iam_policy.cluster_autoscaler.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:${local.k8s_service_account_namespace}:${local.k8s_service_account_name}"]
}

