#####
# Create Resource Groups for Vnet 
#####

resource "azurerm_resource_group" "rg-vnet-kubernetes" {
  name     = "${var.vnet_resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

#####
# Create vNet 
#####

resource "azurerm_virtual_network" "vnet-kubernetes" {
  name                = "${var.vnet_name}"
  address_space       = ["${var.vnet_cidr}"]
  location            = "${azurerm_resource_group.rg-vnet-kubernetes.location}"
  resource_group_name = "${azurerm_resource_group.rg-vnet-kubernetes.name}"

  tags                = "${var.tags}"
}

#####
# Launch Kubernetes Module
#####

// module "kubernetes" {
//   source                   = "./modules/kubernetes"
//   k8s_resource_group_name  = "${var.k8s_resource_group_name}"
//   vnet_resource_group_id   = "${azurerm_resource_group.rg-vnet-kubernetes.id}"
//   vnet_resource_group_name = "${azurerm_resource_group.rg-vnet-kubernetes.name}"
//   k8s_resource_group_id    = "${azurerm_resource_group.rg-kubernetes.id}"
//   k8s_resource_group_name  = "${azurerm_resource_group.rg-kubernetes.name}"
//   k8s_security_group_name  = "${azurerm_network_security_group.nsg-kubernetes.name}"
//   k8s_cluster_name         = "${var.k8s_cluster_name}"
//   cluster_cidr             = "${var.subnet_prefix}"
//   location                 = "${var.location}"
//   kubernetes_version       = "${var.kubernetes_version}"
//   vnet_name                = "${azurerm_virtual_network.vnet-kubernetes.name}"
//   subnet_name              = "${azurerm_subnet.subnet-k8s.name}"
//   subnet_id                = "${azurerm_subnet.subnet-k8s.id}"
//   vm_size                  = "${var.masters_vm_size}"
//   vm_count                 = "${var.masters_vm_count}"
//   vm_os_publisher          = "${var.vm_os_publisher}"
//   vm_os_offer              = "${var.vm_os_offer}"
//   vm_os_sku                = "${var.vm_os_sku}"
//   vm_os_version            = "${var.vm_os_version}"
//   nb_instance              = "${var.nb_instance}"
//   addons                   = "${var.addons}"
// }