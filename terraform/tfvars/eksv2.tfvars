# Amazon EKS v2 clusters

eksv2 = {
    eksv2_cluster_00 = {
        enabled = false

        auth = {  # Optional, null values are replaced with aws CLI defaults
            access_key = null
            secret_key = null
        }

        meta = {
            cluster_name = "tf-jarvice"
            kubernetes_version = "1.24"
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
                    #Indicate whether the node pool should have a GPU capable AWS ami by setting the number of GPU's present.
                    #gpu = "1"
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

    eksv2_cluster_01 = {
        enabled = false

        auth = {  # Optional, null values are replaced with aws CLI defaults
            access_key = null
            secret_key = null
        }

        meta = {
            cluster_name = "tf-jarvice-downstream"
            kubernetes_version = "1.30"
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
