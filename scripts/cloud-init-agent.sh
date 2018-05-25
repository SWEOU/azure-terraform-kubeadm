#!/bin/sh
# -------

export MASTER_HOST_NAME=${master_host_name}
export KUBERNETES_VERSION=${kubernetes_version}
export KUBEADM_TOKEN=${kubeadm_token}
export DNS_NAME=${dns_name}
export LOCATION=${location}
export TENANT_ID=${tenant_id}
export SUBSCRIPTION_ID=${subscription_id}
export RESOURCE_GROUP=${resource_group}
export VNET_NAME=${vnet_name}
export SUBNET_NAME=${subnet_name}
export VNET_RESOURCE_GROUP=${vnet_resource_group}
export CLUSTER_CIDR=${cluster_cidr}
export SECURITY_GROUP_NAME=${security_group_name}
export PRIMARY_SCALESET_NAME=${primary_scaleset_name}
export ROUTE_TABLE_NAME=${route_table_name}

# install docker & kubeadm - ubuntu
# ---------------------------------

# update and upgrade packages
apt-get update && apt-get upgrade -y

# install docker
apt-get install -y docker.io

# install kubeadm
apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF

apt-get update
apt-get install -y kubelet="$${KUBERNETES_VERSION}*" kubeadm="$${KUBERNETES_VERSION}*" kubectl 

# Create Azure Cloud Config
mkdir -p /etc/kubernetes/
cat >/etc/kubernetes/azure.json <<EOF
{
    "cloud":"AzurePublicCloud",
    "tenantId": "$TENANT_ID",
    "subscriptionId": "$SUBSCRIPTION_ID",
    "aadClientId": "msi",
    "aadClientSecret": "msi",
    "resourceGroup": "$RESOURCE_GROUP",
    "location": "$LOCATION",
    "vmType": "vmss",
    "subnetName": "$SUBNET_NAME",
    "securityGroupName": "$SECURITY_GROUP_NAME",
    "vnetName": "$VNET_NAME",
    "vnetResourceGroup": "$VNET_RESOURCE_GROUP",
    "primaryAvailabilitySetName": "",
    "primaryScaleSetName": "$PRIMARY_SCALESET_NAME",
    "routeTableName": "$ROUTE_TABLE_NAME",
    "cloudProviderBackoff": false,
    "cloudProviderBackoffRetries": 0,
    "cloudProviderBackoffExponent": 0,
    "cloudProviderBackoffDuration": 0,
    "cloudProviderBackoffJitter": 0,
    "cloudProviderRatelimit": false,
    "cloudProviderRateLimitQPS": 0,
    "cloudProviderRateLimitBucket": 0,
    "useManagedIdentityExtension": true,
    "useInstanceMetadata": true
}
EOF

# Fix kubelet configuration
# sed -i '/Environment="KUBELET_KUBECONFIG_ARGS/a\\Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i '/Environment="KUBELET_KUBECONFIG_ARGS/a\\Environment="KUBELET_CLOUD_ARGS=--non-masquerade-cidr=10.96.0.0/12 --network-plugin=kubenet --cloud-provider=azure --cloud-config=/etc/kubernetes/azure.json --address=0.0.0.0"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i '/ExecStart=\/usr/s/$/ $KUBELET_CLOUD_ARGS/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl enable kubelet 
systemctl restart kubelet

# kubeadm - agent nodes
# ---------------------
# initialize agent node

kubeadm join --token $KUBEADM_TOKEN --node-name `hostname` $MASTER_HOST_NAME:6443 --discovery-token-unsafe-skip-ca-verification

# --------------------------------------------
echo 'configuration complete' > /tmp/hello.txt