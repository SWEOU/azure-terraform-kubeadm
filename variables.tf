variable "k8s_resource_group_name" {
  description = "The name of the resource group in which the resources will be created"
  default     = "rg-kubernetes"
}

variable "vnet_resource_group_name" {
  description = "The name of the resource group in which the resources will be created"
  default     = "rg-vnet-kubernetes"
}

variable "vnet_name" {
  description = "The name of the vNet that will be created in Azure"
}

variable "subnet_name" {
  description = "The name of the subnet that the cluster will join"
  default = "subnet-k8s"
}

variable "cluster_cidr" {
  description = "CIDR range for k8s"
}

variable "k8s_cluster_name" {
  description = "The domain label that will be used for the master front-end IP"
}

variable "location" {
  description = "The location where the resources will be created"
  default     = "eastus"
}

variable "vm_size" {
  default     = "Standard_DS2_v2"
  description = "Size of the Virtual Machine based on Azure sizing"
}

variable "vmscaleset_name" {
  default     = "vmss-agents"
  description = "The name of the VM scale set that will be created in Azure"
}

variable "nb_instance" {
  description = "Specify the number of vm instances"
  default     = 1
}

variable "vm_count" {
  default     = 1
  description = "The number of kubernetes masters that will be created in Azure"
}

variable "vm_os_publisher" {
  description = "The name of the publisher of the image that you want to deploy"
  default     = "Canonical"
}

variable "vm_os_offer" {
  description = "The name of the offer of the image that you want to deploy"
  default     = "UbuntuServer"
}

variable "vm_os_sku" {
  description = "The sku of the image that you want to deploy"
  default     = "16.04-LTS"
}

variable "vm_os_version" {
  description = "The version of the image that you want to deploy."
  default     = "latest"
}

variable "admin_username" {
  description = "The admin username of the VMSS that will be deployed"
  default     = "theadmin"
}

variable "ssh_key" {
  description = "Path to the public key to be used for ssh access to the VM"
  default     = "~/.ssh/id_rsa.pub"
}

variable "tags" {
  type        = "map"
  description = "A map of the tags to use on the resources that are deployed with this module."

  default = {
    source = "terraform"
  }
}

variable "kubernetes_version" {
  description = "Version of kubernetes to be installed"
  default     = "1.10.2"
}

variable "addons" {
    description = "list of YAML files with Kubernetes addons which should be installed"
    type        = "list"
}

variable "cloudconfig_masters_file" {
  description = "The location of the cloud init configuration file."
  default     = "./scripts/cloud-init-master.sh"
}

variable "cloudconfig_agent_file" {
  description = "The location of the cloud init configuration file."
  default     = "./scripts/cloud-init-agent.sh"
}

variable "storage_account_tier" {
  description = "The tier of azure blob storage to use for diagnostic logs."
  default     = "standard"
}

variable "storage_account_type" {
  description = "The replication type of azure blob storage to use for diagnostic logs."
  default     = "LRS"
}

variable "managed_disk_type" {
  default     = "Premium_LRS"
  description = "Type of managed disk for the VMs that will be part of this compute group. Allowable values are 'Standard_LRS' or 'Premium_LRS'."
}





