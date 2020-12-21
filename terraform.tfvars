# Terraform will automatically load values from this variable definitions file
# and then any *.auto.tfvars files.  e.g. Copy terraform.tfvars to
# override.auto.tfvars and make any configuration edits there.
#
# See the JARVICE Terraform Configuration documentation for more information
# on terraform variable definitions and JARVICE helm chart values:
# https://github.com/nimbix/jarvice-helm/blob/master/Terraform.md#terraform-configuration

#######################
### Global settings ###
#######################
global = {
    meta = {
        ssh_public_key = "~/.ssh/id_rsa.pub"
    }

    helm = {
        jarvice = {
            version = "./"

            values_file = "values.yaml"  # ignored if file does not exist
            values_yaml = <<EOF
# global values_yaml - Uncomment or add any values that should be
# applied to all defined clusters.

# Update per cluster values_yaml to override these global values.

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
        }
    }
}

###########################
### Kubernetes settings ###
###########################
k8s = {
    k8s_cluster_00 = {
        enabled = false

        auth = {
            kube_config = "~/.kube/config"
        }

        meta = {
            cluster_name = "tf-jarvice"
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.k8s.<cluster_name>.yaml"  # "override-tf.k8s.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_JOBS_DOMAIN: # jarvice.my-domain.com/job$   # (path based ingress)
  #JARVICE_JOBS_DOMAIN: # my-domain.com  # (host based ingress)
  #JARVICE_JOBS_LB_SERVICE: false

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

#jarvice_k8s_scheduler:
  # loadBalancerIP and ingressHost are only applicable when
  # jarvice.JARVICE_CLUSTER_TYPE is set to "downstream"
  #loadBalancerIP:
  #ingressHost: # jarvice-k8s-scheduler.my-domain.com

#jarvice_api:
  #loadBalancerIP:
  #ingressHost: # jarvice-api.my-domain.com
  #ingressPath: "/"  # Valid values are "/" (default) or "/api"

#jarvice_mc_portal:
  #loadBalancerIP:
  #ingressHost: # jarvice.my-domain.com
  #ingressPath: "/"  # Valid values are "/" (default) or "/portal"
EOF
            }
        }
    },
    k8s_cluster_01 = {
        enabled = false

        auth = {
            kube_config = "~/.kube/config.downstream"
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-downstream"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.k8s.<cluster_name>.yaml"  # "override-tf.k8s.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION:

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_JOBS_DOMAIN: # jarvice.my-domain.com/job$   # (path based ingress)
  #JARVICE_JOBS_DOMAIN: # my-domain.com  # (host based ingress)
  #JARVICE_JOBS_LB_SERVICE: false

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

#jarvice_k8s_scheduler:
  # loadBalancerIP and ingressHost are only applicable when
  # jarvice.JARVICE_CLUSTER_TYPE is set to "downstream"
  #loadBalancerIP:
  #ingressHost: # jarvice-k8s-scheduler.my-domain.com

#jarvice_api:
  #loadBalancerIP:
  #ingressHost: # jarvice-api.my-domain.com
  #ingressPath: "/"  # Valid values are "/" (default) or "/api"

#jarvice_mc_portal:
  #loadBalancerIP:
  #ingressHost: # jarvice.my-domain.com
  #ingressPath: "/"  # Valid values are "/" (default) or "/portal"
EOF
            }
        }
    },
}

#################################
### Google Cloud GKE Settings ###
#################################
gke = {
    gke_cluster_00 = {
        enabled = false

        auth = {
            project = null
            credentials = null
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.16"

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "us-west1"
            zones = ["us-west1-b"]
        }

        # Visit the following link for GCP machine type specs:
        # https://cloud.google.com/compute/docs/machine-types
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                # n1 node_type is required for accelerator attachment
                nodes_type = "c2-standard-60"  # "n1-standard-64"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                    disable_hyperthreading = "true"

                    # Visit the following link for GCP accelerator type specs:
                    # https://cloud.google.com/compute/docs/gpus
                    #accelerator_type = "nvidia-tesla-v100"
                    #accelerator_count = 8
                }
            },
            #jxecompute01 = {
            #    # n1 node_type is required for accelerator attachment
            #    nodes_type = "c2-standard-60"  # "n1-standard-64"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #        disable_hyperthreading = "true"
            #
            #        # Visit the following link for GCP accelerator type specs:
            #        # https://cloud.google.com/compute/docs/gpus
            #        #accelerator_type = "nvidia-tesla-v100"
            #        #accelerator_count = 8
            #    }
            #},
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.gke.<region>.<cluster_name>.yaml"  # "override-tf.gke.us-west1.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
            }
        }
    },
    gke_cluster_01 = {
        enabled = false

        auth = {
            project = null
            credentials = null
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.16"

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "us-west1"
            zones = ["us-west1-b"]
        }

        # Visit the following link for GCP machine type specs:
        # https://cloud.google.com/compute/docs/machine-types
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                # n1 node_type is required for accelerator attachment
                nodes_type = "c2-standard-60"  # "n1-standard-64"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                    disable_hyperthreading = "true"

                    # Visit the following link for GCP accelerator type specs:
                    # https://cloud.google.com/compute/docs/gpus
                    #accelerator_type = "nvidia-tesla-v100"
                    #accelerator_count = 8
                }
            },
            #jxecompute01 = {
            #    # n1 node_type is required for accelerator attachment
            #    nodes_type = "c2-standard-60"  # "n1-standard-64"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #        disable_hyperthreading = "true"
            #
            #        # Visit the following link for GCP accelerator type specs:
            #        # https://cloud.google.com/compute/docs/gpus
            #        #accelerator_type = "nvidia-tesla-v100"
            #        #accelerator_count = 8
            #    }
            #},
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.gke.<region>.<cluster_name>.yaml"  # "override-tf.gke.us-west1.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
            }
        }
    },
}


###########################
### Amazon EKS Settings ###
###########################
eks = {
    eks_cluster_00 = {
        enabled = false

        auth = {
            access_key = null
            secret_key = null
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.16"
            #arch = "arm64"  # Uncomment to deploy an arm64 cluster

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "us-west-2"
            zones = ["us-west-2a"]
        }

        # Visit the following link for AWS instance type specs:
        # https://aws.amazon.com/ec2/instance-types/
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "c5.18xlarge"  # "c6g.16xlarge"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                    disable_hyperthreading = "true"
                }
            },
            #jxecompute01 = {
            #    nodes_type = "c5.18xlarge"  # "c6g.16xlarge"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #        disable_hyperthreading = "true"
            #    }
            #},
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.eks.<region>.<cluster_name>.yaml"  # "override-tf.eks.us-west-2.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
            }
        }
    },
    eks_cluster_01 = {
        enabled = false

        auth = {
            access_key = null
            secret_key = null
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.16"
            #arch = "arm64"  # Uncomment to deploy an arm64 cluster

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "us-west-2"
            zones = ["us-west-2a"]
        }

        # Visit the following link for AWS instance type specs:
        # https://aws.amazon.com/ec2/instance-types/
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "c5.18xlarge"  # "c6g.16xlarge"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                    disable_hyperthreading = "true"
                }
            },
            #jxecompute01 = {
            #    nodes_type = "c5.18xlarge"  # "c6g.16xlarge"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #        disable_hyperthreading = "true"
            #    }
            #},
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.eks.<region>.<cluster_name>.yaml"  # "override-tf.eks.us-west-2.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
            }
        }
    },
}


##########################
### Azure AKS settings ###
##########################
aks = {
    aks_cluster_00 = {
        enabled = false

        # Visit the following link for service principal creation information:
        # https://github.com/nimbix/jarvice-helm/blob/testing/Terraform.md#creating-a-service-principal-using-the-azure-cli
        auth = {
            service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.16"

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "westus2"
            zones = ["1"]
        }

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "Standard_D15_v2"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                }
            },
            #jxecompute01 = {
            #    nodes_type = "Standard_D15_v2"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #    }
            #},
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.aks.<region>.<cluster_name>.yaml"  # "override-tf.aks.westus2.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
            }
        }
    },
    aks_cluster_01 = {
        enabled = false

        # Visit the following link for service principal creation information:
        # https://github.com/nimbix/jarvice-helm/blob/testing/Terraform.md#creating-a-service-principal-using-the-azure-cli
        auth = {
            service_principal_client_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
            service_principal_client_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.16"

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "westus2"
            zones = ["1"]
        }

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "Standard_D15_v2"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                }
            },
            #jxecompute01 = {
            #    nodes_type = "Standard_D15_v2"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #    }
            #},
        }

        helm = {
            jarvice = {
                # version = "./"  # Uncomment to override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.aks.<region>.<cluster_name>.yaml"  # "override-tf.aks.westus2.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

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

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
EOF
            }
        }
    },
}

