variable "azure_subscription_id" {
  description = "Azure Subscription ID"
}

variable "azure_client_id" {
  description = "Azure Client ID"
}

variable "azure_client_secret" {
  description = "Azure Client Secret"
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
}

variable "vnet_resource_group_name" {
  description = "The name of the resource group in which the resources will be created"
  default     = "rg-vnet-hashinetes"
}

variable "k8s_resource_group_name" {
  description = "The name of the resource group in which the resources will be created"
  default     = "rg-hashinetes"
}

variable "location" {
  description = "The location where the resources will be created"
  default     = "eastus"
}

variable "kubernetes_version" {
  description = "Version of kubernetes to be installed"
  default     = "1.10.2"
}

variable "k8s_cluster_name" {
  description = "The domain label that will be used for the master front-end IP"
  default     = "hashinetesnje01"
}

variable "masters_vm_size" {
  default     = "Standard_DS2_v2"
  description = "Size of the Virtual Machine based on Azure sizing"
}

variable "agents_vm_size" {
  default     = "Standard_DS2_v2"
  description = "Size of the Virtual Machine based on Azure sizing"
}

variable "vnet_name" {
  default     = "vnet-hashinetes"
  description = "The name of the vNet that will be created in Azure"
}

variable "vnet_cidr" {
  default     = "10.0.0.0/16"
  description = "The name of the cidr notation that will be used when creating the vNet in Azure"
}

variable "subnet_name" {
  default     = "subnet-k8s"
  description = "The name of the vNet that will be created in Azure"
}

variable "subnet_prefix" {
  default     = "10.0.0.0/24"
  description = "The name of the cidr notation that will be used when creating the subnet in Azure"
}

variable "masters_vm_count" {
  default     = 1
  description = "The number of kubernetes masters that will be created in Azure"
}

variable "vmscaleset_name" {
  default     = "vmss-agents"
  description = "The name of the VM scale set that will be created in Azure"
}

variable "nb_instance" {
  description = "Specify the number of vm instances"
  default     = 1
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

variable "tags" {
  type        = "map"
  description = "A map of the tags to use on the resources that are deployed with this module."

  default = {
    source = "terraform"
  }
}
