# JARVICE Terraform Configuration - Modular Structure

This directory contains platform-specific Terraform variable files that have been extracted from the original monolithic `terraform.tfvars` file for better organization and maintainability.

## File Structure

- `global.tfvars` - Global settings shared across all cluster types
- `k8s.tfvars` - Configuration for pre-existing Kubernetes clusters
- `gkev2.tfvars` - Configuration for Google Cloud GKE v2 clusters
- `capg.tfvars` - Configuration for CAPG (Cluster API Provider for GCP) clusters
- `eksv2.tfvars` - Configuration for Amazon EKS v2 clusters
- `aks.tfvars` - Configuration for Azure AKS clusters

## Usage

To use these modular configuration files, you have several options:

### Option 1: Use specific platform files

Deploy only specific platforms by including the relevant tfvars files:

```bash
# Deploy global settings + GKE clusters
terraform plan -var-file="tfvars/global.tfvars" -var-file="tfvars/gkev2.tfvars"
terraform apply -var-file="tfvars/global.tfvars" -var-file="tfvars/gkev2.tfvars"

# Deploy global settings + EKS clusters
terraform plan -var-file="tfvars/global.tfvars" -var-file="tfvars/eksv2.tfvars"
terraform apply -var-file="tfvars/global.tfvars" -var-file="tfvars/eksv2.tfvars"

# Deploy global settings + AKS clusters
terraform plan -var-file="tfvars/global.tfvars" -var-file="tfvars/aks.tfvars"
terraform apply -var-file="tfvars/global.tfvars" -var-file="tfvars/aks.tfvars"
```

### Option 2: Use multiple platforms

Deploy multiple cloud providers simultaneously:

```bash
# Deploy GKE + EKS
terraform plan \
  -var-file="tfvars/global.tfvars" \
  -var-file="tfvars/gkev2.tfvars" \
  -var-file="tfvars/eksv2.tfvars"

terraform apply \
  -var-file="tfvars/global.tfvars" \
  -var-file="tfvars/gkev2.tfvars" \
  -var-file="tfvars/eksv2.tfvars"
```

### Option 3: Use all platforms

Deploy to all supported platforms:

```bash
terraform plan \
  -var-file="tfvars/global.tfvars" \
  -var-file="tfvars/k8s.tfvars" \
  -var-file="tfvars/gkev2.tfvars" \
  -var-file="tfvars/capg.tfvars" \
  -var-file="tfvars/eksv2.tfvars" \
  -var-file="tfvars/aks.tfvars"
```

### Option 4: Use the deployment script

Use the provided `deploy.sh` script for easier management:

```bash
# Deploy specific platforms
./deploy.sh plan gke eks
./deploy.sh apply gke eks

# Deploy all platforms
./deploy.sh plan all
./deploy.sh apply all
```

## Migration from Original terraform.tfvars

If you were previously using the monolithic `terraform.tfvars` file:

1. **Backup your configuration**: Make a copy of your current `terraform.tfvars`
2. **Update your commands**: Replace `-var-file="terraform.tfvars"` with the appropriate combination of the new tfvars files
3. **Enable desired platforms**: Set `enabled = true` in the relevant cluster configurations in each platform file
4. **Customize as needed**: Edit the platform-specific files to match your requirements

## Benefits of Modular Structure

- **Clarity**: Each platform's configuration is isolated and easier to understand
- **Maintainability**: Changes to one platform don't affect others
- **Selective deployment**: Deploy only the platforms you need
- **Reduced conflicts**: Multiple team members can work on different platforms simultaneously
- **Better organization**: Related configurations are grouped together

## Configuration Guidelines

1. Always include `global.tfvars` as it contains shared settings
2. Set `enabled = true` only for the clusters you want to deploy
3. Customize cluster names, regions, and other settings as needed
4. Review and update networking, storage, and security settings for your environment
5. Test with `terraform plan` before running `terraform apply`
