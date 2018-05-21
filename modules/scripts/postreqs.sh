#!/bin/sh
# -------
DNS_NAME=${dns_name}

scp -i ~/.ssh/id_rsa -P 50001 theadmin@"${DNS_NAME}":/home/theadmin/kubeconfig ./config 
export KUBECONFIG=`pwd`/config
kubectl config set-cluster kubernetes --server="https://${DNS_NAME}:6443"

# Label dedicated vault nodes
kubectl label node vm-agent000003 vm-agent000004 dedicated=vault

# Ensure nodes in the vault-pool node pool only accept Vault workloads by tainting them:
kubectl taint nodes \
  $(kubectl get nodes -l dedicated=vault -o jsonpath='{.items[*].metadata.name}') \
  dedicated=vault:NoSchedule


