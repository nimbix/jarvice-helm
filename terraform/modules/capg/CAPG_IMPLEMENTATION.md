# JARVICE CAPG (Cluster API Provider for GCP) Implementation

## Overview

This implementation provides a complete Terraform module for deploying JARVICE on Google Cloud Platform using Cluster API Provider for GCP (CAPG) instead of the native GKE provider. The CAPG module duplicates all the functionality of the existing GKE modules while leveraging the Cluster API for infrastructure management.

## Architecture

The CAPG implementation consists of the following components:

### 1. Terraform Module (`/terraform/modules/capg/`)
- **main.tf**: Core infrastructure and Cluster API resource definitions
- **variables.tf**: Input variables matching GKE module structure
- **locals.tf**: Local values and cluster configuration
- **deploy.tf**: JARVICE deployment and add-on configurations
- **outputs.tf**: Module outputs for cluster information
- **README.md**: Module-specific documentation

### 2. Cluster API Manifests (`/terraform/modules/capg/manifests/`)
- **cluster.yaml**: Cluster API Cluster and GCPManagedControlPlane
- **gcp-cluster.yaml**: GCPCluster infrastructure configuration
- **machinedeployment.yaml**: MachineDeployment and node pool definitions

### 3. Root Module Integration
- **main.tf**: Added CAPG provider and module configurations
- **variables.tf**: Added CAPG variable definitions
- **locals.tf**: Added CAPG local value processing
- **terraform.tfvars**: Added comprehensive CAPG configuration examples

## Key Features

### Infrastructure Management
- **Cluster API Integration**: Uses Cluster API for standardized Kubernetes cluster management
- **GCP Service Account**: Automated service account creation with proper IAM roles
- **Network Management**: Configurable VPC, subnets, and firewall rules
- **Multi-zone Deployment**: Support for multi-zone cluster deployment

### Node Pool Management
- **System Node Pool**: Dedicated nodes for system workloads
- **Compute Node Pools**: Scalable compute nodes for JARVICE workloads
- **GPU Support**: NVIDIA GPU node pools with driver installation
- **Autoscaling**: Horizontal Pod Autoscaler and Cluster Autoscaler support

### Security Features
- **Workload Identity**: GCP Workload Identity integration
- **Network Policies**: Kubernetes network policy support
- **RBAC**: Role-based access control
- **Pod Security Policies**: Optional pod security policy enforcement

### Add-on Support
- **CNI Providers**: Calico, Flannel, and Weave Net support
- **Cert Manager**: Automated certificate management
- **NVIDIA GPU Operator**: GPU driver and runtime installation
- **MetalLB**: Load balancer for on-premise deployments
- **DNS**: CoreDNS configuration

### JARVICE Integration
- **Helm Chart Deployment**: Automated JARVICE helm chart installation
- **Ingress Configuration**: Automated ingress and TLS setup
- **License Manager**: Optional license manager deployment
- **Bird Integration**: Portal and scheduler integration
- **Multi-tenancy**: Support for upstream and downstream clusters

## Configuration

### Basic Configuration Example

```hcl
capg = {
    capg_cluster_00 = {
        enabled = true

        auth = {
            service_account_key_file = "~/.config/gcloud/terraform-sa-key.json"
        }

        cluster = {
            name = "tf-jarvice-capg"
            project = "my-project-id"
            region = "us-west1"
            
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
                kubernetes_version = "v1.28.0"
            }

            node_pools = {
                system = {
                    machine_type = "n1-standard-4"
                    replicas = 3
                    enable_autoscaling = true
                    min_replicas = 1
                    max_replicas = 10
                }
            }

            domain_name = "my-domain.com"
            subdomain = "tf-jarvice-capg"
        }

        helm = {
            jarvice = {
                namespace = "jarvice-system"
                values_yaml = <<EOF
jarvice:
  JARVICE_CLUSTER_TYPE: "upstream"
  # Additional JARVICE configuration...
EOF
            }
        }
    }
}
```

### Advanced Configuration

The module supports advanced features including:

- **Custom Machine Types**: Configure specific machine types for different workloads
- **Spot Instances**: Enable preemptible instances for cost optimization
- **Custom Labels and Taints**: Node labeling and tainting for workload placement
- **Network Policies**: Advanced network security configurations
- **Backup Configuration**: Automated etcd backup and disaster recovery
- **Monitoring Integration**: Prometheus and Grafana integration

## Deployment

### Prerequisites

1. **Terraform**: Version ~> 1.0
2. **kubectl**: Latest version
3. **gcloud CLI**: Configured with appropriate credentials
4. **Cluster API Management Cluster**: Either Kind or existing cluster

### Installation Steps

1. **Configure Authentication**:
   ```bash
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   export GOOGLE_PROJECT="my-project-id"
   export GOOGLE_REGION="us-west1"
   ```

2. **Initialize Terraform**:
   ```bash
   cd terraform
   terraform init
   ```

3. **Plan Deployment**:
   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

4. **Apply Configuration**:
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

### Management Cluster Setup

For standalone deployments, you can use Kind to create a management cluster:

```bash
# Create management cluster
kind create cluster --name capg-management

# Install Cluster API components
clusterctl init --infrastructure gcp
```

## Comparison with GKE Module

| Feature | GKE Module | CAPG Module |
|---------|------------|-------------|
| **Infrastructure Provider** | Google Cloud GKE | Cluster API + GCP |
| **Cluster Management** | GKE API | Cluster API |
| **Node Pool Management** | GKE Node Pools | MachineDeployments |
| **Networking** | GKE VPC-native | Custom VPC + CNI |
| **Security** | GKE Security | Cluster API + Custom |
| **Monitoring** | GKE Monitoring | Custom + Prometheus |
| **Updates** | GKE Auto-update | Manual/Automated |
| **Portability** | GCP-specific | Multi-cloud capable |

## Migration Guide

### From GKE to CAPG

1. **Export existing configuration**:
   ```bash
   terraform show -json > gke-state.json
   ```

2. **Create CAPG configuration** based on existing GKE settings

3. **Deploy CAPG cluster** with similar configuration

4. **Migrate workloads** using standard Kubernetes tools

5. **Validate functionality** and performance

6. **Decommission GKE cluster** after successful migration

## Troubleshooting

### Common Issues

1. **Cluster API Bootstrap Issues**:
   - Ensure management cluster has Cluster API installed
   - Check CAPG provider installation
   - Verify GCP credentials and permissions

2. **Node Pool Creation Failures**:
   - Check machine type availability in region
   - Verify quota limits
   - Review subnet and networking configuration

3. **JARVICE Deployment Issues**:
   - Verify ingress controller installation
   - Check DNS configuration
   - Review service account permissions

### Debug Commands

```bash
# Check Cluster API resources
kubectl get clusters,machines,machinepools -A

# Check CAPG provider logs
kubectl logs -n capg-system -l control-plane=capg-controller-manager

# Check node status
kubectl get nodes -o wide

# Check JARVICE deployment
kubectl get pods -n jarvice-system
```

## Best Practices

### Security
- Use dedicated service accounts with minimal permissions
- Enable Workload Identity for pod-level authentication
- Implement network policies for traffic segmentation
- Regular security updates and patches

### Performance
- Use appropriate machine types for workloads
- Enable autoscaling for dynamic resource management
- Implement resource requests and limits
- Monitor resource utilization

### Cost Optimization
- Use spot instances for non-critical workloads
- Implement cluster autoscaling
- Regular cleanup of unused resources
- Monitor and optimize resource usage

### Monitoring
- Deploy monitoring stack (Prometheus, Grafana)
- Set up alerting for critical metrics
- Monitor cluster and workload health
- Regular backup and disaster recovery testing

## Contributing

When contributing to the CAPG module:

1. Follow existing code style and patterns
2. Update documentation for new features
3. Add appropriate variable validation
4. Include examples in terraform.tfvars
5. Test with multiple configurations
6. Update version compatibility information

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review Cluster API documentation
3. Check JARVICE documentation
4. Open GitHub issues for bugs
5. Contribute improvements via pull requests

## Version Compatibility

| Component | Version |
|-----------|---------|
| Terraform | ~> 1.0 |
| Cluster API | v1.5.0+ |
| CAPG | v1.5.0+ |
| Kubernetes | v1.28.0+ |
| JARVICE | 3.0.0+ |

## Future Enhancements

Planned improvements include:

1. **Multi-cluster Management**: Support for cluster federation
2. **Advanced Networking**: Service mesh integration
3. **Enhanced Security**: OPA Gatekeeper integration
4. **GitOps Integration**: ArgoCD and Flux support
5. **Observability**: Enhanced monitoring and logging
6. **Disaster Recovery**: Automated backup and restore
