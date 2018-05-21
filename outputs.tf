output "new_token" {
  value = "${module.kubeadm-token.token}"
}

output "master_load_balancer_ip_address" {
  value = "${module.kubernetes.master_load_balancer_ip_address}"
}

