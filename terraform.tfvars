# Terraform will automatically load values from this variable definitions file
# and then any *.auto.tfvars files.  e.g. Copy terraform.tfvars to
# override.auto.tfvars and make any configuration edits there.
#
# Visit the following link for more information on how terraform handles
# variable definitions:
# https://www.terraform.io/docs/configuration/variables.html#variable-definitions-tfvars-files

#######################
### Global settings ###
#######################
global = {
    ssh_public_key = "~/.ssh/id_rsa.pub"

    helm = {
        jarvice = {
            override_yaml_values = <<EOF
# global override_yaml_values - Uncomment or add any values that should be
# applied to all defined clusters.

# Update per cluster override_yaml_values to override these global values.

#jarvice:
  # imagePullSecret is a base64 encoded string.
  # e.g. - echo "_json_key:$(cat gcr.io.json)" | base64 -w 0
  #imagePullSecret:
  #JARVICE_LICENSE_LIC:

  # JARVICE_REMOTE_* settings are used for application synchronization
  #JARVICE_REMOTE_API_URL: https://api.jarvice.com
  #JARVICE_REMOTE_USER:
  #JARVICE_REMOTE_APIKEY:
  #JARVICE_APPSYNC_USERONLY: false
EOF
        }
    }
}

###########################
### Kubernetes settings ###
###########################
#k8s = {
#    "k8s_cluster_00" = {
#    },
#}

#################################
### Google Cloud GKE Settings ###
#################################
gke = {
    "gke_cluster_00" = {
        enabled = false

        project = null
        credentials = null

        cluster_name = "tf-jarvice"
        location = "us-west1-a"

        kubernetes_version = "1.16"

        ssh_public_key = null  # global setting used if null specified

        # Visit the following link for GCP machine type specs:
        # https://cloud.google.com/compute/docs/machine-types
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = [
            {
                nodes_type = "n1-standard-32"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
            },
            #{
            #    nodes_type = "n1-standard-32"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #},
        ]

        helm = {
            jarvice = {
                version = "./"
                namespace = "jarvice-system"
                # global override_yaml_values take precedence over cluster
                # override_yaml_file (override_yaml_file ignored if not found)
                override_yaml_file = "override-tf.gke.<location>.<cluster_name>.yaml"  # "override-tf.gke.us-west1-a.tf-jarvice.yaml"

                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
    "gke_cluster_01" = {
        enabled = false

        project = null
        credentials = null

        cluster_name = "tf-jarvice-downstream"
        location = "us-west1-a"

        kubernetes_version = "1.16"

        ssh_public_key = null  # global setting used if null specified

        # Visit the following link for GCP machine type specs:
        # https://cloud.google.com/compute/docs/machine-types
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = [
            {
                nodes_type = "n1-standard-32"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
            },
            #{
            #    nodes_type = "n1-standard-32"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #},
        ]

        helm = {
            jarvice = {
                version = "./"
                namespace = "jarvice-system"
                # global override_yaml_values take precedence over cluster
                # override_yaml_file (override_yaml_file ignored if not found)
                override_yaml_file = "override-tf.gke.<location>.<cluster_name>.yaml"  # "override-tf.gke.us-west1-a.tf-jarvice-downstream.yaml"

                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
}


###########################
### Amazon EKS Settings ###
###########################
eks = {
    "eks_cluster_00" = {
        enabled = false

        access_key = null
        secret_key = null

        cluster_name = "tf-jarvice"
        region = "us-west-2"
        availability_zones = null

        kubernetes_version = "1.16"

        ssh_public_key = null  # global setting used if null specified

        # Visit the following link for AWS instance type specs:
        # https://aws.amazon.com/ec2/instance-types/
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = [
            {
                nodes_type = "c5.18xlarge"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
            },
            #{
            #    nodes_type = "c5.18xlarge"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #},
        ]

        helm = {
            jarvice = {
                version = "./"
                namespace = "jarvice-system"
                # global override_yaml_values take precedence over cluster
                # override_yaml_file (override_yaml_file ignored if not found)
                override_yaml_file = "override-tf.eks.<region>.<cluster_name>.yaml"  # "override-tf.eks.us-west-2.tf-jarvice.yaml"

                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
    "eks_cluster_01" = {
        enabled = false

        access_key = null
        secret_key = null

        cluster_name = "tf-jarvice-downstream"
        region = "us-west-2"
        availability_zones = null

        kubernetes_version = "1.16"

        ssh_public_key = null  # global setting used if null specified

        # Visit the following link for AWS instance type specs:
        # https://aws.amazon.com/ec2/instance-types/
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = [
            {
                nodes_type = "c5.18xlarge"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
            },
            #{
            #    nodes_type = "c5.18xlarge"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #},
        ]

        helm = {
            jarvice = {
                version = "./"
                namespace = "jarvice-system"
                # global override_yaml_values take precedence over cluster
                # override_yaml_file (override_yaml_file ignored if not found)
                override_yaml_file = "override-tf.eks.<region>.<cluster_name>.yaml"  # "override-tf.eks.us-west-2.tf-jarvice-downstream.yaml"

                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
}


##########################
### Azure AKS settings ###
##########################
aks = {
    "aks_cluster_00" = {
        enabled = false

        # Visit the following link for service principal creation information:
        # https://github.com/nimbix/jarvice-helm/blob/testing/Terraform.md#creating-a-service-principal-using-the-azure-cli
        service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

        cluster_name = "tf-jarvice"
        location = "Central US"
        availability_zones = ["1"]

        kubernetes_version = "1.16"

        ssh_public_key = null  # global setting used if null specified

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = [
            {
                nodes_type = "Standard_D32_v3"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
            },
            #{
            #    nodes_type = "Standard_D32_v3"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #},
        ]

        helm = {
            jarvice = {
                version = "./"
                namespace = "jarvice-system"
                # global override_yaml_values take precedence over cluster
                # override_yaml_file (override_yaml_file ignored if not found)
                override_yaml_file = "override-tf.aks.<location>.<cluster_name>.yaml"  # "override-tf.aks.centralus.tf-jarvice.yaml"

                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
    "aks_cluster_01" = {
        enabled = false

        # Visit the following link for service principal creation information:
        # https://github.com/nimbix/jarvice-helm/blob/testing/Terraform.md#creating-a-service-principal-using-the-azure-cli
        service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

        cluster_name = "tf-jarvice-downstream"
        location = "Central US"
        availability_zones = ["1"]

        kubernetes_version = "1.16"

        ssh_public_key = null  # global setting used if null specified

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = [
            {
                nodes_type = "Standard_D32_v3"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
            },
            #{
            #    nodes_type = "Standard_D32_v3"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #},
        ]

        helm = {
            jarvice = {
                version = "./"
                namespace = "jarvice-system"
                # global override_yaml_values take precedence over cluster
                # override_yaml_file (override_yaml_file ignored if not found)
                override_yaml_file = "override-tf.aks.<location>.<cluster_name>.yaml"  # "override-tf.aks.centralus.tf-jarvice-downstream.yaml"

                override_yaml_values = <<EOF
# override_yaml_values - takes precedence over override_yaml_file and
# global override_yaml_values

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10
EOF
            }
        }
    },
}

