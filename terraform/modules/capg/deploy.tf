# deploy.tf - CAPG module helm deployment for JARVICE

module "common" {
    source = "../common"

    global = var.global
    cluster = {
        enabled = var.enabled
        auth = var.auth
        meta = var.meta
        location = var.location
        system_node_pool = var.system_node_pool
        dockerbuild_node_pool = var.dockerbuild_node_pool
        compute_node_pools = var.compute_node_pools
        helm = var.helm
    }

    system_nodes_type_upstream = "n1-standard-8"
    system_nodes_type_downstream = "n1-standard-4"
    storage_class_provisioner = "pd.csi.storage.gke.io"
    storage_class_provisioner_dockerbuild = "pd.csi.storage.gke.io"
}

# Install helm on workload cluster and deploy JARVICE
resource "null_resource" "install_helm_and_jarvice" {
    provisioner "local-exec" {
        command = <<-EOF
            set -e
            
            export PATH="${path.root}/.tmp:$PATH"
            
            # Wait for workload cluster to be ready
            sleep 30
            
            # Check if helm is installed
            if ! command -v helm &> /dev/null; then
                echo "Installing helm..."
                curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
                mv /usr/local/bin/helm ${path.root}/.tmp/ || true
                export PATH="${path.root}/.tmp:$PATH"
            fi
            
            # Use workload cluster kubeconfig
            export KUBECONFIG="${path.root}/.tmp/workload-kubeconfig.yaml"
            
            # Create namespace for JARVICE
            kubectl create namespace jarvice-system --dry-run=client -o yaml | kubectl apply -f -
            
            # Add JARVICE helm repo
            helm repo add jarvice https://nimbix.github.io/jarvice-helm/
            helm repo update
            
            # Create values file for JARVICE
            cat > ${path.root}/.tmp/jarvice-values.yaml <<-EOY
# JARVICE CAPG values
jarvice:
  imagePullPolicy: Always
  JARVICE_CLUSTER_TYPE: upstream
  JARVICE_SYSTEM_NAMESPACE: jarvice-system
  
  # Use node selectors for system components
  daemonsets:
    lxcfs:
      nodeSelector:
        node-role.jarvice.io/jarvice-system: "true"
    rdma:
      enabled: false

  # Storage classes
  storageClass:
    create: true
    name: jarvice-default
    provisioner: pd.csi.storage.gke.io
    
  # Ingress configuration
  ingress:
    enabled: true
    class: nginx
    
  # Enable basic authentication
  auth:
    enabled: true
    
# Install nginx ingress controller
nginx-ingress:
  enabled: true
  controller:
    service:
      type: LoadBalancer
      annotations:
        cloud.google.com/load-balancer-type: "External"
        
# Enable cert-manager for TLS
cert-manager:
  enabled: true
  installCRDs: true
EOY
            
            # Install JARVICE using helm
            helm upgrade --install jarvice jarvice/jarvice \
                --namespace jarvice-system \
                --values ${path.root}/.tmp/jarvice-values.yaml \
                --timeout 20m \
                --wait
            
            echo "JARVICE deployed successfully to workload cluster"
        EOF
    }
    
    depends_on = [
        null_resource.create_workload_cluster,
        data.external.workload_cluster_info
    ]
}
