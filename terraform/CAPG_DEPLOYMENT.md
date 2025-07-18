# CAPG (Cluster API Provider for GCP) JARVICE Deployment Guide

## Overview

This document describes the complete CAPG implementation for deploying JARVICE using Cluster API Provider for GCP. The implementation creates a bootstrap cluster using kind, deploys a workload cluster using Cluster API, and then deploys the JARVICE helm chart to the workload cluster.

## Architecture

1. **Bootstrap Cluster**: A local kind cluster that hosts the Cluster API management components
2. **Workload Cluster**: A GCP-based Kubernetes cluster created via Cluster API
3. **JARVICE Deployment**: JARVICE helm chart deployed to the workload cluster

## Prerequisites

1. **GCP Project**: A GCP project with billing enabled
2. **Service Account**: A GCP service account with the following roles:
   - `roles/compute.admin`
   - `roles/container.admin`
   - `roles/iam.serviceAccountAdmin`
   - `roles/iam.securityAdmin`
3. **Tools**: The deployment will automatically install:
   - `kind` (for bootstrap cluster)
   - `kubectl` (for Kubernetes management)
   - `clusterctl` (for Cluster API management)
   - `helm` (for JARVICE deployment)

## Configuration

### 1. Update CAPG Configuration

Edit `tfvars/capg.tfvars` and update the following:

```hcl
capg = {
    capg_cluster_00 = {
        enabled = true

        auth = {
            project = "YOUR_GCP_PROJECT_ID"  # Replace with your GCP project ID
            service_account_key_file = "~/.config/gcloud/terraform-sa-key.json"  # Path to service account key
        }

        meta = {
            cluster_name = "tf-jarvice-capg"
            kubernetes_version = "v1.28.0"
            ssh_public_key = null  # Uses global setting
        }

        location = {
            region = "us-west1"
            zones = ["us-west1-a", "us-west1-b", "us-west1-c"]
        }

        # ... rest of configuration
    }
}
```

### 2. GCP Authentication

Choose one of the following authentication methods:

#### Option A: Service Account Key File
1. Create a service account in GCP Console
2. Download the JSON key file
3. Update the `service_account_key_file` path in `capg.tfvars`

#### Option B: Environment Variables
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
export GOOGLE_PROJECT="your-project-id"
export GOOGLE_REGION="us-west1"
```

#### Option C: gcloud Authentication
```bash
gcloud auth application-default login
```

## Deployment Process

### Step 1: Planning
```bash
./deploy.sh plan capg
```

This will:
- Generate the cluster configuration
- Validate the Terraform configuration
- Show the planned resources

### Step 2: Apply
```bash
./deploy.sh apply capg
```

This will execute the following workflow:

1. **Infrastructure Setup**:
   - Create GCP service account for CAPG
   - Assign necessary IAM roles
   - Enable required GCP APIs

2. **Bootstrap Cluster Creation**:
   - Install kind, kubectl, clusterctl if needed
   - Create kind cluster with CAPG credentials mounted
   - Initialize Cluster API with GCP provider

3. **Workload Cluster Creation**:
   - Generate workload cluster manifests
   - Apply cluster manifests to bootstrap cluster
   - Wait for workload cluster to become ready
   - Install CNI (Calico) on workload cluster

4. **JARVICE Deployment**:
   - Install helm if needed
   - Add JARVICE helm repository
   - Deploy JARVICE with CAPG-specific configuration
   - Install nginx-ingress and cert-manager

## What Gets Created

### Bootstrap Cluster (kind)
- Name: `{cluster_name}-management`
- Purpose: Hosts Cluster API controllers
- Location: Local Docker container

### Workload Cluster (GCP)
- Name: `{cluster_name}-workload`
- Purpose: Runs JARVICE workloads
- Components:
  - Control plane: 3 nodes (n1-standard-4)
  - Worker nodes: Configurable (default: 3 x n1-standard-4)
  - Network: Custom VPC with subnets
  - CNI: Calico

### JARVICE Components
- Namespace: `jarvice-system`
- Components:
  - JARVICE control plane
  - nginx-ingress controller
  - cert-manager
  - Storage classes for GCP persistent disks

## Accessing the Cluster

After deployment, cluster access files are available in `.tmp/`:

```bash
# Use workload cluster kubeconfig
export KUBECONFIG=.tmp/workload-kubeconfig.yaml

# Check cluster status
kubectl get nodes

# Check JARVICE status
kubectl get pods -n jarvice-system
```

## Monitoring Deployment

### Bootstrap Cluster
```bash
# Switch to management cluster
kubectl config use-context kind-{cluster_name}-management

# Check CAPG controller status
kubectl get pods -n capg-system

# Monitor workload cluster creation
kubectl get clusters,gcpclusters,machines
```

### Workload Cluster
```bash
# Use workload cluster kubeconfig
export KUBECONFIG=.tmp/workload-kubeconfig.yaml

# Check node status
kubectl get nodes

# Check JARVICE deployment
kubectl get pods -n jarvice-system
kubectl get svc -n jarvice-system
```

## Troubleshooting

### Common Issues

1. **GCP Authentication Errors**:
   - Verify service account has required permissions
   - Check credentials file path
   - Ensure GCP APIs are enabled

2. **Bootstrap Cluster Issues**:
   - Check Docker is running
   - Verify kind cluster creation: `kind get clusters`
   - Check CAPG controller logs: `kubectl logs -n capg-system deployment/capg-controller-manager`

3. **Workload Cluster Issues**:
   - Monitor cluster creation: `kubectl get clusters -w`
   - Check GCP quota limits
   - Verify network configuration

4. **JARVICE Deployment Issues**:
   - Check helm deployment: `helm list -n jarvice-system`
   - Monitor pod status: `kubectl get pods -n jarvice-system`
   - Check ingress configuration: `kubectl get ingress -n jarvice-system`

### Logs and Debugging

```bash
# CAPG controller logs
kubectl logs -n capg-system deployment/capg-controller-manager -f

# Cluster API logs
kubectl logs -n capi-system deployment/capi-controller-manager -f

# JARVICE logs
kubectl logs -n jarvice-system deployment/jarvice-api -f
```

## Cleanup

To destroy the entire deployment:

```bash
./deploy.sh destroy capg
```

This will:
1. Delete JARVICE from workload cluster
2. Delete workload cluster
3. Delete bootstrap cluster
4. Clean up GCP resources
5. Remove local temporary files

## Advanced Configuration

### Custom Cluster Configuration

The `cluster` section in `capg.tfvars` allows extensive customization:

```hcl
cluster = {
    project = "my-project-id"
    
    network = {
        name = "tf-jarvice-capg-network"
        create_network = true
        subnet_name = "tf-jarvice-capg-subnet"
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
```

### JARVICE Customization

Customize JARVICE deployment through the `helm` section:

```hcl
helm = {
    jarvice = {
        values_yaml = <<EOF
jarvice:
  JARVICE_CLUSTER_TYPE: upstream
  # Add custom JARVICE configuration here
EOF
    }
}
```

## Next Steps

After successful deployment:

1. Configure DNS for JARVICE ingress
2. Set up TLS certificates
3. Configure JARVICE applications
4. Set up monitoring and logging
5. Configure backup strategies

## Support

For issues specific to:
- **Cluster API**: Check [Cluster API documentation](https://cluster-api.sigs.k8s.io/)
- **CAPG**: Check [CAPG documentation](https://github.com/kubernetes-sigs/cluster-api-provider-gcp)
- **JARVICE**: Check JARVICE documentation and support channels
