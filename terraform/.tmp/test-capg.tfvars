# Test CAPG configuration with mock credentials

capg = {
    test_cluster = {
        enabled = true

        auth = {
            project = "test-project-id"
            service_account_key_file = ".tmp/mock-gcp-credentials.json"
        }

        meta = {
            cluster_name = "test-jarvice-capg"
            kubernetes_version = "v1.28.0"
            ssh_public_key = null
        }

        location = {
            region = "us-central1"
            zones = ["us-central1-a", "us-central1-b", "us-central1-c"]
        }

        system_node_pool = {
            nodes_type = "n1-standard-4"
            nodes_num = 3
        }

        dockerbuild_node_pool = {
            nodes_type = "c2-standard-4"
            nodes_num = 1
            nodes_min = 0
            nodes_max = 5
        }

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
                }
            }
        }

        cluster = {
            project = "test-project-id"
            
            network = {
                name = "test-jarvice-capg-network"
                create_network = true
                subnet_name = "test-jarvice-capg-subnet"
                subnet_cidr = "10.0.0.0/16"
                pod_cidr = "192.168.0.0/16"
                service_cidr = "10.96.0.0/12"
            }

            control_plane = {
                machine_type = "n1-standard-4"
                disk_size_gb = 100
                image = "ubuntu-2204-jammy-v20231213"
                kubernetes_version = "v1.28.0"
            }

            node_pools = {
                system = {
                    machine_type = "n1-standard-4"
                    disk_size_gb = 100
                    replicas = 3
                    min_replicas = 1
                    max_replicas = 10
                    enable_autoscaling = true
                }
            }
        }

        helm = {
            jarvice = {
                values_yaml = <<EOY
# Test JARVICE values
jarvice:
  JARVICE_CLUSTER_TYPE: upstream
  imagePullPolicy: Always
EOY
            }
        }
    }
}
