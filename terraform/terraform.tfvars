# Terraform will automatically load values from this variable definitions file
# and then any *.auto.tfvars files.  e.g. Copy terraform.tfvars to
# override.auto.tfvars and make any configuration edits there.
#
# See the JARVICE Terraform Configuration documentation for more information
# on terraform variable definitions and JARVICE helm chart values:
# https://github.com/nimbix/jarvice-helm/blob/master/Terraform.md#terraform-configuration
#
# The following configuration sections available below:
#   * Global settings - Configuration options that apply to all clusters
#   * Kubernetes clusters - Deploy JARVICE to pre-existing K8s clusters
#   * GKE clusters - Provision GKE infrastructure/clusters and deploy JARVICE
#   * EKS clusters - Provision EKS infrastructure/clusters and deploy JARVICE
#   * AKS clusters - Provision AKS infrastructure/clusters and deploy JARVICE

#######################
### Global settings ###
#######################
global = {  # Global config options can be overridden in cluster configs
    meta = {
        ssh_public_key = "~/.ssh/id_rsa.pub"
    }

    helm = {
        jarvice = {
            repository = "https://nimbix.github.io/jarvice-helm/"
            # null version installs latest release from the helm repository.
            # Subsequent helm upgrades require that a specific release version
            # be set.  e.g. "3.0.0-1.XXXXXXXXXXXX"
            # Visit the following link for the latest release versions:
            # https://github.com/nimbix/jarvice-helm/releases
            version = null  # "../"  # "~/github/nimbix/jarvice-helm"

            # Available helm values for a released version can be found via:
            # version=3.0.0-1.XXXXXXXXXXXX; curl https://raw.githubusercontent.com/nimbix/jarvice-helm/$version/values.yaml
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
  #JARVICE_APPSYNC_USERONLY: "false"

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

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
### Kubernetes clusters ###
###########################
k8s = {  # Deploy JARVICE to pre-existing K8s clusters
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.k8s.<cluster_name>.yaml"  # "override-tf.k8s.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_JOBS_DOMAIN: # jarvice.my-domain.com/job$   # (path based ingress)
  #JARVICE_JOBS_DOMAIN: # my-domain.com  # (host based ingress)
  #JARVICE_JOBS_LB_SERVICE: "false"

  #tolerations: '[{"key": "node-role.jarvice.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}]'
  #nodeAffinity: # '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}]}, {"matchExpressions": [{"key": "node-role.kubernetes.io/jarvice-system", "operator": "Exists"}]}] }}'
  #nodeSelector: # '{"node-role.jarvice.io/jarvice-system": "true"}'

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

  #daemonsets:
  #  lxcfs:
  #    enabled: false

#jarvice_db: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #persistence:
  #  enabled: false
  #  # Set to "keep" to prevent removal or jarvice-db-pvc on helm delete
  #  resourcePolicy: ""  # "keep"
  #  # Use empty existingClaimName for dynamic provisioning via storageClass
  #  existingClaimName: # "jarvice-db-pvc"
  #  # storageClass: "-"
  #  storageClass: "jarvice-db"
  #  accessMode: ReadWriteOnce
  #  size: 8Gi
  #securityContext:
  #  enabled: false  # Enable when PersistentVolume is root squashed
  #  fsGroup: 999
  #  runAsUser: 999

# jarvice-license-manager runs on amd64 nodes only. In a multi-arch cluster, it
# may be necessary to set tolerations, nodeAffinity, and/or nodeSelector.
# Also, update/create jarvice-license-manager ConfigMap w/ servers.json data
# Uses "user:password" pair set in jarvice.JARVICE_LICENSE_MANAGER_KEY
#jarvice_license_manager: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #enabled: false
  #loadBalancerIP:
  #ingressHost: # jarvice-license-manager.my-domain.com
  #env:
  #  JARVICE_HOSTALIASES: # '[ {"ip": "10.20.0.1", "hostnames": ["hostname-1a"]}, {"ip": "10.20.0.2", "hostnames": ["hostname-2a", "hostname-2b"]} ]'
  #  JARVICE_LMSTAT_INTERVAL: 60
  #  JARVICE_S3_BUCKET:
  #  JARVICE_S3_ACCESSKEY:
  #  JARVICE_S3_SECRETKEY:
  #  JARVICE_S3_ENDPOINTURL: # https://s3.my-domain.com

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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-downstream"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.k8s.<cluster_name>.yaml"  # "override-tf.k8s.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_JOBS_DOMAIN: # jarvice.my-domain.com/job$   # (path based ingress)
  #JARVICE_JOBS_DOMAIN: # my-domain.com  # (host based ingress)
  #JARVICE_JOBS_LB_SERVICE: "false"

  #tolerations: '[{"key": "node-role.jarvice.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}, {"key": "node-role.kubernetes.io/jarvice-system", "effect": "NoSchedule", "operator": "Exists"}]'
  #nodeAffinity: # '{"requiredDuringSchedulingIgnoredDuringExecution": {"nodeSelectorTerms": [{"matchExpressions": [{"key": "node-role.jarvice.io/jarvice-system", "operator": "Exists"}]}, {"matchExpressions": [{"key": "node-role.kubernetes.io/jarvice-system", "operator": "Exists"}]}] }}'
  #nodeSelector: # '{"node-role.jarvice.io/jarvice-system": "true"}'

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

  #daemonsets:
  #  lxcfs:
  #    enabled: false

#jarvice_db: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #persistence:
  #  enabled: false
  #  # Set to "keep" to prevent removal or jarvice-db-pvc on helm delete
  #  resourcePolicy: ""  # "keep"
  #  # Use empty existingClaimName for dynamic provisioning via storageClass
  #  existingClaimName: # "jarvice-db-pvc"
  #  # storageClass: "-"
  #  storageClass: "jarvice-db"
  #  accessMode: ReadWriteOnce
  #  size: 8Gi
  #securityContext:
  #  enabled: false  # Enable when PersistentVolume is root squashed
  #  fsGroup: 999
  #  runAsUser: 999

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
### Google Cloud GKE clusters ###
#################################
gke = {  # Provision GKE infrastructure/clusters and deploy JARVICE
    gke_cluster_00 = {
        enabled = false

        auth = {  # Optional, null values are replaced with gcloud CLI defaults
            project = null
            credentials = null  # Path to JSON service account key file
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.gke.<region>.<cluster_name>.yaml"  # "override-tf.gke.us-west1.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

# Uses "user:password" pair set in jarvice.JARVICE_LICENSE_MANAGER_KEY
#jarvice_license_manager: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #enabled: false
  #env:
  #  JARVICE_HOSTALIASES: # '[ {"ip": "10.20.0.1", "hostnames": ["hostname-1a"]}, {"ip": "10.20.0.2", "hostnames": ["hostname-2a", "hostname-2b"]} ]'
  #  JARVICE_LMSTAT_INTERVAL: 60
  #  JARVICE_S3_BUCKET:
  #  JARVICE_S3_ACCESSKEY:
  #  JARVICE_S3_SECRETKEY:
  #  JARVICE_S3_ENDPOINTURL: # https://s3.my-domain.com
EOF
            }
        }
    },
    gke_cluster_01 = {
        enabled = false

        auth = {  # Optional, null values are replaced with gcloud CLI defaults
            project = null
            credentials = null  # Path to JSON service account key file
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.gke.<region>.<cluster_name>.yaml"  # "override-tf.gke.us-west1.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

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
### Amazon EKS clusters ###
###########################
eks = {  # Provision EKS infrastructure/clusters and deploy JARVICE
    eks_cluster_00 = {
        enabled = false

        auth = {  # Optional, null values are replaced with aws CLI defaults
            access_key = null
            secret_key = null
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.18"
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.eks.<region>.<cluster_name>.yaml"  # "override-tf.eks.us-west-2.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

# Uses "user:password" pair set in jarvice.JARVICE_LICENSE_MANAGER_KEY
#jarvice_license_manager: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #enabled: false
  #env:
  #  JARVICE_HOSTALIASES: # '[ {"ip": "10.20.0.1", "hostnames": ["hostname-1a"]}, {"ip": "10.20.0.2", "hostnames": ["hostname-2a", "hostname-2b"]} ]'
  #  JARVICE_LMSTAT_INTERVAL: 60
  #  JARVICE_S3_BUCKET:
  #  JARVICE_S3_ACCESSKEY:
  #  JARVICE_S3_SECRETKEY:
  #  JARVICE_S3_ENDPOINTURL: # https://s3.my-domain.com
EOF
            }
        }
    },
    eks_cluster_01 = {
        enabled = false

        auth = {  # Optional, null values are replaced with aws CLI defaults
            access_key = null
            secret_key = null
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.18"
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.eks.<region>.<cluster_name>.yaml"  # "override-tf.eks.us-west-2.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

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
### Azure AKS clusters ###
##########################
aks = {  # Provision AKS infrastructure/clusters and deploy JARVICE
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
            region = "southcentralus"  # "westus2"
            zones = []  # ["1"]
        }

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                }
            },
            #jxecompute01 = {
            #    nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.aks.<region>.<cluster_name>.yaml"  # "override-tf.aks.westus2.tf-jarvice.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

#jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  #JARVICE_CLUSTER_TYPE: "upstream"  # "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

# Uses "user:password" pair set in jarvice.JARVICE_LICENSE_MANAGER_KEY
#jarvice_license_manager: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #enabled: false
  #env:
  #  JARVICE_HOSTALIASES: # '[ {"ip": "10.20.0.1", "hostnames": ["hostname-1a"]}, {"ip": "10.20.0.2", "hostnames": ["hostname-2a", "hostname-2b"]} ]'
  #  JARVICE_LMSTAT_INTERVAL: 60
  #  JARVICE_S3_BUCKET:
  #  JARVICE_S3_ACCESSKEY:
  #  JARVICE_S3_SECRETKEY:
  #  JARVICE_S3_ENDPOINTURL: # https://s3.my-domain.com
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
            region = "southcentralus"  # "westus2"
            zones = []  # ["1"]
        }

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                }
            },
            #jxecompute01 = {
            #    nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
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
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.aks.<region>.<cluster_name>.yaml"  # "override-tf.aks.westus2.tf-jarvice-downstream.yaml"

                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "downstream"

  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"

  #JARVICE_PVC_VAULT_NAME: persistent
  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
  #JARVICE_PVC_VAULT_SIZE: 10

  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
  # jarvice_license_manager.enabled is true (may still be modified as needed)
  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"

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

