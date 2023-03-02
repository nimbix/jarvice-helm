# Terraform will automatically load values from this variable definitions file
# and then any *.auto.tfvars files.  e.g. Copy terraform.tfvars to
# override.auto.tfvars and make any configuration edits there.
#
# See the JARVICE Terraform Configuration documentation for more information
# on terraform variable definitions and JARVICE helm chart values:
# https://github.com/nimbix/jarvice-helm/blob/master/Terraform.md#terraform-configuration
#
# The following configuration sections are available below:
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
            # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
            # user_java_cacert = "/etc/ssl/certs/java/cacerts"
            values_yaml = <<EOF
# global values_yaml - Uncomment or add any values that should be
# applied to all defined clusters.

# Update per cluster values_yaml to override these global values.

#jarvice:
  # imagePullSecret is a base64 encoded string.
  # e.g. - echo "_json_key:$(cat key.json)" | base64 -w 0
  #imagePullSecret:
  #JARVICE_LICENSE_LIC:

  # JARVICE_REMOTE_* settings are used for application synchronization
  #JARVICE_REMOTE_API_URL: https://cloud.nimbix.net/api
  #JARVICE_REMOTE_USER:
  #JARVICE_REMOTE_APIKEY:
  #JARVICE_APPSYNC_USERONLY: "false"

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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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

#jarvice_dockerbuild: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #persistence:  # Enable to execute builds on dynamically provisioned PVCs
  #  enabled: false
  #  # storageClass: "-"  # "-" uses cluster's default StorageClass/provisioner
  #  storageClass: "jarvice-dockerbuild"
  #  size: 300Gi

# Enable to use a kubernetes CronJob to garbage collect dockerbuild PVCs
# N/A if jarvice_dockerbuild.persistence.enabled is false
#jarvice_dockerbuild_pvc_gc:
  #enabled: false
  #env:
  #  JARVICE_BUILD_PVC_KEEP_SUCCESSFUL: 3600  # Default: 3600 (1 hour)
  #  JARVICE_BUILD_PVC_KEEP_ABORTED: 7200  # Default: 7200 (2 hours)
  #  JARVICE_BUILD_PVC_KEEP_FAILED: 14400  # Default: 14400 (4 hours)

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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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
            kubernetes_version = "1.21"

            # Sync ingress hosts to zones/domains managed w/ Google Cloud DNS
            #dns_manage_records = "true"
            # Google Cloud project which contains the DNS zone for domain(s)
            #dns_zone_project = "tf-jarvice"  # If diff than cluster's project

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
        dockerbuild_node_pool = {  # N/A for downstream clusters
            nodes_type = "c2-standard-4"
            nodes_num = 1
            nodes_min = 0
            nodes_max = 5
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
                    disk_type = "pd-standard" # "pd-ssd" # "pd-balanced"
                    #enable_gcfs = "true"
                    #zones = "us-west1-a,us-west1-b,us-west1-c"

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
            #        disk_type = "pd-standard" # "pd-ssd" # "pd-balanced"
            #        #enable_gcfs = "true"
            #        #zones = "us-west1-a,us-west1-b,us-west1-c"
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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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

#jarvice_dockerbuild: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #persistence:
  #  size: 300Gi

#jarvice_dockerbuild_pvc_gc:
  #env:
  #  JARVICE_BUILD_PVC_KEEP_SUCCESSFUL: 3600  # Default: 3600 (1 hour)
  #  JARVICE_BUILD_PVC_KEEP_ABORTED: 7200  # Default: 7200 (2 hours)
  #  JARVICE_BUILD_PVC_KEEP_FAILED: 14400  # Default: 14400 (4 hours)

#jarvice_images_pull: # Auto-enabled on clusters with GCFS enabled node pool(s)
  #schedule: "0 4 * * *"
  #scheduleNow: false  # Immediately schedule images pull job on install/upgrade
  #images:
  #  amd64:
  #    - us-docker.pkg.dev/jarvice/images/app-filemanager:ocpassform
  #    - us-docker.pkg.dev/jarvice/images/ubuntu-desktop:bionic
  #    - us-docker.pkg.dev/jarvice/images/app-openfoam:8

#jarvice_api:
  #ingressHost: tf-jarvice.my-domain.com
  #ingressPath: "/api"

#jarvice_mc_portal:
  #ingressHost: tf-jarvice.my-domain.com

#jarvice_slurm_scheduler:
  #enabled: true
  #schedulers:
  #- name: default
    #env:
      #JARVICE_SLURM_CLUSTER_ADDR: # address for slurm headnode
    #sshConf:
      #user: # user to ssh into slurm headnode (e.g. nimbix)
      #pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.

keycloak:
  enabled: false
  create_realm: false
  env:
    JARVICE_REALM_ADMIN: nimbix # jarvice realm admin username
    JARVICE_REALM_ADMIN_PASSWD: abc1234! # jarvice realm admin password
    JARVICE_KEYCLOAK_ADMIN: jarvice # keycloak master realm username
    JARVICE_KEYCLOAK_ADMIN_PASSWD: Pass1234 # keycloak master realm password
  extraEnv: |
    - name: KEYCLOAK_USER
      value: "jarvice"
    - name: KEYCLOAK_PASSWORD
      value: "Pass1234"
    - name: PROXY_ADDRESS_FORWARDING
      value: "true"
    - name: KEYCLOAK_IMPORT
      value: /realm/realm.json
  ingress:
    enabled: true
    annotations:
      cert-manager.io/issuer: # letsencrypt-staging
    ingressClassName: traefik
    rules:
    - host: # ingress host
      paths:
      - path: /
        pathType: Prefix
    tls:
    - hosts:
      - # ingress host
      secretName: # ingress host (tls-<ingress-host>)
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
            kubernetes_version = "1.21"

            # Sync ingress hosts to zones/domains managed w/ Google Cloud DNS
            #dns_manage_records = "true"
            # Google Cloud project which contains the DNS zone for domain(s)
            #dns_zone_project = "tf-jarvice"  # If diff than cluster's project

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
        dockerbuild_node_pool = {  # N/A for downstream clusters
            nodes_type = null
            nodes_num = 0
            nodes_min = 0
            nodes_max = 0
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
                    disk_type = "pd-standard" # "pd-ssd" # "pd-balanced"
                    #enable_gcfs = "true"
                    #zones = "us-west1-a,us-west1-b,us-west1-c"

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
            #        disk_type = "pd-standard" # "pd-ssd" # "pd-balanced"
            #        #enable_gcfs = "true"
            #        #zones = "us-west1-a,us-west1-b,us-west1-c"
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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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
  #ingressHost: tf-jarvice-downstream.my-domain.com

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
            kubernetes_version = "1.21"
            #arch = "arm64"  # Uncomment to deploy an arm64 cluster

            # Sync ingress hosts to zones/domains managed w/ AWS Route53 DNS
            #dns_manage_records = "true"

            #Join existing VPC by defining the VPC ID here. Make sure to set allow_cluster_join to true on the deployment that manages the VPC you are trying to join.
            #vpc_id = "aws_vpc_id"
            #Set to true if you want to allow another jarvice-helm deployment to join this deployments VPC allowing them to both use the same storage and subnets. NOTE: Setting allow_cluster_join = "true" will cause terraform to add kubernetes tags when they already exist.
            #This is done to avoid Terraform removing the joining clusters tags, these changes should not interupt running jobs and can be ignored during terraform plan/apply operations.
            #allow_cluster_join = "true"

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "us-west-2"
            zones = ["us-west-2a", "us-west-2b"]
        }

        # Visit the following link for AWS instance type specs:
        # https://aws.amazon.com/ec2/instance-types/
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        dockerbuild_node_pool = {  # N/A for downstream clusters
            nodes_type = "c5n.xlarge"  # "c6gn.xlarge"
            nodes_num = 1
            nodes_min = 0
            nodes_max = 5
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
                    #zones = "us-west-2a,us-west-2b,us-west-2c"

                    # EFA requires k8s ver >= 1.19.  Supported instance types:
                    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types (four p4d.24xlarge EFA interfaces not yet supported)
                    #interface_type = "efa"

                    #Define custom ami_id for compute nodes. Leave commented out to pull in newest version of the AMI which will recreate pool.
                    #ami_id

                    #Indicate whether the node pool should have a GPU capable AWS ami.
                    #gpu = "true"
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
            #        #zones = "us-west-2a,us-west-2b,us-west-2c"
            #
            #        # EFA requires k8s ver >= 1.19.  Supported instance types:
            #        # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types (four p4d.24xlarge EFA interfaces not yet supported)
            #        #interface_type = "efa"
            # 
            #        #Define custom ami_id for compute nodes. Leave commented out to pull in newest version of the AMI which will recreate pool.
            #        #ami_id

            #        #Indicate whether the node pool should have a GPU capable AWS ami.
            #        #gpu = "true"
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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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

#jarvice_dockerbuild: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #persistence:
  #  size: 300Gi

#jarvice_dockerbuild_pvc_gc:
  #env:
  #  JARVICE_BUILD_PVC_KEEP_SUCCESSFUL: 3600  # Default: 3600 (1 hour)
  #  JARVICE_BUILD_PVC_KEEP_ABORTED: 7200  # Default: 7200 (2 hours)
  #  JARVICE_BUILD_PVC_KEEP_FAILED: 14400  # Default: 14400 (4 hours)

#jarvice_api:
  #ingressHost: tf-jarvice.my-domain.com
  #ingressPath: "/api"

#jarvice_mc_portal:
  #ingressHost: tf-jarvice.my-domain.com

#jarvice_slurm_scheduler:
  #enabled: true
  #schedulers:
  #- name: default
    #env:
      #JARVICE_SLURM_CLUSTER_ADDR: # address for slurm headnode
    #sshConf:
      #user: # user to ssh into slurm headnode (e.g. nimbix)
      #pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.
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
            kubernetes_version = "1.21"
            #arch = "arm64"  # Uncomment to deploy an arm64 cluster

            # Sync ingress hosts to zones/domains managed w/ AWS Route53 DNS
            #dns_manage_records = "true"

            #Join existing VPC by defining the VPC ID here. Make sure to set allow_cluster_join to true on the deployment that manages the VPC you are trying to join.
            #vpc_id = "aws_vpc_id"
            #Set to true if you want to allow another jarvice-helm deployment to join this deployments VPC allowing them to both use the same storage and subnets. NOTE: Setting allow_cluster_join = "true" will cause terraform to add kubernetes tags when they already exist.
            #This is done to avoid Terraform removing the joining clusters tags, these changes should not interupt running jobs and can be ignored during terraform plan/apply operations.
            #allow_cluster_join = "true"

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "us-west-2"
            zones = ["us-west-2a", "us-west-2b"]
        }

        # Visit the following link for AWS instance type specs:
        # https://aws.amazon.com/ec2/instance-types/
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        dockerbuild_node_pool = {  # N/A for downstream clusters
            nodes_type = null
            nodes_num = 0
            nodes_min = 0
            nodes_max = 0
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
                    #zones = "us-west-2a,us-west-2b,us-west-2c"

                    # EFA requires k8s ver >= 1.19.  Supported instance types:
                    # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types (four p4d.24xlarge EFA interfaces not yet supported)
                    #interface_type = "efa"
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
            #        #zones = "us-west-2a,us-west-2b,us-west-2c"
            #
            #        # EFA requires k8s ver >= 1.19.  Supported instance types:
            #        # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa.html#efa-instance-types (four p4d.24xlarge EFA interfaces not yet supported)
            #        #interface_type = "efa"
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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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

#jarvice_k8s_scheduler:
  #ingressHost: tf-jarvice-downstream.my-domain.com

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

        auth = {  # Authenticate w/ 'az login' prior to deployment
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.21"

            # Sync ingress hosts to zones/domains managed w/ Azure DNS
            #dns_manage_records = "true"
            # Azure resource group which contains the DNS zone for the domain
            #dns_zone_resource_group = "tf-jarvice-dns"  # (required for mgmt)

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "southcentralus"  # "westus2"
            zones = ["1"]
        }

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        dockerbuild_node_pool = {  # N/A for downstream clusters
            nodes_type = "Standard_F4s_v2"
            nodes_num = 1
            nodes_min = 0
            nodes_max = 5
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                    #zones = "1,2,3"
                }
            },
            #jxecompute01 = {
            #    nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #        #zones = "1,2,3"
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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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

#jarvice_dockerbuild: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  #persistence:
  #  size: 300Gi

#jarvice_dockerbuild_pvc_gc:
  #env:
  #  JARVICE_BUILD_PVC_KEEP_SUCCESSFUL: 3600  # Default: 3600 (1 hour)
  #  JARVICE_BUILD_PVC_KEEP_ABORTED: 7200  # Default: 7200 (2 hours)
  #  JARVICE_BUILD_PVC_KEEP_FAILED: 14400  # Default: 14400 (4 hours)

#jarvice_api:
  #ingressHost: tf-jarvice.my-domain.com
  #ingressPath: "/api"

#jarvice_mc_portal:
  #ingressHost: tf-jarvice.my-domain.com

#jarvice_slurm_scheduler:
  #enabled: true
  #schedulers:
  #- name: default
    #env:
      #JARVICE_SLURM_CLUSTER_ADDR: # address for slurm headnode
    #sshConf:
      #user: # user to ssh into slurm headnode (e.g. nimbix)
      #pkey: # base64 encoded private ssh key for JXE slurm scheduler service. Add public key to slurm headnode.
EOF
            }
        }
    },
    aks_cluster_01 = {
        enabled = false

        auth = {  # Authenticate w/ 'az login' prior to deployment
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.21"

            # Sync ingress hosts to zones/domains managed w/ Azure DNS
            #dns_manage_records = "true"
            # Azure resource group which contains the DNS zone for the domain
            #dns_zone_resource_group = "tf-jarvice-dns"  # (required for mgmt)

            ssh_public_key = null  # global setting used if null specified
        }

        location = {
            region = "southcentralus"  # "westus2"
            zones = ["1"]
        }

        # Visit the following link for Azure node size specs:
        # https://docs.microsoft.com/en-us/azure/cloud-services/cloud-services-sizes-specs
        system_node_pool = {
            nodes_type = null  # auto-set if null specified
            nodes_num = null   # auto-set if null specified
        }
        dockerbuild_node_pool = {  # N/A for downstream clusters
            nodes_type = null
            nodes_num = 0
            nodes_min = 0
            nodes_max = 0
        }
        compute_node_pools = {
            jxecompute00 = {
                nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
                nodes_disk_size_gb = 100
                nodes_num = 2
                nodes_min = 1
                nodes_max = 16
                meta = {
                    #zones = "1,2,3"
                }
            },
            #jxecompute01 = {
            #    nodes_type = "Standard_D15_v2"  # "Standard_NC12s_v3"
            #    nodes_disk_size_gb = 100
            #    nodes_num = 2
            #    nodes_min = 1
            #    nodes_max = 16
            #    meta = {
            #        #zones = "1,2,3"
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
                # user_cacert = "/etc/ssl/certs/ca-certificates.crt"
                # user_java_cacert = "/etc/ssl/certs/java/cacerts"
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

#jarvice_k8s_scheduler:
  #ingressHost: tf-jarvice-downstream.my-domain.com

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
EOF
            }
        }
    },
}

