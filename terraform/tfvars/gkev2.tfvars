# Google Cloud GKE v2 clusters

gkev2 = {
    gkev2_cluster_00 = {
        enabled = false

        auth = {  # Optional, null values are replaced with gcloud CLI defaults
            project = null
            credentials = null  # Path to JSON service account key file
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.30"

            # Sync ingress hosts to zones/domains managed w/ Google Cloud DNS
            #dns_manage_records = "true"
            # Google Cloud project which contains the DNS zone for domain(s)
            #dns_zone_project = "tf-jarvice"  # If diff than cluster's project
            #Service account to be used for deployment if not defined it will be set to default.
            #service_account = "securityAccountName@projectName.iam.gserviceaccount.com"
            #KMS key to be used for disk encryption if not defined it will be created automatically.
            #kms_key = "projects/projectName/locations/us-central1/keyRings/keyRingName/cryptoKeys/keyName"
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
        kns_node_pools = {}
        #kns_node_pools = {
        #      jxecompute02 = {
        #          # n1 node_type is required for accelerator attachment
        #          nodes_type = "n1-standard-8"
        #          nodes_disk_size_gb = 100
        #          nodes_num = 0
        #          nodes_min = 0
        #          nodes_max = 16
        #          meta = {
        #              disable_hyperthreading = "true"
        #              disk_type = "pd-standard" # "pd-ssd" # "pd-balanced"
        #              #enable_gcfs = "true"
        #              #zones = "us-west1-a,us-west1-b,us-west1-c"
        #              # Visit the following link for GCP accelerator type specs:
        #              # https://cloud.google.com/compute/docs/gpus
        #              #accelerator_type = "nvidia-tesla-t4"
        #              #accelerator_count = 8
        #          }
        #      },
        #      jxecompute03 = {
        #          # n1 node_type is required for accelerator attachment
        #          nodes_type = "g2-standard-32"
        #          nodes_disk_size_gb = 200
        #          nodes_num = 0
        #          nodes_min = 0
        #          nodes_max = 16
        #          meta = {
        #              disable_hyperthreading = "true"
        #              disk_type = "pd-ssd" # "pd-standard" # "pd-balanced"
        #              #enable_gcfs = "true"
        #              zones = "us-west1-a,us-west1-b,us-west1-c"
        #
        #              # Visit the following link for GCP accelerator type specs:
        #              # https://cloud.google.com/compute/docs/gpus
        #              accelerator_type = "nvidia-l4"
        #              accelerator_count = 1
        #          }
        #      }          
        #  }
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
                values_file = "override-tf.gkev2.<region>.<cluster_name>.yaml"  # "override-tf.gkev2.us-west1.tf-jarvice.yaml"
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

jarvice_bird: # N/A if jarvice.JARVICE_CLUSTER_TYPE: "downstream"
  enabled: false
  conf:
    configMap: # jarvice-bird-config
  nginx:
    configMap: # jarvice-bird-nginx-config
  preset:
    configMap: # jarvice-bird-user-preset
  env:
    KEYCLOAK_URL: # keycloak.my-domain.com/auth
    JARVICE_KEYCLOAK_ADMIN_USER: nimbix
    JARVICE_KEYCLOAK_ADMIN_PASS: abc1234!
  ingressHost: # jarvice-bird.my-domain.com
  ingressPath: "/"  # Valid values are "/" (default) or "/bird"

keycloakx:
  enabled: false
  create_realm: false
  smtpServer:
    KEYCLOAK_SMTP_FROM:      # donotreply@example.com
    KEYCLOAK_SMTP_HOST:      # smtp.example.com
    KEYCLOAK_SMTP_PORT:      # 587
    KEYCLOAK_SMTP_START_TLS: # true
    KEYCLOAK_SMTP_AUTH:      # true
    KEYCLOAK_SMTP_USER:      # <user>@smtp.example.com
    KEYCLOAK_SMTP_PASSWORD:  # smtp password
  ingress:
    enabled: false
    annotations: {}
      # cert-manager.io/issuer: letsencrypt-staging
      # cert-manager.io/cluster-issuer: selfsigned
      ## Resolve HTTP 502 error using ingress-nginx:
      ## See https://www.ibm.com/support/pages/502-error-ingress-keycloak-response
      # nginx.ingress.kubernetes.io/proxy-buffer-size: 128k
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

    gkev2_cluster_01 = {
        enabled = false

        auth = {  # Optional, null values are replaced with gcloud CLI defaults
            project = null
            credentials = null  # Path to JSON service account key file
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.30"

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
                values_file = "override-tf.gkev2.<region>.<cluster_name>.yaml"  # "override-tf.gkev2.us-west1.tf-jarvice-downstream.yaml"
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
