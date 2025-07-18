# main.tf - CAPG (Cluster API Provider GCP) module

terraform {
    required_providers {
        google = "~> 4.66.0"
        helm = "~> 2.4"
        kubernetes = "~> 2.6"
        null = "~> 3.1"
        local = "~> 2.1"
        random = "~> 3.1"
        external = "~> 2.3"
    }
}

data "google_project" "jarvice" {
}

locals {
    project = trimprefix(data.google_project.jarvice.id, "projects/")
    region = var.location.region
    zones = var.location.zones
    
    # Cluster API naming conventions
    cluster_name = var.meta["cluster_name"]
    management_cluster_name = "${local.cluster_name}-management"
    workload_cluster_name = "${local.cluster_name}-workload"
    namespace = "default"
    
    # GCP credentials for Cluster API
    credentials_json = base64decode(google_service_account_key.capg_manager.private_key)
    
    project_services = [
        "compute.googleapis.com",
        "container.googleapis.com",
        "iam.googleapis.com",
        "cloudresourcemanager.googleapis.com"
    ]
}

resource "google_project_service" "project_services" {
    for_each = toset(local.project_services)

    service = each.value
    disable_dependent_services = false
    disable_on_destroy = false
}

# Create a GCP Service Account for the Cluster API management
resource "google_service_account" "capg_manager" {
    account_id   = "${substr(local.cluster_name, 0, 20)}-capg"
    display_name = "Cluster API GCP Manager for ${local.cluster_name}"
    project      = local.project
}

resource "google_service_account_key" "capg_manager" {
    service_account_id = google_service_account.capg_manager.name
}

# Assign necessary roles to the service account
resource "google_project_iam_member" "capg_manager_compute_admin" {
    project = local.project
    role    = "roles/compute.admin"
    member  = "serviceAccount:${google_service_account.capg_manager.email}"
}

resource "google_project_iam_member" "capg_manager_container_admin" {
    project = local.project
    role    = "roles/container.admin"
    member  = "serviceAccount:${google_service_account.capg_manager.email}"
}

resource "google_project_iam_member" "capg_manager_iam_admin" {
    project = local.project
    role    = "roles/iam.serviceAccountAdmin"
    member  = "serviceAccount:${google_service_account.capg_manager.email}"
}

resource "google_project_iam_member" "capg_manager_security_admin" {
    project = local.project
    role    = "roles/iam.securityAdmin"
    member  = "serviceAccount:${google_service_account.capg_manager.email}"
}

# Create the GCP credentials file
resource "local_file" "gcp_credentials" {
    content  = base64decode(google_service_account_key.capg_manager.private_key)
    filename = "${path.root}/.tmp/gcp-credentials.json"
    
    depends_on = [google_service_account_key.capg_manager]
}

# Create bootstrap cluster using kind
resource "null_resource" "create_bootstrap_cluster" {
    provisioner "local-exec" {
        command = <<-EOF
            set -e
            
            # Create temporary directory
            mkdir -p ${path.root}/.tmp
            
            # Check if kind is installed
            if ! command -v kind &> /dev/null; then
                echo "Installing kind..."
                curl -Lo ${path.root}/.tmp/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
                chmod +x ${path.root}/.tmp/kind
                export PATH="${path.root}/.tmp:$PATH"
            fi
            
            # Check if kubectl is installed
            if ! command -v kubectl &> /dev/null; then
                echo "Installing kubectl..."
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                mv kubectl ${path.root}/.tmp/
                export PATH="${path.root}/.tmp:$PATH"
            fi
            
            # Check if clusterctl is installed
            if ! command -v clusterctl &> /dev/null; then
                echo "Installing clusterctl..."
                curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.5.0/clusterctl-linux-amd64 -o ${path.root}/.tmp/clusterctl
                chmod +x ${path.root}/.tmp/clusterctl
                export PATH="${path.root}/.tmp:$PATH"
            fi
            
            # Create kind cluster configuration
            cat > ${path.root}/.tmp/kind-cluster-config.yaml <<-EOC
apiVersion: kind.x-k8s.io/v1alpha4
kind: Cluster
nodes:
- role: control-plane
  extraMounts:
  - hostPath: ${path.root}/.tmp/gcp-credentials.json
    containerPath: /etc/capg/service-account.json
    readOnly: true
EOC
            
            # Create kind cluster
            kind create cluster --name ${local.management_cluster_name} --config ${path.root}/.tmp/kind-cluster-config.yaml || true
            
            # Wait for cluster to be ready
            kubectl --kubeconfig ~/.kube/config wait --for=condition=Ready nodes --all --timeout=300s
            
            echo "Bootstrap cluster created successfully"
        EOF
    }
    
    depends_on = [local_file.gcp_credentials]
}

# Initialize Cluster API
resource "null_resource" "init_cluster_api" {
    provisioner "local-exec" {
        command = <<-EOF
            set -e
            
            export PATH="${path.root}/.tmp:$PATH"
            export GOOGLE_APPLICATION_CREDENTIALS="${path.root}/.tmp/gcp-credentials.json"
            
            # Set kubeconfig to kind cluster
            kubectl config use-context kind-${local.management_cluster_name}
            
            # Initialize Cluster API with CAPG provider
            clusterctl init --infrastructure gcp --wait-providers
            
            # Wait for CAPG to be ready
            kubectl wait --for=condition=Available deployment/capg-controller-manager -n capg-system --timeout=300s
            
            echo "Cluster API initialized successfully"
        EOF
    }
    
    depends_on = [null_resource.create_bootstrap_cluster]
}

# Create workload cluster manifests
resource "local_file" "workload_cluster_manifests" {
    content = templatefile("${path.module}/templates/workload-cluster.yaml.tpl", {
        cluster_name = local.workload_cluster_name
        namespace = local.namespace
        project_id = local.project
        region = local.region
        zones = local.zones
        kubernetes_version = var.meta["kubernetes_version"]
        control_plane_machine_type = lookup(var.cluster.control_plane, "machine_type", "n1-standard-4")
        control_plane_disk_size = lookup(var.cluster.control_plane, "disk_size_gb", 100)
        control_plane_image = lookup(var.cluster.control_plane, "image", "ubuntu-2204-jammy-v20231213")
        worker_machine_type = lookup(var.cluster.node_pools.system, "machine_type", "n1-standard-4")
        worker_disk_size = lookup(var.cluster.node_pools.system, "disk_size_gb", 100)
        worker_image = lookup(var.cluster.node_pools.system, "image", "ubuntu-2204-jammy-v20231213")
        worker_replicas = lookup(var.cluster.node_pools.system, "replicas", 3)
        network_name = lookup(var.cluster.network, "name", "tf-jarvice-capg-network")
        subnet_name = lookup(var.cluster.network, "subnet_name", "tf-jarvice-capg-subnet")
        subnet_cidr = lookup(var.cluster.network, "subnet_cidr", "10.0.0.0/16")
        pod_cidr = lookup(var.cluster.network, "pod_cidr", "192.168.0.0/16")
        service_cidr = lookup(var.cluster.network, "service_cidr", "10.96.0.0/12")
    })
    filename = "${path.root}/.tmp/workload-cluster.yaml"
    
    depends_on = [null_resource.init_cluster_api]
}

# Apply workload cluster manifests
resource "null_resource" "create_workload_cluster" {
    provisioner "local-exec" {
        command = <<-EOF
            set -e
            
            export PATH="${path.root}/.tmp:$PATH"
            export GOOGLE_APPLICATION_CREDENTIALS="${path.root}/.tmp/gcp-credentials.json"
            
            # Set kubeconfig to kind cluster
            kubectl config use-context kind-${local.management_cluster_name}
            
            # Apply workload cluster manifests
            kubectl apply -f ${path.root}/.tmp/workload-cluster.yaml
            
            # Wait for cluster to be ready
            kubectl wait --for=condition=Ready cluster ${local.workload_cluster_name} -n ${local.namespace} --timeout=1200s
            
            # Get workload cluster kubeconfig
            clusterctl get kubeconfig ${local.workload_cluster_name} -n ${local.namespace} > ${path.root}/.tmp/workload-kubeconfig.yaml
            
            # Install CNI on workload cluster
            kubectl --kubeconfig ${path.root}/.tmp/workload-kubeconfig.yaml apply -f https://docs.projectcalico.org/manifests/calico.yaml
            
            # Wait for nodes to be ready
            kubectl --kubeconfig ${path.root}/.tmp/workload-kubeconfig.yaml wait --for=condition=Ready nodes --all --timeout=600s
            
            echo "Workload cluster created successfully"
        EOF
    }
    
    depends_on = [local_file.workload_cluster_manifests]
}

# Extract workload cluster info
data "external" "workload_cluster_info" {
    program = ["bash", "-c", <<-EOF
        set -e
        export PATH="${path.root}/.tmp:$PATH"
        
        if [[ -f "${path.root}/.tmp/workload-kubeconfig.yaml" ]]; then
            ENDPOINT=$(kubectl --kubeconfig ${path.root}/.tmp/workload-kubeconfig.yaml config view --minify -o jsonpath='{.clusters[0].cluster.server}')
            CA_CERT=$(kubectl --kubeconfig ${path.root}/.tmp/workload-kubeconfig.yaml config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
            TOKEN=$(kubectl --kubeconfig ${path.root}/.tmp/workload-kubeconfig.yaml create token default --duration=24h 2>/dev/null || echo "")
            
            jq -n --arg endpoint "$ENDPOINT" --arg ca_cert "$CA_CERT" --arg token "$TOKEN" \
                '{endpoint: $endpoint, ca_certificate: $ca_cert, token: $token}'
        else
            jq -n '{endpoint: "", ca_certificate: "", token: ""}'
        fi
    EOF
    ]
    
    depends_on = [null_resource.create_workload_cluster]
}
