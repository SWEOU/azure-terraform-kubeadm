output "agent_vmss_name" {
  value = "${azurerm_virtual_machine_scale_set.vm-agents.*.name}"
}

output "master_cluster_size" {
  value = "${var.nb_instance}"
}

output "agent_cluster_size" {
  value = "${var.vm_count}"
}

output "master_load_balancer_ip_address" {
  value = "${azurerm_public_ip.pip-masters.*.ip_address}"
}

output "new_token" {
  value = "${module.kubeadm-token.token}"
}





