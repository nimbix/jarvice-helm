variable "azure_service_principal_client_id" {
  description = "The Client ID for the Service Principal to use for this Managed Kubernetes Cluster"
  type = string
}

variable "azure_service_principal_client_secret" {
  description = "The Client Secret for the Service Principal to use for this Managed Kubernetes Cluster"
  type = string
}

variable "location" {
  description = "Azure region in which all resources should be provisioned"
  type = string
  default = "Central US"
}

variable "availability_zones" {
  description = "Azure availability zones in which all resources should be provisioned"
  type = list
  default = ["1"]
}

variable "cluster_name" {
  description = "Cluster name"
  type = string
  default = "jarvice"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type = string
  default = "1.15.10"
}

variable "ssh_public_key" {
  description = "SSH key used for accessing cluster nodes"
  type = string
  default = "~/.ssh/id_rsa.pub"
}

variable "compute_node_vm_size" {
  description = "Size of the compute node VMs"
  type = string
  default = "Standard_DS13_v2"
}

variable "compute_node_os_disk_size_gb" {
  description = "Disk size of the compute node VMs"
  type = number
  default = 100
}

variable "compute_node_count" {
  description = "Initial number of compute nodes"
  type = number
  default = 2
}

variable "compute_node_min_count" {
  description = "Minimal number of compute nodes"
  type = number
  default = 1
}

variable "compute_node_max_count" {
  description = "Maximum number of compute nodes"
  type = number
  default = 16
}

variable "override_yaml" {
  description = "YAML override file that provides the helm chart values"
  type = string
  default = "override.yaml"
}

variable "JARVICE_PVC_VAULT_SIZE" {
  description = "JARVICE_PVC_VAULT_SIZE"
  type = string
  default = "10"
}

variable "JARVICE_PVC_VAULT_NAME" {
  description = "JARVICE_PVC_VAULT_NAME"
  type = string
  default = "persistent"
}

variable "JARVICE_PVC_VAULT_STORAGECLASS" {
  description = "JARVICE_PVC_VAULT_STORAGECLASS"
  type = string
  default = "jarvice-user"
}

variable "JARVICE_PVC_VAULT_ACCESSMODES" {
  description = "JARVICE_PVC_VAULT_ACCESSMODES"
  type = string
  default = "ReadWriteOnce"
}

