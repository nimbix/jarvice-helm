# main.tf - EKS module

terraform {
    required_providers {
        aws = "~> 3.64"

        helm = "~> 2.4"
        kubernetes = "~> 2.6"

        null = "~> 3.1"
        local = "~> 2.1"
        random = "~> 3.1"
    }
}


data "aws_eks_cluster" "cluster" {
    name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
    name = module.eks.cluster_id
}

data "aws_availability_zones" "available" {
    filter {
        name = var.cluster.location["zones"] != null ? "zone-name" : "region-name"
        values = var.cluster.location["zones"] != null ? var.cluster.location["zones"] : [var.cluster.location["region"]]
    }
}

# Force update to data.aws_availability_zones.available with:
# terraform apply -target=module.<eks_cluster_XX>.null_resource.aws_availability_zones_available
resource "null_resource" "aws_availability_zones_available" {
    triggers = {
        names = join(",", data.aws_availability_zones.available.names)
    }
}


module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    version = "~> 3.11"

    name = "${var.cluster.meta["cluster_name"]}-vpc"
    cidr = "10.0.0.0/16"
    azs = data.aws_availability_zones.available.names
    public_subnets = length(data.aws_availability_zones.available.names) > 2 ? ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19", "10.0.96.0/19"] : ["10.0.0.0/18", "10.0.64.0/18"]
    private_subnets = length(data.aws_availability_zones.available.names) > 2 ? ["10.0.128.0/19", "10.0.160.0/19", "10.0.192.0/19", "10.0.224.0/19"] : ["10.0.128.0/18", "10.0.192.0/18"]
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

data "aws_ec2_instance_type" "jarvice_compute" {
    for_each = var.cluster["compute_node_pools"]

    instance_type = each.value["nodes_type"]
}

resource "aws_placement_group" "efa" {
    for_each = { for name, pool in var.cluster["compute_node_pools"] : name => pool if lookup(pool.meta, "interface_type", null) == "efa" ? true:false}
    name = "${var.cluster.meta["cluster_name"]}-${each.key}"
    strategy = "cluster"
}

locals {
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

    # See /opt/amazon/bin/efa-hugepages-reserve.sh for reference
    huge_pages_size = 2048  # TODO: may be different on arm64 nodes
    efa_ep_huge_pages_memory = 110 * 1024
}



module "eks" {
    #source = "terraform-aws-modules/eks/aws"
    #version = "~> 18.2"
    source = "git::https://github.com/nimbix/terraform-aws-eks.git?ref=interface_type_update"

    cluster_name = var.cluster.meta["cluster_name"]
    cluster_version = var.cluster.meta["kubernetes_version"]

    vpc_id = module.vpc.vpc_id
    enable_irsa = true
    subnet_ids = module.vpc.private_subnets

    cluster_security_group_additional_rules = {
        egress_internet_all = {
            description = "Allow cluster egress access to the Internet."
            protocol = "-1"
            from_port = 0
            to_port = 65535
            type = "egress"
            cidr_blocks = ["0.0.0.0/0"]
        }

    }

    node_security_group_additional_rules = {
        egress_internet_all = {
            description = "Allow nodes all egress to the Internet."
            protocol = "-1"
            from_port = 0
            to_port = 65535
            type = "egress"
            cidr_blocks = ["0.0.0.0/0"]
        }
        ingress_internet_all = {
            description = "Allow nodes all ingress from the Internet."
            protocol = "-1"
            from_port = 0
            to_port = 65535
            type = "ingress"
            cidr_blocks = ["0.0.0.0/0"]
        }

    }

    self_managed_node_group_defaults = {
        create_security_group = false
        #iam_role_additional_policies = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
    }

    self_managed_node_groups = merge({
        default = {
            name = "default"
            instance_type = lookup(var.cluster.meta, "arch", "") == "arm64" ? "t4g.small" : "t2.small"
            ami_id = lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : data.aws_ami.eks_amd64.id
            desired_size = 2
            min_size = 2
            max_size = 2
            key_name = ""
            bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node-role.jarvice.io/default=true'"
            public_ip = true
            network_interfaces = [
                    {
                      device_index = 0
                      associate_public_ip_address = true
                      security_groups = ["${aws_security_group.ssh.id}"] #lookup(pool.meta, "interface_type", null) == "efa" ? ["${aws_security_group.efa.id}", "${aws_security_group.ssh.id}"] : ["${aws_security_group.ssh.id}"] 
                    }
                ]
            #vpc_security_group_ids = [aws_security_group.ssh.id]
            pre_bootstrap_user_data = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
        }
        jxesystem = {
            name = "jxesystem"
            instance_type = module.common.system_nodes_type
            ami_id = lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : data.aws_ami.eks_amd64.id
            desired_size = module.common.system_nodes_num
            min_size = module.common.system_nodes_num
            max_size = module.common.system_nodes_num * 2
            key_name = ""
            bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node-role.jarvice.io/jarvice-system=true,node-pool.jarvice.io/jarvice-system=jxesystem --register-with-taints=node-role.jarvice.io/jarvice-system=true:NoSchedule'"
            instance_refresh = {
              strategy = "Rolling"
              preferences = {
                checkpoint_delay       = 600
                checkpoint_percentages = [35, 70, 100]
                instance_warmup        = 300
                min_healthy_percentage = 50
              }
            }
            network_interfaces = [
                    {
                      device_index = 0
                      associate_public_ip_address = true
                      security_groups = ["${aws_security_group.ssh.id}"] 
                    }
                ]
            enable_bootstrap_user_data = true
            pre_bootstrap_user_data = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
        }
    },
    module.common.jarvice_cluster_type == "downstream" || var.cluster.dockerbuild_node_pool["nodes_type"] == null ? {} : {
        jxedockerbuild = {
            name = "jxedockerbuild"
            instance_type = var.cluster.dockerbuild_node_pool["nodes_type"]
            ami_id = lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : data.aws_ami.eks_amd64.id
            desired_size = var.cluster.dockerbuild_node_pool["nodes_num"]
            min_size = var.cluster.dockerbuild_node_pool["nodes_min"]
            max_size = var.cluster.dockerbuild_node_pool["nodes_max"]
            key_name = ""
            instance_refresh = true
            bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node-role.jarvice.io/jarvice-dockerbuild=true,node-pool.jarvice.io/jarvice-dockerbuild=jxedockerbuild --register-with-taints=node-role.jarvice.io/jarvice-dockerbuild=true:NoSchedule'"
            instance_refresh = {
              strategy = "Rolling"
              preferences = {
                checkpoint_delay       = 600
                checkpoint_percentages = [35, 70, 100]
                instance_warmup        = 300
                min_healthy_percentage = 50
              }
            }
            network_interfaces = [
                    {
                      device_index = 0
                      associate_public_ip_address = true
                      security_groups = ["${aws_security_group.ssh.id}"] 
                    }
                ]
            enable_bootstrap_user_data = true
            pre_bootstrap_user_data = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys
EOF
            tags = {
                    "k8s.io/cluster-autoscaler/enabled" = "true"
                    "k8s.io/cluster-autoscaler/${var.cluster.meta["cluster_name"]}" = "owned"
                    "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/instance-type" = var.cluster.dockerbuild_node_pool["nodes_type"]
                    "k8s.io/cluster-autoscaler/node-template/label/kubernetes.io/arch" = lookup(var.cluster.meta, "arch", null) == "arm64" ? "arm64" : "amd64"
                }
        }
    },
    {
        for pool_name, pool in var.cluster["compute_node_pools"]:
            pool_name => {
                name = pool_name
                #create_launch_template = false
                #launch_template_id = aws_launch_template.jarvice_compute[pool_name].id
                instance_type = pool.nodes_type
                ami_id = lookup(pool.meta, "ami_id", null) != null ? pool.meta.ami_id : lookup(var.cluster.meta, "arch", "") == "arm64" ? data.aws_ami.eks_arm64.id : lookup(pool.meta, "interface_type", null) == "efa" ? data.aws_ami.eks_amd64.id : data.aws_ami.eks_amd64_gpu.id
                desired_size = pool.nodes_num
                min_size = pool.nodes_min
                max_size = pool.nodes_max
                key_name = ""
                bootstrap_extra_args = "--kubelet-extra-args '--node-labels=node-role.jarvice.io/jarvice-compute=true,node-pool.jarvice.io/jarvice-compute=${pool_name},node-pool.jarvice.io/disable-hyperthreading=${lookup(pool.meta, "disable_hyperthreading", "false")}${length(regexall("^(p2|p3|p4|g3|g4|inf1)", pool.nodes_type)) > 0 ? ",accelerator=nvidia" : ""}${lookup(pool.meta, "interface_type", null) == "efa" ? ",node-pool.jarvice.io/interface-type=efa" : ""} --register-with-taints=node-role.jarvice.io/jarvice-compute=true:NoSchedule'"
                subnet_ids = lookup(pool.meta, "zones", null) == null ? (
                    lookup(pool.meta, "interface_type", null) == "efa" ? [module.vpc.private_subnets[0]] : module.vpc.private_subnets
                ) : (
                    lookup(pool.meta, "interface_type", null) == "efa" ? (
                        [
                            module.vpc.private_subnets[index(module.vpc.azs, split(",", pool.meta["zones"])[0])]
                        ]
                    ) : (
                        [
                            for zone in split(",", pool.meta["zones"]):
                                module.vpc.private_subnets[index(module.vpc.azs, zone)]
                        ]
                    )
                )
                cpu_options = {
                  core_count       = data.aws_ec2_instance_type.jarvice_compute[pool_name].default_vcpus / data.aws_ec2_instance_type.jarvice_compute[pool_name].default_threads_per_core
                  threads_per_core = lower(lookup(pool.meta, "disable_hyperthreading", "false")) == "true" ? 1:2
                }
                ebs_optimized = true
                block_device_mappings = {
                    compute_disk = {
                      device_name = "/dev/xvda"
                      ebs = {
                        volume_type = "gp2"
                        volume_size = pool.nodes_disk_size_gb
                        delete_on_termination = true
                      }
                    }
                }
                network_interfaces = [
                    {
                      device_index = 0
                      associate_public_ip_address = true
                      interface_type = lookup(pool.meta, "interface_type", null) == "efa" ? "efa" : null
                      security_groups = lookup(pool.meta, "interface_type", null) == "efa" ? ["${aws_security_group.efa.id}", "${aws_security_group.ssh.id}"] : ["${aws_security_group.ssh.id}"] 
                      #subnet_id = lookup(pool.meta, "zones", null) == null ? (
                      #      module.vpc.private_subnets[0]
                      #      ) : (module.vpc.private_subnets[index(module.vpc.azs, pool.meta["zones"])])
                    }
                ]
                placement_group = lookup(pool.meta, "interface_type", null) == "efa" ? [for k,v in aws_placement_group.efa : v.id if v.name == "${var.cluster.meta["cluster_name"]}-${pool_name}"][0] : null
                enable_bootstrap_user_data = true
                pre_bootstrap_user_data = <<EOF
# pre_userdata (executed before kubelet bootstrap and cluster join)
# Add authorized ssh key
echo "${module.common.ssh_public_key}" >>/home/ec2-user/.ssh/authorized_keys

${lookup(pool.meta, "interface_type", null) == "efa" ? local.efa_install : ""}

#${lower(lookup(pool.meta, "disable_hyperthreading", "false")) == "true" ? local.disable_hyperthreading : ""}
EOF
                post_bootstrap_user_data = <<EOF
# additional_userdata (executed after kubelet bootstrap and cluster join)
EOF
                tags = merge(
                        {
                            "k8s.io/cluster-autoscaler/enabled" = "true"
                            "k8s.io/cluster-autoscaler/${var.cluster.meta["cluster_name"]}" = "owned"
                            "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/instance-type" = pool.nodes_type
                            "k8s.io/cluster-autoscaler/node-template/label/kubernetes.io/arch" = lookup(var.cluster.meta, "arch", null) == "arm64" ? "arm64" : "amd64"
                        },
                    lookup(pool.meta, "interface_type", null) == "efa" ?
                            {
                                "k8s.io/cluster-autoscaler/node-template/resources/vpc.amazonaws.com/efa" = "1"
                                "k8s.io/cluster-autoscaler/node-template/resources/hugepages-2Mi" = format("%sMi", tostring(((local.efa_ep_huge_pages_memory * data.aws_ec2_instance_type.jarvice_compute[pool_name].default_vcpus * (lower(lookup(pool.meta, "aws_disable_hyperthreading", "false")) == "true" ? 1:2)) / local.huge_pages_size + 1) * 2))
                            }
                        : {}
                )
            }
    })

    tags = {
        cluster_name = var.cluster.meta["cluster_name"]
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
    name_prefix = "${var.cluster.meta["cluster_name"]}-cluster-autoscaler"
    description = "EKS cluster-autoscaler policy for cluster ${module.eks.cluster_id}"
    policy = data.aws_iam_policy_document.cluster_autoscaler.json
}

module "iam_assumable_role_admin_cluster_autoscaler" {
    source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
    version = "~> 4.7"

    create_role = true
    role_name_prefix = substr("${var.cluster.meta["cluster_name"]}-cluster-autoscaler", 0, 32)
    provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
    role_policy_arns = [aws_iam_policy.cluster_autoscaler.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:cluster-autoscaler-aws-cluster-autoscaler"]
}

locals {
    arn_partition = length(regexall("^us-gov-", var.cluster.location["region"])) > 0 ? "aws-us-gov" : "aws"
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
                "Resource": "arn:${local.arn_partition}:ec2:*:*:security-group/*",
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
                "Resource": "arn:${local.arn_partition}:ec2:*:*:security-group/*",
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
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:targetgroup/*/*",
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:loadbalancer/app/*/*"
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
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:listener/net/*/*/*",
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:listener/app/*/*/*",
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                    "arn:${local.arn_partition}:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
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
                "Resource": "arn:${local.arn_partition}:elasticloadbalancing:*:*:targetgroup/*/*"
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
    version = "~> 4.7"

    create_role = true
    role_name_prefix = substr("${var.cluster.meta["cluster_name"]}-aws-load-balancer-controller", 0, 32)
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
                    "arn:${local.arn_partition}:route53:::hostedzone/*"
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
    version = "~> 4.7"

    create_role = true
    role_name_prefix = substr("${var.cluster.meta["cluster_name"]}-external-dns", 0, 32)
    provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
    role_policy_arns = [aws_iam_policy.external_dns.arn]
    oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:external-dns"]
}

