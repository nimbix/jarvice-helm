# JARVICE Multi-Cloud Terraform Deployment Guide

## Overview

This guide covers deploying JARVICE using the refactored modular Terraform configuration with support for multiple cloud platforms including CAPG (Cluster API Provider for GCP).

## Prerequisites

### General Requirements
- Terraform >= 1.0
- kubectl
- Helm 3.x
- Git

### For CAPG Deployments
- Google Cloud SDK (gcloud) configured
- Google Cloud Project with required APIs enabled:
  - Compute Engine API
  - Kubernetes Engine API
  - Cloud Resource Manager API
  - Cluster API Provider GCP (CAPG) requires a management cluster

## Directory Structure

```
terraform/
├── deploy.sh                 # Main deployment script
├── variables.tf              # Root variable definitions
├── main.tf                   # Main configuration with templates
├── locals.tf                 # Local variable definitions
├── tfvars/                   # Platform-specific configuration
│   ├── global.tfvars         # Global settings
│   ├── capg.tfvars           # CAPG (Cluster API) clusters
│   ├── gkev2.tfvars          # GKE v2 clusters
│   ├── eksv2.tfvars          # EKS v2 clusters
│   ├── aks.tfvars            # AKS clusters
│   └── k8s.tfvars            # Generic Kubernetes clusters
└── modules/                  # Terraform modules
    ├── capg/                 # CAPG module
    ├── gkev2/                # GKE v2 module
    ├── common/               # Common utilities
    └── helm/                 # Helm deployment module
```

## Deployment Commands

### Basic Usage

```bash
# Plan deployment for specific platform
./deploy.sh plan <platform>

# Apply deployment for specific platform  
./deploy.sh apply <platform>

# Destroy deployment for specific platform
./deploy.sh destroy <platform>
```

### Supported Platforms
- `capg` - Cluster API Provider for GCP
- `gkev2` - Google Kubernetes Engine v2
- `eksv2` - Amazon Elastic Kubernetes Service v2
- `aks` - Azure Kubernetes Service
- `k8s` - Generic Kubernetes clusters

### Examples

```bash
# Deploy CAPG clusters
./deploy.sh apply capg

# Deploy GKE v2 clusters
./deploy.sh apply gkev2

# Plan EKS deployment
./deploy.sh plan eksv2

# Destroy AKS deployment
./deploy.sh destroy aks
```

## CAPG (Cluster API) Deployment

### Prerequisites for CAPG

1. **Management Cluster**: CAPG requires a management cluster where Cluster API controllers run
2. **Service Account**: GCP service account with required permissions
3. **APIs Enabled**: Required GCP APIs must be enabled

### CAPG Setup Process

1. **Create Management Cluster** (one-time setup):
   ```bash
   # Create a GKE cluster to serve as management cluster
   gcloud container clusters create capg-management \
     --zone=us-west1-a \
     --machine-type=n1-standard-4 \
     --num-nodes=3
   
   # Get credentials
   gcloud container clusters get-credentials capg-management --zone=us-west1-a
   ```

2. **Install Cluster API** (one-time setup):
   ```bash
   # Install clusterctl
   curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.6.0/clusterctl-linux-amd64 -o clusterctl
   chmod +x clusterctl
   sudo mv clusterctl /usr/local/bin/
   
   # Initialize Cluster API
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   export GOOGLE_PROJECT="your-project-id"
   clusterctl init --infrastructure gcp
   ```

3. **Configure Authentication**:
   Update `tfvars/capg.tfvars`:
   ```hcl
   capg = {
     capg_cluster_00 = {
       enabled = true
       auth = {
         project = "your-actual-project-id"
         service_account_key_file = "/path/to/your-service-account-key.json"
       }
       # ... rest of configuration
     }
   }
   ```

4. **Deploy CAPG Clusters**:
   ```bash
   ./deploy.sh apply capg
   ```

### CAPG Architecture

CAPG deployments create:
- **Bootstrap Cluster**: Management cluster running Cluster API controllers
- **Workload Clusters**: Target clusters where JARVICE will be deployed
- **Helm Deployments**: JARVICE Helm charts deployed to workload clusters

## Configuration Files

### Global Configuration (`tfvars/global.tfvars`)
Contains settings shared across all platforms:
- SSH keys
- Helm repository settings
- Global JARVICE configuration

### Platform-Specific Configuration
Each platform has its own tfvars file with platform-specific settings:
- Authentication credentials
- Cluster specifications
- Node pool configurations
- Platform-specific JARVICE settings

#### CAPG (Cluster API Provider for GCP)

CAPG provides a fully automated end-to-end deployment using Cluster API to create Kubernetes clusters on GCP.

**Features:**
- Automated bootstrap cluster creation using kind
- Workload cluster provisioning via Cluster API
- Automatic JARVICE deployment to workload cluster
- Complete lifecycle management

**Quick Start:**
```bash
# Configure GCP credentials and project in tfvars/capg.tfvars
./deploy.sh apply capg
```

**Detailed Guide:** See [CAPG_DEPLOYMENT.md](./CAPG_DEPLOYMENT.md) for complete setup instructions.

## Automation Features

### Auto-Initialization
The `deploy.sh` script automatically runs `terraform init` if needed.

### Platform Detection
The script automatically detects which tfvars files to use based on the platform parameter.

### Modular Deployment
Each platform can be deployed independently without affecting others.

## Troubleshooting

### Common Issues

1. **Terraform Init Required**:
   ```bash
   # The script handles this automatically, but you can run manually:
   terraform init
   ```

2. **Authentication Issues**:
   ```bash
   # For GCP:
   gcloud auth application-default login
   
   # For AWS:
   aws configure
   
   # For Azure:
   az login
   ```

3. **Module Not Found**:
   ```bash
   # Clean and reinitialize:
   rm -rf .terraform/
   terraform init
   ```

### CAPG-Specific Issues

1. **Management Cluster Not Ready**:
   ```bash
   # Check management cluster status:
   kubectl get nodes
   kubectl get pods -A
   ```

2. **Cluster API Controllers Not Running**:
   ```bash
   # Check Cluster API status:
   kubectl get pods -n capi-system
   kubectl get pods -n capg-system
   ```

3. **Workload Cluster Creation Stuck**:
   ```bash
   # Check cluster status:
   kubectl get clusters
   kubectl get machines
   kubectl describe cluster <cluster-name>
   ```

## Security Considerations

1. **Service Account Keys**: Store GCP service account keys securely and never commit to version control
2. **State Files**: Use remote state backends for production deployments
3. **Secrets**: Use proper secret management for sensitive configuration
4. **Network Security**: Configure appropriate firewall rules and network policies

## Next Steps

After successful deployment:

1. **Access JARVICE**: Use the provided ingress URLs to access the JARVICE portal
2. **Configure Applications**: Set up JARVICE applications and user accounts
3. **Monitor**: Set up monitoring and logging for the deployment
4. **Scale**: Adjust node pools and resources as needed

## Support

For issues and questions:
- Check the Terraform plan output for validation errors
- Review the deployment logs
- Consult the JARVICE documentation
- Check the Cluster API documentation for CAPG-specific issues
