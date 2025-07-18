# CAPG (Cluster API Provider GCP) Module

This module deploys JARVICE using Cluster API Provider GCP (CAPG) instead of the native Google Cloud provider. It duplicates the functionality of the existing GKE modules but uses Cluster API for infrastructure management.

## Features

- **Cluster API Management**: Uses Cluster API for declarative cluster lifecycle management
- **GCP Integration**: Fully integrated with Google Cloud Platform services
- **Node Pool Management**: Supports multiple node pool types (system, compute, dockerbuild, images-pull, KNS, vcluster)
- **GPU Support**: Automatic NVIDIA GPU driver installation for accelerated workloads
- **Autoscaling**: Built-in cluster autoscaling with configurable min/max replicas
- **Security**: Shielded nodes and service account integration
- **Monitoring**: Health checks and machine health monitoring
- **DNS Integration**: Optional external DNS management
- **Certificate Management**: Automatic certificate management with cert-manager

## Architecture

The module creates the following Cluster API resources:

1. **Cluster**: Main cluster resource that defines the cluster specification
2. **GCPCluster**: Infrastructure provider resource for GCP-specific configuration
3. **GCPManagedControlPlane**: Managed control plane configuration
4. **MachineDeployment**: Worker node pool definitions
5. **GCPMachineTemplate**: Machine template specifications for node pools
6. **KubeadmConfigTemplate**: Bootstrap configuration for worker nodes

## Node Pool Types

- **System**: Runs JARVICE system components (DAL, scheduler, portal, etc.)
- **Compute**: Runs JARVICE user workloads and jobs
- **Dockerbuild**: Dedicated nodes for container image building
- **Images-pull**: Specialized nodes for image pulling with GCFS
- **KNS**: Kubernetes Native Scheduler nodes
- **VCluster**: Virtual cluster nodes

## Prerequisites

1. **Cluster API Management Cluster**: A Kubernetes cluster with Cluster API installed
2. **CAPG Provider**: cluster-api-provider-gcp must be installed in the management cluster
3. **Google Cloud Credentials**: Service account with necessary permissions
4. **kubectl**: Configured to access the management cluster

## Installation

### 1. Install Cluster API on Management Cluster

```bash
# Install clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.6.0/clusterctl-linux-amd64 -o clusterctl
chmod +x clusterctl
sudo mv clusterctl /usr/local/bin/clusterctl

# Initialize Cluster API
clusterctl init --infrastructure gcp
```

### 2. Configure GCP Credentials

```bash
# Set environment variables
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"

# Create secret for CAPG
kubectl create secret generic capg-manager-bootstrap-credentials \
  --from-file=credentials.json=${GOOGLE_APPLICATION_CREDENTIALS} \
  --namespace=capg-system
```

### 3. Deploy JARVICE with CAPG

```hcl
module "capg_cluster" {
  source = "./modules/capg"
  
  global = var.global
  cluster = var.capg_cluster_config
}
```

## Configuration

### Basic Configuration

```hcl
capg = {
  capg_cluster_00 = {
    enabled = true
    
    auth = {
      project = "your-gcp-project"
      credentials = "/path/to/service-account.json"
    }
    
    meta = {
      cluster_name = "jarvice-capg"
      kubernetes_version = "1.28"
      dns_manage_records = true
      dns_zone_project = "your-dns-project"
    }
    
    location = {
      region = "us-central1"
      zones = ["us-central1-a", "us-central1-b", "us-central1-c"]
    }
    
    compute_node_pools = {
      jxecompute00 = {
        nodes_type = "n1-standard-4"
        nodes_disk_size_gb = 100
        nodes_num = 1
        nodes_min = 0
        nodes_max = 10
        meta = {
          disk_type = "pd-ssd"
          accelerator_type = "nvidia-tesla-t4"
          accelerator_count = 1
          enable_gcfs = "true"
        }
      }
    }
    
    dockerbuild_node_pool = {
      nodes_type = "n1-standard-2"
      nodes_num = 1
      nodes_min = 0
      nodes_max = 3
    }
    
    helm = {
      jarvice = {
        values_file = "override.yaml"
        namespace = "jarvice-system"
        chart_version = "3.0.0-1.202X.XX.XX"
        chart_ref = "jarvice"
        chart_set = []
      }
    }
  }
}
```

### Advanced Configuration

#### GPU Acceleration

```hcl
compute_node_pools = {
  gpu_pool = {
    nodes_type = "n1-standard-4"
    nodes_disk_size_gb = 100
    nodes_num = 0
    nodes_min = 0
    nodes_max = 5
    meta = {
      accelerator_type = "nvidia-tesla-v100"
      accelerator_count = 1
      enable_gcfs = "true"
      disk_type = "pd-ssd"
    }
  }
}
```

#### Multi-Zone Configuration

```hcl
compute_node_pools = {
  zone_a_pool = {
    nodes_type = "n1-standard-4"
    nodes_disk_size_gb = 100
    nodes_num = 1
    nodes_min = 0
    nodes_max = 5
    meta = {
      zones = "us-central1-a"
      disk_type = "pd-standard"
    }
  }
  zone_b_pool = {
    nodes_type = "n1-standard-4"
    nodes_disk_size_gb = 100
    nodes_num = 1
    nodes_min = 0
    nodes_max = 5
    meta = {
      zones = "us-central1-b"
      disk_type = "pd-standard"
    }
  }
}
```

## Outputs

The module provides the following outputs:

- `cluster_info`: Complete cluster information
- `kube_config`: Kubernetes configuration for cluster access
- `load_balancer_ip`: External IP address for ingress
- `ingress_host`: Hostname for JARVICE services
- `service_account_email`: Email of the CAPG service account
- `helm_charts`: Information about deployed Helm charts

## Monitoring and Troubleshooting

### Check Cluster Status

```bash
# Check cluster resources
kubectl get clusters,gcpclusters,gcpmanagedcontrolplanes

# Check machine deployments
kubectl get machinedeployments,machines

# Check node status
kubectl get nodes
```

### View Logs

```bash
# CAPG controller logs
kubectl logs -n capg-system deployment/capg-controller-manager

# Machine deployment logs
kubectl describe machinedeployment <deployment-name>

# Individual machine logs
kubectl describe machine <machine-name>
```

### Common Issues

1. **Cluster Not Provisioning**: Check CAPG controller logs and GCP service account permissions
2. **Node Not Joining**: Verify network connectivity and firewall rules
3. **GPU Driver Issues**: Check node logs for NVIDIA driver installation status
4. **Autoscaling Not Working**: Verify MachineAutoscaler configuration and resource requests

## Differences from GKE Modules

| Feature | GKE Module | CAPG Module |
|---------|------------|-------------|
| **Management** | Native GCP resources | Cluster API resources |
| **Control Plane** | GKE managed | GKE managed via CAPG |
| **Node Pools** | GKE node pools | Machine deployments |
| **Scaling** | GKE autoscaling | Cluster API autoscaling |
| **Lifecycle** | Terraform only | Cluster API + Terraform |
| **Declarative** | Partial | Full |
| **Multi-Cloud** | GCP only | Extensible to other providers |

## Migration from GKE

To migrate from existing GKE modules to CAPG:

1. **Backup**: Export existing cluster configuration and data
2. **Plan**: Review node pool configurations and requirements
3. **Deploy**: Create new CAPG cluster with equivalent configuration
4. **Migrate**: Move workloads from GKE to CAPG cluster
5. **Validate**: Verify all services are working correctly
6. **Cleanup**: Remove old GKE resources

## Security Considerations

- **Service Account**: Uses dedicated service account with minimal required permissions
- **Network Security**: Supports VPC-native networking and network policies
- **Secrets Management**: Service account keys are stored as Kubernetes secrets
- **Shielded Nodes**: Enabled by default for enhanced security
- **Encryption**: Supports disk encryption with customer-managed keys

## Performance Considerations

- **Node Sizing**: Choose appropriate machine types for workload requirements
- **Disk Types**: Use SSD disks for better I/O performance
- **Network**: Consider regional persistent disks for multi-zone deployments
- **Autoscaling**: Configure appropriate scaling parameters to avoid resource waste

## Contributing

When contributing to this module:

1. Follow existing code patterns and conventions
2. Update manifest templates for new features
3. Add appropriate labels and annotations
4. Include health checks and monitoring
5. Update documentation and examples
6. Test with different node pool configurations

## References

- [Cluster API Documentation](https://cluster-api.sigs.k8s.io/)
- [CAPG Provider Documentation](https://github.com/kubernetes-sigs/cluster-api-provider-gcp)
- [GCP Machine Types](https://cloud.google.com/compute/docs/machine-types)
- [Kubernetes Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- [JARVICE Documentation](https://jarvice.readthedocs.io/)
