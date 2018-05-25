#####
# Generate kubeadm token
#####
module "kubeadm-token" {
  source = "github.com/scholzj/terraform-kubeadm-token"
}

#####
#Create Kubernetes masters and associated resources
#####

# Source Subscription and Vnet Data
data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "vnet-kubernetes" {
  name                 = "${var.vnet_name}"
  resource_group_name  = "${var.vnet_resource_group_name}"
}

data "azurerm_resource_group" "rg-vnet-kubernetes" {
  name = "${var.vnet_resource_group_name}"
}

# Create Resource Group for Kubernetes cluster
resource "azurerm_resource_group" "rg-kubernetes" {
  name     = "${var.k8s_resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

# Create Network Security Group 
resource "azurerm_network_security_group" "nsg-kubernetes" {
  name                         = "nsg-kubernetes"
  location                     = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name          = "${azurerm_resource_group.rg-kubernetes.name}"

  security_rule {
    name                       = "kube_apiserver"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.cluster_cidr}"
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
    destination_address_prefix = "${var.cluster_cidr}"
  }

  tags     = "${var.tags}"

}

# Add K8s Subnet to Vnet
resource "azurerm_subnet" "subnet-k8s" {
  name                      = "${var.subnet_name}"
  resource_group_name       = "${var.vnet_resource_group_name}"
  virtual_network_name      = "${var.vnet_name}"
  address_prefix            = "${var.cluster_cidr}"
  network_security_group_id = "${azurerm_network_security_group.nsg-kubernetes.id}"
}

# Create Load Balancer for the Masters
resource "azurerm_public_ip" "pip-masters" {
  name                         = "${var.k8s_cluster_name}_access"
  location                     = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name          = "${azurerm_resource_group.rg-kubernetes.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "${var.k8s_cluster_name}-master"
}

resource "azurerm_lb" "lb-masters" {
  name                = "lb-masters"
  location            = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name = "${azurerm_resource_group.rg-kubernetes.name}"
  tags                = "${var.tags}"

  frontend_ip_configuration {
    name = "PublicIpAddressMasters"
    public_ip_address_id = "${azurerm_public_ip.pip-masters.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "pool-masters" {
  resource_group_name = "${azurerm_resource_group.rg-kubernetes.name}"
  loadbalancer_id     = "${azurerm_lb.lb-masters.id}"
  name                = "MastersPool"
}

resource "azurerm_lb_probe" "lbprobe-master" {
  resource_group_name = "${azurerm_resource_group.rg-kubernetes.name}"
  loadbalancer_id     = "${azurerm_lb.lb-masters.id}"
  name                = "tcpHTTPSProbe"
  port                = 6443
}

resource "azurerm_lb_rule" "lbrule-masters" {
  resource_group_name = "${azurerm_resource_group.rg-kubernetes.name}"
  loadbalancer_id     = "${azurerm_lb.lb-masters.id}"
  name                           = "kube-apiserver"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "PublicIpAddressMasters"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.pool-masters.id}"
  probe_id                       = "${azurerm_lb_probe.lbprobe-master.id}"
}

resource "azurerm_lb_nat_rule" "ssh-masters" {
  count                          = "${var.vm_count}"
  resource_group_name            = "${azurerm_resource_group.rg-kubernetes.name}"
  loadbalancer_id                = "${azurerm_lb.lb-masters.id}"
  name                           = "ssh-master${count.index}"
  protocol                       = "tcp"
  frontend_port                  = "5000${count.index + 1}"
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIpAddressMasters"
}

resource "azurerm_network_interface" "nic" {
  count                     = "${var.vm_count}"
  name                      = "nic-master${count.index}"
  location                  = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name       = "${azurerm_resource_group.rg-kubernetes.name}"
  
  tags                      = "${var.tags}"

  ip_configuration {
    name                                   = "ip-masters${count.index}"
    subnet_id                              = "${azurerm_subnet.subnet-k8s.id}"
    private_ip_address_allocation          = "dynamic"
    // public_ip_address_id                   = "${azurerm_public_ip.pip-masters.id}"
    load_balancer_inbound_nat_rules_ids    = ["${element(azurerm_lb_nat_rule.ssh-masters.*.id, count.index)}"]
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.pool-masters.id}"]
  }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.rg-kubernetes.name}"
  }

  byte_length = 8
}

resource "azurerm_storage_account" "stor" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = "${azurerm_resource_group.rg-kubernetes.name}"
  location                 = "${azurerm_resource_group.rg-kubernetes.location"
  account_tier             = "${var.storage_account_tier}"
  account_replication_type = "${var.storage_account_type}"
  
  tags                     = "${var.tags}"  
}

resource "azurerm_availability_set" "avset" {
  name                         = "avset-masters"
  location                     = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name          = "${azurerm_resource_group.rg-kubernetes.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 3
  managed                      = true
}

data "template_file" "cloudconfig-master" {
  template = "${file("${var.cloudconfig_masters_file}")}"

  vars {
    kubernetes_version           = "${var.kubernetes_version}"
    kubeadm_token                = "${module.kubeadm-token.token}"
    dns_name                     = "${azurerm_public_ip.pip-masters.fqdn}"
    ip_address                   = "${azurerm_public_ip.pip-masters.ip_address}"
    location                     = "${azurerm_resource_group.rg-kubernetes.location}"
    tenant_id                    = "${data.azurerm_client_config.current.tenant_id}"
    subscription_id              = "${data.azurerm_client_config.current.subscription_id}"
    resource_group               = "${azurerm_resource_group.rg-kubernetes.name}"
    vnet_name                    = "${var.vnet_name}"
    subnet_name                  = "${var.subnet_name}"
    vnet_resource_group          = "${var.vnet_resource_group_name}"
    cluster_cidr                 = "${var.cluster_cidr}"
    security_group_name          = "${azurerm_network_security_group.nsg-kubernetes.name}"
    primary_scaleset_name        = "${var.vmscaleset_name}"
    addons                       = "${join(" ", var.addons)}"
    route_table_name             = "k8s-master-routetable"
  }
}

data "template_cloudinit_config" "config-master" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.cloudconfig-master.rendered}"
  }
}

resource "azurerm_virtual_machine" "vm-masters" {
  count                 = "${var.vm_count}"
  name                  = "vm-master${count.index}"
  location              = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name   = "${azurerm_resource_group.rg-kubernetes.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  vm_size               = "${var.vm_size}"
  delete_os_disk_on_termination = true
  tags                = "${var.tags}" 
  identity = {
    type = "SystemAssigned"
  } 

  storage_image_reference {
    publisher = "${var.vm_os_publisher}"
    offer     = "${var.vm_os_offer}"
    sku       = "${var.vm_os_sku}"
    version   = "${var.vm_os_version}"
  }

  storage_os_disk {
    name              = "osdisk-master${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "${var.managed_disk_type}"
  }

  os_profile {
    computer_name  = "vm-master${count.index}"
    admin_username = "${var.admin_username}"
    custom_data    = "${data.template_cloudinit_config.config-master.rendered}"
  }
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("${var.ssh_key}")}"
    }
  }
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
        "os_profile"
      ]
  }
}

resource "azurerm_virtual_machine_extension" "msi-masters" {
  count                = "${var.vm_count}"
  name                 = "msi-master"
  location             = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name  = "${azurerm_resource_group.rg-kubernetes.name}"
  virtual_machine_name = "${azurerm_virtual_machine.vm-masters.name}"
  publisher            = "Microsoft.ManagedIdentity"
  type                 = "ManagedIdentityExtensionForLinux"
  type_handler_version = "1.0"
  settings             = "{\"port\": 50342}"
}

locals {
  masters_principal_ids = ["${azurerm_virtual_machine.vm-masters.*.identity.0.principal_id}"]
}

resource "azurerm_role_assignment" "masters-role-assignment-cluster-rg" {
  depends_on           = ["azurerm_virtual_machine_extension.msi-masters"]
  count                = "${var.vm_count}"
  scope                = "${azurerm_resource_group.rg-kubernetes.id}"
  role_definition_name = "Contributor"
  principal_id         = "${local.masters_principal_ids[count.index]}"
}

resource "azurerm_role_assignment" "masters-role-assignment-vnet-rg" {
  depends_on           = ["azurerm_virtual_machine_extension.msi-masters"]
  count                = "${var.vm_count}"
  scope                = "${data.azurerm_resource_group.rg-vnet-kubernetes.id}"
  role_definition_name = "Contributor"
  principal_id         = "${local.masters_principal_ids[count.index]}"
}

#####
#Create Kubernetes agents and associated resources
#####
data "template_file" "cloudconfig-agent" {
  template = "${file("${var.cloudconfig_agent_file}")}"
   
  vars {
    master_host_name             = "vm-master0"
    kubernetes_version           = "${var.kubernetes_version}"
    kubeadm_token                = "${module.kubeadm-token.token}"
    dns_name                     = "${azurerm_public_ip.pip-masters.fqdn}"
    location                     = "${azurerm_resource_group.rg-kubernetes.location}"
    tenant_id                    = "${data.azurerm_client_config.current.tenant_id}"
    subscription_id              = "${data.azurerm_client_config.current.subscription_id}"
    resource_group               = "${azurerm_resource_group.rg-kubernetes.name}"
    vnet_name                    = "${var.vnet_name}"
    subnet_name                  = "${var.subnet_name}"
    vnet_resource_group          = "${var.vnet_resource_group_name}"
    cluster_cidr                 = "${var.cluster_cidr}"
    security_group_name          = "${azurerm_network_security_group.nsg-kubernetes.name}"
    primary_scaleset_name        = "${var.vmscaleset_name}"
    route_table_name             = "k8s-master-routetable"
  }
}

data "template_cloudinit_config" "config-agent" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.cloudconfig-agent.rendered}"
  }
}

resource "azurerm_virtual_machine_scale_set" "vm-agents" {
  depends_on          = ["azurerm_virtual_machine.vm-masters"]
  count               = "${var.nb_instance}"
  name                = "${var.vmscaleset_name}"
  location            = "${azurerm_resource_group.rg-kubernetes.location}"
  resource_group_name = "${azurerm_resource_group.rg-kubernetes.name}"
  upgrade_policy_mode = "Manual"
  tags                = "${var.tags}"

  sku {
    name     = "${var.vm_size}"
    tier     = "Standard"
    capacity = "${var.nb_instance}"
  }

  storage_profile_image_reference {
    publisher = "${var.vm_os_publisher}"
    offer     = "${var.vm_os_offer}"
    sku       = "${var.vm_os_sku}"
    version   = "${var.vm_os_version}"
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "${var.managed_disk_type}"
  }

  os_profile {
    computer_name_prefix = "vm-agent"
    admin_username       = "${var.admin_username}"
    custom_data          = "${data.template_cloudinit_config.config-agent.rendered}"
    admin_password       = "Passwword1234"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = "${file("${var.ssh_key}")}"
    }
  }

  network_profile {
    name    = "agentsNetworkProfile"
    primary = true

    ip_configuration {
      name        = "IPConfiguration"
      subnet_id   = "${azurerm_subnet.subnet-k8s.id}"
    }
  }
  identity {
    type     = "systemAssigned"
  }

  extension {
    name                       = "MSILinuxExtension"
    publisher                  = "Microsoft.ManagedIdentity"
    type                       = "ManagedIdentityExtensionForLinux"
    type_handler_version       = "1.0"
    settings                   = "{\"port\": 50342}"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
        "os_profile"
      ]
  }
}

resource "azurerm_role_assignment" "agents-role-assignment-cluster-rg" {
  scope                = "${azurerm_resource_group.rg-kubernetes.id}"
  role_definition_name = "Reader"
  principal_id         = "${lookup(azurerm_virtual_machine_scale_set.vm-agents.0.identity[0], "principal_id")}"
}

resource "azurerm_role_assignment" "agents-role-assignment-vnet-rg" {
  scope                = "${data.azurerm_resource_group.rg-vnet-kubernetes.id}"
  role_definition_name = "Reader"
  principal_id         = "${lookup(azurerm_virtual_machine_scale_set.vm-agents.0.identity[0], "principal_id")}"
}

 
 