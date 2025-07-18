# CAPG        auth = {
            project = "my-project-id"  # GCP project ID
            service_account_key_file = ".tmp/mock-gcp-credentials.json"  # Path relative to terraform root
            # service_account_key_file = "~/.config/gcloud/terraform-sa-key.json"uster API Provider for GCP) clusters

capg = {
    capg_cluster_00 = {
        enabled = true

        auth = {
            project = "my-project-id"  # GCP project ID
            #service_account_key_file = ".tmp/mock-gcp-credentials.json"  # Path to service account key file
            service_account_key_file = "~/.config/gcloud/terraform-sa-key.json"
            
            # Alternatively, use environment variables:
            # export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
            # export GOOGLE_PROJECT="my-project-id"
            # export GOOGLE_REGION="us-west1"
        }

        # Meta information (used by common module)
        meta = {
            cluster_name = "tf-jarvice-capg"
            kubernetes_version = "v1.28.0"
            ssh_public_key = null  # global setting used if null specified
        }

        # Location information (used by common module)
        location = {
            region = "us-west1"
            zones = ["us-west1-a", "us-west1-b", "us-west1-c"]
        }

        # System node pool (used by common module)
        system_node_pool = {
            nodes_type = "n1-standard-4"
            nodes_num = 3
        }

        # Docker build node pool (used by common module for docker build operations)
        dockerbuild_node_pool = {
            nodes_type = "c2-standard-4"
            nodes_num = 1
            nodes_min = 0
            nodes_max = 5
        }

        # CAPG compute node pools (similar to GKE structure)
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "n1-standard-8"
                nodes_disk_size_gb = 100
                nodes_num = 0
                nodes_min = 0
                nodes_max = 20
                meta = {
                    disable_hyperthreading = "false"
                    disk_type = "pd-standard"
                    # enable_gcfs = "true"  # Google Cloud FileStore
                    # accelerator_type = "nvidia-tesla-v100"
                    # accelerator_count = 1
                }
            }
        }

        # CAPG-specific cluster configuration
        cluster = {
            project = "my-project-id"
            # zones = ["us-west1-a", "us-west1-b", "us-west1-c"]  # Optional, defaults to all zones in region
            
            # Network settings
            network = {
                name = "tf-jarvice-capg-network"
                create_network = true
                subnet_name = "tf-jarvice-capg-subnet"
                subnet_cidr = "10.0.0.0/16"
                pod_cidr = "192.168.0.0/16"
                service_cidr = "10.96.0.0/12"
            }

            # Control plane settings
            control_plane = {
                machine_type = "n1-standard-4"
                disk_size_gb = 100
                image = "ubuntu-2204-jammy-v20231213"
                # Optional GKE management integration
                gke_cluster_name = ""  # Empty for standalone CAPG
                enable_autopilot = false
                enable_autorepair = true
                enable_autoupgrade = false
                kubernetes_version = "v1.28.0"
            }

            # Node pool settings
            node_pools = {
                system = {
                    machine_type = "n1-standard-4"
                    disk_size_gb = 100
                    image = "ubuntu-2204-jammy-v20231213"
                    replicas = 3
                    min_replicas = 1
                    max_replicas = 10
                    labels = {}
                    taints = []
                    enable_autoscaling = true
                    enable_spot_instances = false
                    preemptible = false
                }
                # gpu = {
                #     machine_type = "n1-standard-4"
                #     disk_size_gb = 100
                #     image = "ubuntu-2204-jammy-v20231213"
                #     replicas = 0
                #     min_replicas = 0
                #     max_replicas = 10
                #     accelerator_type = "nvidia-tesla-t4"
                #     accelerator_count = 1
                #     labels = {}
                #     taints = []
                #     enable_autoscaling = true
                #     enable_spot_instances = false
                #     preemptible = false
                # }
            }

            # Cluster API settings
            cluster_api = {
                # management_cluster_context = "kind-capg-management"  # Optional, for external management cluster
                bootstrap_cluster_delete_timeout = "10m"
                # credential_secret_name = "capg-manager-bootstrap-credentials"
                # credential_secret_namespace = "capg-system"
            }

            # Load balancer and ingress settings
            load_balancer = {
                type = "external"  # "internal" or "external"
                # source_ranges = ["0.0.0.0/0"]  # CIDR blocks allowed to access load balancer
            }

            # Logging and monitoring
            logging = {
                enable_audit_logs = true
                # log_retention_days = 30
            }

            # Security settings
            security = {
                enable_network_policy = true
                enable_pod_security_policy = false
                enable_workload_identity = true
                # authorized_networks = []  # CIDR blocks allowed to access API server
            }

            # Add-ons
            addons = {
                install_cni = true
                cni_provider = "calico"  # "calico", "flannel", "weave"
                install_csi_driver = true
                install_dns = true
                install_cert_manager = true
                install_nvidia_driver = true
                install_metallb = false
                metallb_address_pool = "192.168.1.240-192.168.1.250"
            }

            # Backup and disaster recovery
            backup = {
                enable_etcd_backup = false
                # backup_schedule = "0 2 * * *"  # Daily at 2 AM
                # backup_retention_days = 7
            }

            # Maintenance window
            maintenance = {
                # day = "sunday"
                # start_time = "02:00"
                # duration = "4h"
            }

            domain_name = "my-domain.com"
            subdomain = "tf-jarvice-capg"
            
            # Resource labels
            labels = {
                # terraform = "true"
                # environment = "production"
                # team = "platform"
            }

            # Custom tags for all resources
            tags = {
                # Environment = "production"
                # Team = "platform"
                # Project = "jarvice"
            }
        }

        helm = {
            jarvice = {
                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
                namespace = "jarvice-system"

                # global values_yaml take precedence over cluster
                # values_file (values_file ignored if not found)
                values_file = "override-tf.capg.<region>.<cluster_name>.yaml"  # "override-tf.capg.us-west1.tf-jarvice-capg.yaml"
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
                values_yaml = <<EOF
# values_yaml - takes precedence over values_file and global values_yaml

jarvice:
  #JARVICE_IMAGES_TAG: jarvice-master
  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo

  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
  # settings in jarvice_* component stanzas are ignored.
  JARVICE_CLUSTER_TYPE: "upstream"

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

  # HTTP/S Proxy settings, no_proxy is set for services
  #JARVICE_HTTP_PROXY:   # "http://proxy.my-domain.com:8080"
  #JARVICE_HTTPS_PROXY:  # "https://proxy.my-domain.com:8080"
  #JARVICE_NO_PROXY:     # "my-other-domain.com,192.168.1.10,domain.com:8080"

  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
  #JARVICE_MAIL_USERNAME: # "mail-username"
  #JARVICE_MAIL_PASSWORD: # "Pass1234"
  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"

  #ingress:
  #  tls:
  #    issuer:
  #      name: "letsencrypt-prod"  # "letsencrypt-staging" # "selfsigned"
  #      # An admin email is required when letsencrypt issuer is set. The first
  #      # JARVICE_MAIL_ADMINS email will be used if issuer.email is not set.
  #      email: # "admin@my-domain.com"
  #    # If crt and key values are provided, issuer settings will be ignored
  #    crt: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.pem
  #    key: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.key

#jarvice_images_pull: # Auto-enabled on clusters with GCFS enabled node pool(s)
  #schedule: "0 4 * * *"
  #scheduleNow: false  # Immediately schedule images pull job on install/upgrade
  #images:
  #  amd64:
  #    - us-docker.pkg.dev/jarvice/images/app-filemanager:ocpassform
  #    - us-docker.pkg.dev/jarvice/images/ubuntu-desktop:bionic
  #    - us-docker.pkg.dev/jarvice/images/app-openfoam:8

#jarvice_k8s_scheduler:
  #ingressHost: tf-jarvice-capg.my-domain.com

#jarvice_slurm_scheduler:
  #enabled: true
  #schedulers:
  #- name: default
    #ingressHost: # jarvice-slurm.my-domain.com
    #env:
      #JARVICE_SLURM_CLUSTER_ADDR: # address for slurm headnode
    #sshConf:
      #user: # user to ssh into slurm headnode (e.g. nimbix)
      #pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.

#jarvice_license_manager:
  #enabled: true
  #ingressHost: jarvice-license-manager.my-domain.com

#jarvice_bird:
  #enabled: true
  #ingressHost: jarvice-bird.my-domain.com
  #cluster: # tf-jarvice-capg
  #egressIPs:
    #- 1.2.3.4
    #- 5.6.7.8
  #systemJobPriorityClass: jarvice-system-compute-priority
  #systemJobNodesSelector: {}
  #systemJobNodesAffinity: {}
  #storageClass: jarvice-db
  #size: 20Gi
  #accessMode: ReadWriteOnce
  #database:
    #host: # jarvice-db-postgresql
    #port: 5432
    #username: jarvice
    #password: # Set in cluster's config secret
    #name: jarvice_bird

#jarvice_pod_scheduler:
  #enabled: true  # Enable multitenancy?
  #ingressHost: jarvice-pod-scheduler.my-domain.com
  #cluster: # tf-jarvice-capg
  #tolerations:
    #- key: "node-role.kubernetes.io/master"
      #operator: "Equal"
      #value: ""
      #effect: "NoSchedule"
  #nodeSelector:
    #node-role.kubernetes.io/master: ""
  #affinity: {}
  #systemJobPriorityClass: jarvice-system-compute-priority
  #systemJobNodesSelector: {}
  #systemJobNodesAffinity: {}
EOF
            }
        }
    },

#    # capg_cluster_01 = {
#    #     enabled = true
#    #
#    #     auth = {
#    #         project = "my-project-id"  # GCP project ID
#    #         service_account_key_file = null  # Path to service account key file
#    #         # service_account_key_file = "~/.config/gcloud/terraform-sa-key.json"
#    #     }
#
#        # Meta information (used by common module)
#        meta = {
#            cluster_name = "tf-jarvice-capg-downstream"
#            kubernetes_version = "v1.28.0"
#            ssh_public_key = null  # global setting used if null specified
#        }
#
#        # Location information (used by common module)
#        location = {
#            region = "us-west1"
#            zones = ["us-west1-a", "us-west1-b", "us-west1-c"]
#        }
#
#        # System node pool (used by common module)
#        system_node_pool = {
#            nodes_type = "n1-standard-2"
#            nodes_num = 2
#        }
#
#        # Docker build node pool (used by common module for docker build operations)
#        dockerbuild_node_pool = {
#            nodes_type = "c2-standard-4"
#            nodes_num = 1
#            nodes_min = 0
#            nodes_max = 5
#        }
#
#        # CAPG compute node pools (similar to GKE structure)
#        compute_node_pools = {
#            jxecompute00 = {
#                nodes_type = "n1-standard-8"
#                nodes_disk_size_gb = 100
#                nodes_num = 0
#                nodes_min = 0
#                nodes_max = 10
#                meta = {
#                    disable_hyperthreading = "false"
#                    disk_type = "pd-standard"
#                    # enable_gcfs = "true"  # Google Cloud FileStore
#                    # accelerator_type = "nvidia-tesla-v100"
#                    # accelerator_count = 1
#                }
#            }
#        }
#
#        # CAPG-specific cluster configuration
#        cluster = {
#            project = "my-project-id"
#            
#            # Network settings - can use existing network from upstream cluster
#            network = {
#                name = "tf-jarvice-capg-network"
#                create_network = false  # Use existing network
#                subnet_name = "tf-jarvice-capg-downstream-subnet"
#                subnet_cidr = "10.1.0.0/16"
#                pod_cidr = "192.169.0.0/16"
#                service_cidr = "10.97.0.0/12"
#            }
#
#            # Control plane settings
#            control_plane = {
#                machine_type = "n1-standard-2"
#                disk_size_gb = 50
#                image = "ubuntu-2204-jammy-v20231213"
#                # Optional GKE management integration
#                gke_cluster_name = ""  # Empty for standalone CAPG
#                enable_autopilot = false
#                enable_autorepair = true
#                enable_autoupgrade = false
#                kubernetes_version = "v1.28.0"
#            }
#
#            # Node pool settings
#            node_pools = {
#                system = {
#                    machine_type = "n1-standard-2"
#                    disk_size_gb = 50
#                    image = "ubuntu-2204-jammy-v20231213"
#                    replicas = 2
#                    min_replicas = 1
#                    max_replicas = 5
#                    labels = {}
#                    taints = []
#                    enable_autoscaling = true
#                    enable_spot_instances = true
#                    preemptible = true
#                }
#                compute = {
#                    machine_type = "n1-standard-8"
#                    disk_size_gb = 100
#                    image = "ubuntu-2204-jammy-v20231213"
#                    replicas = 0
#                    min_replicas = 0
#                    max_replicas = 20
#                    enable_autoscaling = true
#                    enable_spot_instances = true
#                    preemptible = true
#                    labels = {
#                        "node-role.jarvice.io/jarvice-compute" = "true"
#                    }
#                    taints = [
#                        {
#                            key = "node-role.jarvice.io/jarvice-compute"
#                            value = "true"
#                            effect = "NoSchedule"
#                        }
#                    ]
#                }
#            }
#
#            # Load balancer and ingress settings
#            load_balancer = {
#                type = "external"
#            }
#
#            # Add-ons
#            addons = {
#                install_cni = true
#                cni_provider = "calico"
#                install_csi_driver = true
#                install_dns = true
#                install_cert_manager = true
#                install_nvidia_driver = true
#                install_metallb = false
#                metallb_address_pool = "192.168.1.240-192.168.1.250"
#            }
#
#            # Cluster API settings
#            cluster_api = {
#                bootstrap_cluster_delete_timeout = "10m"
#            }
#
#            # Logging and monitoring
#            logging = {
#                enable_audit_logs = true
#            }
#
#            # Security settings
#            security = {
#                enable_network_policy = true
#                enable_pod_security_policy = false
#                enable_workload_identity = true
#            }
#
#            # Backup and disaster recovery
#            backup = {
#                enable_etcd_backup = false
#            }
#
#            # Maintenance window
#            maintenance = {
#                # day = "sunday"
#                # start_time = "02:00"
#                # duration = "4h"
#            }
#
#            domain_name = "my-domain.com"
#            subdomain = "tf-jarvice-capg-downstream"
#            
#            # Resource labels
#            labels = {
#                # terraform = "true"
#                # environment = "production"
#                # team = "platform"
#                # cluster_type = "downstream"
#            }
#
#            # Custom tags for all resources
#            tags = {
#                # Environment = "production"
#                # Team = "platform"
#                # Project = "jarvice"
#                # ClusterType = "downstream"
#            }
#        }
#
#        helm = {
#            jarvice = {
#                # version = "3.0.0-1.XXXXXXXXXXXX"  # Override global version
#                namespace = "jarvice-system"
#
#                # global values_yaml take precedence over cluster
#                # values_file (values_file ignored if not found)
#                values_file = "override-tf.capg.<region>.<cluster_name>.yaml"  # "override-tf.capg.us-west1.tf-jarvice-capg-downstream.yaml"
#                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
#                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
#                values_yaml = <<EOF
## values_yaml - takes precedence over values_file and global values_yaml
#
#jarvice:
#  #JARVICE_IMAGES_TAG: jarvice-master
#  #JARVICE_IMAGES_VERSION: # auto-set (ignored) if installing from chart repo
#
#  # If JARVICE_CLUSTER_TYPE is set to "downstream", relevant "upstream"
#  # settings in jarvice_* component stanzas are ignored.
#  JARVICE_CLUSTER_TYPE: "downstream"
#
#  # If deploying "downstream" cluster, be sure to set JARVICE_SCHED_SERVER_KEY
#  #JARVICE_SCHED_SERVER_KEY: # "jarvice-downstream:Pass1234"
#
#  #JARVICE_PVC_VAULT_NAME: persistent
#  #JARVICE_PVC_VAULT_STORAGECLASS: jarvice-user
#  #JARVICE_PVC_VAULT_ACCESSMODES: ReadWriteOnce
#  #JARVICE_PVC_VAULT_SIZE: 10
#
#  # JARVICE_LICENSE_MANAGER_URL is auto-set in "upstream" deployments if
#  # jarvice_license_manager.enabled is true (may still be modified as needed)
#  #JARVICE_LICENSE_MANAGER_URL: # "https://jarvice-license-manager.my-domain.com"
#  #JARVICE_LICENSE_MANAGER_SSL_VERIFY: "true"
#  #JARVICE_LICENSE_MANAGER_KEY: "jarvice-license-manager:Pass1234"
#
#  # HTTP/S Proxy settings, no_proxy is set for services
#  #JARVICE_HTTP_PROXY:   # "http://proxy.my-domain.com:8080"
#  #JARVICE_HTTPS_PROXY:  # "https://proxy.my-domain.com:8080"
#  #JARVICE_NO_PROXY:     # "my-other-domain.com,192.168.1.10,domain.com:8080"
#
#  #JARVICE_MAIL_SERVER: jarvice-smtpd:25
#  #JARVICE_MAIL_USERNAME: # "mail-username"
#  #JARVICE_MAIL_PASSWORD: # "Pass1234"
#  #JARVICE_MAIL_ADMINS: # "admin1@my-domain.com,admin2@my-domain.com"
#  #JARVICE_MAIL_FROM: "JARVICE Job Status <DoNotReply@localhost>"
#  #JARVICE_PORTAL_MAIL_FROM: "JARVICE Account Status <DoNotReply@localhost>"
#  #JARVICE_PORTAL_MAIL_SUBJECT: "Your JARVICE Account"
#
#  #ingress:
#  #  tls:
#  #    issuer:
#  #      name: "letsencrypt-prod"  # "letsencrypt-staging" # "selfsigned"
#  #      # An admin email is required when letsencrypt issuer is set. The first
#  #      # JARVICE_MAIL_ADMINS email will be used if issuer.email is not set.
#  #      email: # "admin@my-domain.com"
#  #    # If crt and key values are provided, issuer settings will be ignored
#  #    crt: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.pem
#  #    key: # base64 encoded.  e.g. Execute: base64 -w 0 <site-domain>.key
#
##jarvice_images_pull: # Auto-enabled on clusters with GCFS enabled node pool(s)
#  #schedule: "0 4 * * *"
#  #scheduleNow: false  # Immediately schedule images pull job on install/upgrade
#  #images:
#  #  amd64:
#  #    - us-docker.pkg.dev/jarvice/images/app-filemanager:ocpassform
#  #    - us-docker.pkg.dev/jarvice/images/ubuntu-desktop:bionic
#  #    - us-docker.pkg.dev/jarvice/images/app-openfoam:8
#
##jarvice_k8s_scheduler:
#  #ingressHost: tf-jarvice-capg-downstream.my-domain.com
#
##jarvice_slurm_scheduler:
#  #enabled: true
#  #schedulers:
#  #- name: default
#    #ingressHost: # jarvice-slurm.my-domain.com
#    #env:
#      #JARVICE_SLURM_CLUSTER_ADDR: # address for slurm headnode
#    #sshConf:
#      #user: # user to ssh into slurm headnode (e.g. nimbix)
#      #pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.
#EOF
#            }
#        }
#    }
}
