#####
# Configure Azure Provider
#####

provider "azurerm" {
  subscription_id = "${var.azure_subscription_id}"
  client_id       = "${var.azure_client_id}"
  client_secret   = "${var.azure_client_secret}"
  tenant_id       = "${var.azure_tenant_id}"
}

#####
# Create Resource Groups for Vnet and K8s Cluster
#####

resource "azurerm_resource_group" "rg-vnet-hashinetes" {
  name     = "${var.vnet_resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

resource "azurerm_resource_group" "rg-hashinetes" {
  name     = "${var.k8s_resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

#####
# Create Network Security Group 
#####

resource "azurerm_network_security_group" "nsg-hashinetes" {
  name                         = "nsg-hashinetes"
  location                     = "${azurerm_resource_group.rg-hashinetes.location}"
  resource_group_name          = "${azurerm_resource_group.rg-hashinetes.name}"

  security_rule {
    name                       = "kube_apiserver"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.subnet_prefix}"
  }

  security_rule {
    name                       = "ssh"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.subnet_prefix}"
  }

  tags     = "${var.tags}"

}

#####
# Create vNet 
#####

resource "azurerm_virtual_network" "vnet-hashinetes" {
  name                = "${var.vnet_name}"
  address_space       = ["${var.vnet_cidr}"]
  location            = "${azurerm_resource_group.rg-vnet-hashinetes.location}"
  resource_group_name = "${azurerm_resource_group.rg-vnet-hashinetes.name}"

  tags                = "${var.tags}"
}

resource "azurerm_subnet" "subnet-k8s" {
  name                      = "${var.subnet_name}"
  resource_group_name       = "${azurerm_resource_group.rg-vnet-hashinetes.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet-hashinetes.name}"
  address_prefix            = "${var.subnet_prefix}"
  network_security_group_id = "${azurerm_network_security_group.nsg-hashinetes.id}"

}

resource "azurerm_subnet" "subnet-nomad-workers" {
  name                      = "subnet-nomad-workers"
  resource_group_name       = "${azurerm_resource_group.rg-vnet-hashinetes.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet-hashinetes.name}"
  address_prefix            = "10.0.1.0/24"
  network_security_group_id = "${azurerm_network_security_group.nsg-hashinetes.id}"

}

#####
# Generate kubeadm token
#####

module "kubeadm-token" {
  source = "github.com/scholzj/terraform-kubeadm-token"
}

#####
# Launch Kubernetes Module
#####

module "kubernetes" {
  source                   = "./modules/kubernetes"
  k8s_resource_group_name  = "${var.k8s_resource_group_name}"
  vnet_resource_group_id   = "${azurerm_resource_group.rg-vnet-hashinetes.id}"
  vnet_resource_group_name = "${azurerm_resource_group.rg-vnet-hashinetes.name}"
  k8s_resource_group_id    = "${azurerm_resource_group.rg-hashinetes.id}"
  k8s_resource_group_name  = "${azurerm_resource_group.rg-hashinetes.name}"
  k8s_security_group_name  = "${azurerm_network_security_group.nsg-hashinetes.name}"
  k8s_cluster_name         = "${var.k8s_cluster_name}"
  cluster_cidr             = "${var.subnet_prefix}"
  location                 = "${var.location}"
  kubeadm_token            = "${module.kubeadm-token.token}"
  kubernetes_version       = "${var.kubernetes_version}"
  vnet_name                = "${azurerm_virtual_network.vnet-hashinetes.name}"
  subnet_name              = "${azurerm_subnet.subnet-k8s.name}"
  subnet_id                = "${azurerm_subnet.subnet-k8s.id}"
  vm_size                  = "${var.masters_vm_size}"
  vm_count                 = "${var.masters_vm_count}"
  vm_os_publisher          = "${var.vm_os_publisher}"
  vm_os_offer              = "${var.vm_os_offer}"
  vm_os_sku                = "${var.vm_os_sku}"
  vm_os_version            = "${var.vm_os_version}"
  nb_instance              = "${var.nb_instance}"
}