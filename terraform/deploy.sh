#!/bin/bash

# JARVICE Terraform Deployment Script
# This script simplifies the deployment of JARVICE using the modular tfvars structure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TFVARS_DIR="${SCRIPT_DIR}/tfvars"

# Available platforms
PLATFORMS=("k8s" "gkev2" "capg" "eksv2" "aks")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo -e "${BLUE}JARVICE Terraform Deployment Script${NC}"
    echo ""
    echo "Usage: $0 <command> <platforms...>"
    echo ""
    echo "Commands:"
    echo "  plan     - Run terraform plan"
    echo "  apply    - Run terraform apply"
    echo "  destroy  - Run terraform destroy"
    echo "  init     - Run terraform init"
    echo "  validate - Run terraform validate"
    echo ""
    echo "Platforms:"
    echo "  k8s      - Pre-existing Kubernetes clusters"
    echo "  gkev2    - Google Cloud GKE v2 clusters"
    echo "  capg     - CAPG (Cluster API Provider for GCP) clusters"
    echo "  eksv2    - Amazon EKS v2 clusters"
    echo "  aks      - Azure AKS clusters"
    echo "  all      - All platforms"
    echo ""
    echo "Examples:"
    echo "  $0 plan gkev2                    # Plan deployment for GKE only"
    echo "  $0 apply gkev2 eksv2             # Apply deployment for GKE and EKS"
    echo "  $0 plan all                      # Plan deployment for all platforms"
    echo "  $0 destroy aks                   # Destroy AKS resources"
    echo ""
    echo "Notes:"
    echo "  - Global settings are always included"
    echo "  - Make sure to enable clusters in the respective tfvars files"
    echo "  - Run 'terraform init' first if this is a new workspace"
}

validate_platform() {
    local platform=$1
    if [[ "$platform" == "all" ]]; then
        return 0
    fi
    
    for valid_platform in "${PLATFORMS[@]}"; do
        if [[ "$platform" == "$valid_platform" ]]; then
            return 0
        fi
    done
    return 1
}

build_var_files() {
    local platforms=("$@")
    local var_files=("-var-file=${TFVARS_DIR}/global.tfvars")
    
    if [[ "${platforms[0]}" == "all" ]]; then
        for platform in "${PLATFORMS[@]}"; do
            var_files+=("-var-file=${TFVARS_DIR}/${platform}.tfvars")
        done
    else
        for platform in "${platforms[@]}"; do
            if validate_platform "$platform"; then
                var_files+=("-var-file=${TFVARS_DIR}/${platform}.tfvars")
            else
                echo -e "${RED}Error: Invalid platform '$platform'${NC}" >&2
                echo "Valid platforms: ${PLATFORMS[*]} all" >&2
                exit 1
            fi
        done
    fi
    
    echo "${var_files[@]}"
}

check_tfvars_files() {
    if [[ ! -f "${TFVARS_DIR}/global.tfvars" ]]; then
        echo -e "${RED}Error: global.tfvars not found in ${TFVARS_DIR}${NC}" >&2
        exit 1
    fi
    
    for platform in "${PLATFORMS[@]}"; do
        if [[ ! -f "${TFVARS_DIR}/${platform}.tfvars" ]]; then
            echo -e "${YELLOW}Warning: ${platform}.tfvars not found in ${TFVARS_DIR}${NC}" >&2
        fi
    done
}

check_and_init_terraform() {
    # Check if terraform needs initialization
    if [[ ! -d ".terraform" ]] || [[ ! -f ".terraform.lock.hcl" ]]; then
        echo -e "${YELLOW}Terraform not initialized. Running 'terraform init'...${NC}"
        terraform init
        echo ""
    fi
}

run_terraform() {
    local command=$1
    shift
    local platforms=("$@")
    
    if [[ ${#platforms[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No platforms specified${NC}" >&2
        usage
        exit 1
    fi
    
    check_tfvars_files
    
    # Auto-initialize terraform if needed (except for explicit init command)
    if [[ "$command" != "init" ]]; then
        check_and_init_terraform
    fi
    
    local var_files
    var_files=($(build_var_files "${platforms[@]}"))
    
    echo -e "${BLUE}Running terraform $command with platforms: ${platforms[*]}${NC}"
    echo -e "${YELLOW}Using var files: ${var_files[*]}${NC}"
    echo ""
    
    case $command in
        init)
            terraform init
            ;;
        plan)
            terraform plan "${var_files[@]}"
            ;;
        apply)
            terraform apply "${var_files[@]}"
            ;;
        destroy)
            terraform destroy "${var_files[@]}"
            ;;
        validate)
            terraform validate
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}" >&2
            usage
            exit 1
            ;;
    esac
}

main() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi
    
    local command=$1
    shift
    
    case $command in
        help|--help|-h)
            usage
            exit 0
            ;;
        init|validate)
            terraform "$command"
            ;;
        plan|apply|destroy)
            if [[ $# -eq 0 ]]; then
                echo -e "${RED}Error: Platform(s) must be specified for $command${NC}" >&2
                usage
                exit 1
            fi
            run_terraform "$command" "$@"
            ;;
        *)
            echo -e "${RED}Error: Unknown command '$command'${NC}" >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
