# main.tf - EKS module

terraform {
    required_providers {
        aws = "~> 3.44.0"

        helm = "~> 2.1.2"
        kubernetes = "~> 2.1.0"

        null = "~> 3.1.0"
        local = "~> 2.1.0"
        template = "~> 2.2.0"
        random = "~> 3.1.0"
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


module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "~> 3.1.0"

    name = "${var.cluster.meta["cluster_name"]}-vpc"
    cidr = "10.0.0.0/16"
    azs = var.cluster.location["zones"] != null ? distinct(concat(var.cluster.location["zones"], data.aws_availability_zones.available.names)) : data.aws_availability_zones.available.names
    public_subnets = var.cluster.location["zones"] == null ? ["10.0.0.0/18", "10.0.64.0/18"] : length(var.cluster.location["zones"]) > 2 ? ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"] : ["10.0.0.0/18", "10.0.64.0/18"]
    private_subnets = var.cluster.location["zones"] == null ? ["10.0.128.0/18", "10.0.192.0/18"] : length(var.cluster.location["zones"]) > 2 ? ["10.0.128.0/19", "10.0.160.0/19", "10.0.192.0/19", "10.0.224.0/19"] : ["10.0.128.0/18", "10.0.192.0/18"]
    enable_dns_hostnames = true
    enable_dns_support = true
    enable_nat_gateway = true
    single_nat_gateway = true

    public_subnet_tags = {
        "kubernetes.io/cluster/${var.cluster.meta["cluster_name"]}" = "shared"
        "kubernetes.io/role/elb" = "1"
    }

    private_subnet_tags = {
        "kubernetes.io/cluster/${var.cluster.meta["cluster_name"]}" = "shared"
        "kubernetes.io/role/internal-elb" = "1"
    }
}

resource "aws_security_group" "ssh" {
    name_prefix = "${var.cluster.meta["cluster_name"]}-ssh"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"

        cidr_blocks = [module.vpc.vpc_cidr_block]
    }

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }
}

resource "aws_security_group" "efa" {
    name_prefix = "${var.cluster.meta["cluster_name"]}-efa"
    vpc_id = module.vpc.vpc_id

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        self = true
    }

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }
}

data "aws_ami" "eks_amd64" {
    filter {
        name = "name"
        values = ["amazon-eks-node-${var.cluster.meta["kubernetes_version"]}-v*"]
    }
    most_recent = true
    owners = ["amazon"]
}

data "aws_ami" "eks_amd64_gpu" {
    filter {
        name = "name"
        values = ["amazon-eks-gpu-node-${var.cluster.meta["kubernetes_version"]}-v*"]
    }
    most_recent = true
    owners = ["amazon"]
}

data "aws_ami" "eks_arm64" {
    filter {
        name = "name"
        values = ["amazon-eks-arm64-node-${var.cluster.meta["kubernetes_version"]}-*"]
    }
    most_recent = true
    owners = ["amazon"]
}

resource "aws_placement_group" "efa" {
    name = "${var.cluster.meta["cluster_name"]}-efa"
    strategy = "cluster"
}

locals {
    public_subnets = var.cluster.location["zones"] != null ? slice(module.vpc.public_subnets, 0, length(var.cluster.location["zones"])) : null
    private_subnets = var.cluster.location["zones"] != null ? slice(module.vpc.private_subnets, 0, length(var.cluster.location["zones"])) : null
    disable_hyperthreading = <<EOF
# Disable hyper-threading.  Visit the following link for details:
# https://aws.amazon.com/blogs/compute/disabling-intel-hyper-threading-technology-on-amazon-linux/
for n in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d, -f2- | tr ',' '\n' | sort -un); do
    echo "Disabling cpu$n..."
    echo 0 > /sys/devices/system/cpu/cpu$n/online
done
EOF
    efa_install = <<EOF
# Install EFA packages
wget -q --timeout=20 https://s3-us-west-2.amazonaws.com/aws-efa-installer/aws-efa-installer-latest.tar.gz -O /tmp/aws-efa-installer.tar.gz
tar -xf /tmp/aws-efa-installer.tar.gz -C /tmp
cd /tmp/aws-efa-installer
./efa_installer.sh -y -g
/opt/amazon/efa/bin/fi_info -p efa
#sysctl -w kernel.yama.ptrace_scope=0
EOF

    default_nodes = [
        {
            "name" = "default",
            "instance_type" = lookup(var.cluster.meta, "arch", "") == "arm64" ? "t4g.small" : "t2.small"
            "ami_id" = lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : data.aws_ami.eks_amd64.id
            "asg_desired_capacity" = 2
            "asg_min_size" = 2
            "asg_max_size" = 2
            "key_name" = ""
            "kubelet_extra_args" = "--node-labels=node-role.jarvice.io/default=true"
            "public_ip" = true
            "pre_userdata" = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
        }
    ]
    system_nodes = [
        {
            "name" = "jxesystem",
            "instance_type" = module.common.system_nodes_type
            "ami_id" = lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : data.aws_ami.eks_amd64.id
            "asg_desired_capacity" = module.common.system_nodes_num
            "asg_min_size" = module.common.system_nodes_num
            "asg_max_size" = module.common.system_nodes_num * 2
            "key_name" = ""
            "kubelet_extra_args" = "--node-labels=node-role.jarvice.io/jarvice-system=true,node-pool.jarvice.io/jarvice-system=jxesystem --register-with-taints=node-role.jarvice.io/jarvice-system=true:NoSchedule"
            "public_ip" = true
            "pre_userdata" = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
        }
    ]
    compute_nodes = length(var.cluster["compute_node_pools"]) == 0 ? null : [
        for name, pool in var.cluster["compute_node_pools"]:
            {
                "name" = name
                "instance_type" = pool.nodes_type
                "ami_id" = lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : lookup(pool.meta, "interface_type", null) == "efa" ? data.aws_ami.eks_amd64.id : data.aws_ami.eks_amd64_gpu.id
                "root_volume_size" = pool.nodes_disk_size_gb
                "asg_desired_capacity" = pool.nodes_num
                "asg_min_size" = pool.nodes_min
                "asg_max_size" = pool.nodes_max
                "key_name" = ""
                "instance_refresh_enabled" = true
                "kubelet_extra_args" = "--node-labels=node-role.jarvice.io/jarvice-compute=true,node-pool.jarvice.io/jarvice-compute=${name},node-pool.jarvice.io/disable-hyperthreading=${lookup(pool.meta, "disable_hyperthreading", "false")}${length(regexall("^(p2|p3|p4|g3|g4|inf1)", pool.nodes_type)) > 0 ? ",accelerator=nvidia" : ""} --register-with-taints=node-role.jarvice.io/jarvice-compute=true:NoSchedule"
                "public_ip" = true
                "interface_type" = lookup(pool.meta, "interface_type", null)
                "subnets" = lookup(pool.meta, "interface_type", null) == "efa" ? [module.vpc.private_subnets[0]] : module.vpc.private_subnets
                "additional_security_group_ids" = lookup(pool.meta, "interface_type", null) == "efa" ? [aws_security_group.efa.id] : []
                "placement_group" = lookup(pool.meta, "interface_type", null) == "efa" ? aws_placement_group.efa.id : null
                "pre_userdata" = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys

${lookup(pool.meta, "interface_type", null) == "efa" ? local.efa_install : ""}

${lower(lookup(pool.meta, "disable_hyperthreading", "false")) == "true" ? local.disable_hyperthreading : ""}
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
                        "key" = "k8s.io/cluster-autoscaler/${var.cluster.meta["cluster_name"]}"
                        "propagate_at_launch" = "false"
                        "value" = "true"
                    }
                ]

            }
    ]
}

module "eks" {
    #source = "terraform-aws-modules/eks/aws"
    #version = "~> 17.1.0"
    source = "github.com/nimbix/terraform-aws-eks"

    cluster_name = var.cluster.meta["cluster_name"]
    cluster_version = var.cluster.meta["kubernetes_version"]

    #config_output_path = pathexpand(local.kube_config["config_path"])
    write_kubeconfig = false

    vpc_id = module.vpc.vpc_id
    enable_irsa = true

    subnets = module.vpc.private_subnets

    wait_for_cluster_timeout = 600

    worker_groups_launch_template = concat(local.default_nodes, local.system_nodes, local.compute_nodes)
    worker_additional_security_group_ids = [aws_security_group.ssh.id]
    worker_ami_name_filter = lookup(var.cluster.meta, "arch", "") == "arm64" ? "amazon-eks-arm64-node-${var.cluster.meta["kubernetes_version"]}-*" : "amazon-eks-gpu-node-${var.cluster.meta["kubernetes_version"]}-v*"

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
    }

    depends_on = [module.vpc, aws_security_group.ssh]
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
    name_prefix = "${var.cluster.meta["cluster_name"]}-cluster-autoscaler"
    description = "EKS cluster-autoscaler policy for cluster ${module.eks.cluster_id}"
    policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

module "iam_assumable_role_admin_cluster_autoscaler" {
    source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
    version = "~> 4.1.0"

    create_role = true
    role_name = "${var.cluster.meta["cluster_name"]}-cluster-autoscaler"
    provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
    role_policy_arns = [aws_iam_policy.cluster_autoscaler.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:cluster-autoscaler-aws-cluster-autoscaler"]
}


resource "aws_iam_policy" "aws_load_balancer_controller" {
    name_prefix = "${var.cluster.meta["cluster_name"]}-aws-load-balancer-controller"
    description = "EKS aws-load-balancer-controller policy for cluster ${module.eks.cluster_id}"
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "iam:CreateServiceLinkedRole",
                    "ec2:DescribeAccountAttributes",
                    "ec2:DescribeAddresses",
                    "ec2:DescribeAvailabilityZones",
                    "ec2:DescribeInternetGateways",
                    "ec2:DescribeVpcs",
                    "ec2:DescribeSubnets",
                    "ec2:DescribeSecurityGroups",
                    "ec2:DescribeInstances",
                    "ec2:DescribeNetworkInterfaces",
                    "ec2:DescribeTags",
                    "ec2:GetCoipPoolUsage",
                    "ec2:DescribeCoipPools",
                    "elasticloadbalancing:DescribeLoadBalancers",
                    "elasticloadbalancing:DescribeLoadBalancerAttributes",
                    "elasticloadbalancing:DescribeListeners",
                    "elasticloadbalancing:DescribeListenerCertificates",
                    "elasticloadbalancing:DescribeSSLPolicies",
                    "elasticloadbalancing:DescribeRules",
                    "elasticloadbalancing:DescribeTargetGroups",
                    "elasticloadbalancing:DescribeTargetGroupAttributes",
                    "elasticloadbalancing:DescribeTargetHealth",
                    "elasticloadbalancing:DescribeTags"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "cognito-idp:DescribeUserPoolClient",
                    "acm:ListCertificates",
                    "acm:DescribeCertificate",
                    "iam:ListServerCertificates",
                    "iam:GetServerCertificate",
                    "waf-regional:GetWebACL",
                    "waf-regional:GetWebACLForResource",
                    "waf-regional:AssociateWebACL",
                    "waf-regional:DisassociateWebACL",
                    "wafv2:GetWebACL",
                    "wafv2:GetWebACLForResource",
                    "wafv2:AssociateWebACL",
                    "wafv2:DisassociateWebACL",
                    "shield:GetSubscriptionState",
                    "shield:DescribeProtection",
                    "shield:CreateProtection",
                    "shield:DeleteProtection"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupIngress"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateSecurityGroup"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateTags"
                ],
                "Resource": "arn:aws:ec2:*:*:security-group/*",
                "Condition": {
                    "StringEquals": {
                        "ec2:CreateAction": "CreateSecurityGroup"
                    },
                    "Null": {
                        "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:CreateTags",
                    "ec2:DeleteTags"
                ],
                "Resource": "arn:aws:ec2:*:*:security-group/*",
                "Condition": {
                    "Null": {
                        "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            },
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:AuthorizeSecurityGroupIngress",
                    "ec2:RevokeSecurityGroupIngress",
                    "ec2:DeleteSecurityGroup"
                ],
                "Resource": "*",
                "Condition": {
                    "Null": {
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:CreateLoadBalancer",
                    "elasticloadbalancing:CreateTargetGroup"
                ],
                "Resource": "*",
                "Condition": {
                    "Null": {
                        "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:CreateListener",
                    "elasticloadbalancing:DeleteListener",
                    "elasticloadbalancing:CreateRule",
                    "elasticloadbalancing:DeleteRule"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:AddTags",
                    "elasticloadbalancing:RemoveTags"
                ],
                "Resource": [
                    "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                    "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                    "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
                ],
                "Condition": {
                    "Null": {
                        "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:AddTags",
                    "elasticloadbalancing:RemoveTags"
                ],
                "Resource": [
                    "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                    "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                    "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                    "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
                ]
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:ModifyLoadBalancerAttributes",
                    "elasticloadbalancing:SetIpAddressType",
                    "elasticloadbalancing:SetSecurityGroups",
                    "elasticloadbalancing:SetSubnets",
                    "elasticloadbalancing:DeleteLoadBalancer",
                    "elasticloadbalancing:ModifyTargetGroup",
                    "elasticloadbalancing:ModifyTargetGroupAttributes",
                    "elasticloadbalancing:DeleteTargetGroup"
                ],
                "Resource": "*",
                "Condition": {
                    "Null": {
                        "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                    }
                }
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:RegisterTargets",
                    "elasticloadbalancing:DeregisterTargets"
                ],
                "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "elasticloadbalancing:SetWebAcl",
                    "elasticloadbalancing:ModifyListener",
                    "elasticloadbalancing:AddListenerCertificates",
                    "elasticloadbalancing:RemoveListenerCertificates",
                    "elasticloadbalancing:ModifyRule"
                ],
                "Resource": "*"
            }
        ]
    })
}

module "iam_assumable_role_admin_aws_load_balancer_controller" {
    source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
    version = "~> 4.1.0"

    create_role = true
    role_name = "${var.cluster.meta["cluster_name"]}-aws-load-balancer-controller"
    provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
    role_policy_arns = [aws_iam_policy.aws_load_balancer_controller.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
}


resource "aws_iam_policy" "external_dns" {
    name_prefix = "${var.cluster.meta["cluster_name"]}-external-dns"
    description = "EKS external-dns policy for cluster ${module.eks.cluster_id}"
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "route53:ChangeResourceRecordSets"
                ],
                "Resource": [
                    "arn:aws:route53:::hostedzone/*"
                ]
            },
            {
                "Effect": "Allow",
                "Action": [
                    "route53:ListHostedZones",
                    "route53:ListResourceRecordSets"
                ],
                "Resource": [
                    "*"
                ]
            }
        ]
    })
}

module "iam_assumable_role_admin_external_dns" {
    source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
    version = "~> 4.1.0"

    create_role = true
    role_name = "${var.cluster.meta["cluster_name"]}-external-dns"
    provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
    role_policy_arns = [aws_iam_policy.external_dns.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:external-dns"]
}

