#!/bin/bash

# CAPG Implementation Validation Script
# This script validates the CAPG module implementation

set -e

echo "=== JARVICE CAPG Implementation Validation ==="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "[${GREEN}PASS${NC}] $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "[${RED}FAIL${NC}] $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "[${YELLOW}WARN${NC}] $message"
    else
        echo -e "[INFO] $message"
    fi
}

# Change to terraform directory
cd "$(dirname "$0")"
if [ ! -f "terraform.tfvars" ]; then
    cd terraform
fi

# Check if we're in the right directory
if [ ! -f "terraform.tfvars" ]; then
    print_status "FAIL" "Cannot find terraform.tfvars. Please run from the correct directory."
    exit 1
fi

echo "1. Checking CAPG Module Structure..."

# Check if CAPG module directory exists
if [ -d "modules/capg" ]; then
    print_status "PASS" "CAPG module directory exists"
else
    print_status "FAIL" "CAPG module directory not found"
    exit 1
fi

# Check required files in CAPG module
required_files=(
    "modules/capg/main.tf"
    "modules/capg/variables.tf"
    "modules/capg/locals.tf"
    "modules/capg/deploy.tf"
    "modules/capg/outputs.tf"
    "modules/capg/README.md"
    "modules/capg/CAPG_IMPLEMENTATION.md"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "PASS" "Found $file"
    else
        print_status "FAIL" "Missing $file"
    fi
done

# Check manifest files
manifest_files=(
    "modules/capg/manifests/cluster.yaml"
    "modules/capg/manifests/gcp-cluster.yaml"
    "modules/capg/manifests/machinedeployment.yaml"
)

for file in "${manifest_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "PASS" "Found $file"
    else
        print_status "FAIL" "Missing $file"
    fi
done

echo ""
echo "2. Checking Root Module Integration..."

# Check if CAPG is integrated in main.tf
if grep -q "local.capg" main.tf; then
    print_status "PASS" "CAPG integrated in main.tf"
else
    print_status "FAIL" "CAPG not integrated in main.tf"
fi

# Check if CAPG variables are defined
if grep -q "variable \"capg\"" variables.tf; then
    print_status "PASS" "CAPG variables defined"
else
    print_status "FAIL" "CAPG variables not defined"
fi

# Check if CAPG locals are defined
if grep -q "capg = {" locals.tf; then
    print_status "PASS" "CAPG locals defined"
else
    print_status "FAIL" "CAPG locals not defined"
fi

# Check if kubectl provider is added
if grep -q "kubectl" main.tf; then
    print_status "PASS" "kubectl provider configured"
else
    print_status "FAIL" "kubectl provider not configured"
fi

echo ""
echo "3. Checking Configuration Examples..."

# Check if CAPG configuration exists in terraform.tfvars
if grep -q "capg = {" terraform.tfvars; then
    print_status "PASS" "CAPG configuration found in terraform.tfvars"
else
    print_status "FAIL" "CAPG configuration not found in terraform.tfvars"
fi

# Check if CAPG section header exists
if grep -q "Google Cloud CAPG clusters" terraform.tfvars; then
    print_status "PASS" "CAPG section header found"
else
    print_status "FAIL" "CAPG section header not found"
fi

echo ""
echo "4. Validating Terraform Syntax..."

# Check terraform syntax
if terraform validate > /dev/null 2>&1; then
    print_status "PASS" "Terraform configuration is valid"
else
    print_status "FAIL" "Terraform configuration has syntax errors"
    terraform validate
fi

echo ""
echo "5. Checking File Permissions..."

# Check if files have correct permissions
for file in modules/capg/*.tf; do
    if [ -r "$file" ]; then
        print_status "PASS" "File $file is readable"
    else
        print_status "FAIL" "File $file is not readable"
    fi
done

echo ""
echo "6. Checking Dependencies..."

# Check if required tools are available
tools=("terraform" "kubectl" "gcloud")
for tool in "${tools[@]}"; do
    if command -v "$tool" >/dev/null 2>&1; then
        print_status "PASS" "$tool is available"
    else
        print_status "WARN" "$tool is not available (required for deployment)"
    fi
done

echo ""
echo "7. Checking Module Compatibility..."

# Check if module structure matches other modules
if [ -d "modules/gkev2" ]; then
    gkev2_files=$(find modules/gkev2 -name "*.tf" | wc -l)
    capg_files=$(find modules/capg -name "*.tf" | wc -l)
    
    if [ "$capg_files" -ge "$gkev2_files" ]; then
        print_status "PASS" "CAPG module has comparable structure to GKE v2"
    else
        print_status "WARN" "CAPG module has fewer files than GKE v2 module"
    fi
else
    print_status "WARN" "GKE v2 module not found for comparison"
fi

echo ""
echo "8. Summary..."

# Count total checks
total_checks=0
passed_checks=0

# Re-run key checks for summary
checks=(
    "modules/capg directory exists"
    "All required .tf files exist"
    "Manifest files exist"
    "Integration in main.tf"
    "Variables defined"
    "Locals defined"
    "Configuration examples"
    "Terraform syntax valid"
)

for check in "${checks[@]}"; do
    total_checks=$((total_checks + 1))
    # This is a simplified check - in a real implementation,
    # we'd re-run the actual validation logic
    passed_checks=$((passed_checks + 1))
done

echo ""
print_status "INFO" "Validation complete!"
print_status "INFO" "Total checks: $total_checks"
print_status "INFO" "This validation script provides a basic check of the CAPG implementation."
print_status "INFO" "For full validation, run 'terraform plan' and 'terraform apply'."

echo ""
echo "=== Next Steps ==="
echo "1. Review the CAPG_IMPLEMENTATION.md documentation"
echo "2. Configure your GCP credentials and project settings"
echo "3. Update terraform.tfvars with your specific configuration"
echo "4. Run 'terraform init' to initialize the module"
echo "5. Run 'terraform plan' to review the deployment plan"
echo "6. Run 'terraform apply' to deploy the CAPG cluster"
echo ""
echo "For detailed documentation, see:"
echo "- modules/capg/README.md"
echo "- modules/capg/CAPG_IMPLEMENTATION.md"
echo ""
