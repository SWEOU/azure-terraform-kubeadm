#!/bin/sh
# -------
export KUBERNETES_VERSION=${kubernetes_version}
export KUBEADM_TOKEN=${kubeadm_token}
export DNS_NAME=${dns_name}
export IP_ADDRESS=${ip_address}
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
LOCAL_IP_ADDRESS=$(ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')

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
apt-get install -y kubelet="$${KUBERNETES_VERSION}*" kubeadm="$${KUBERNETES_VERSION}*" kubectl kubernetes-cni

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
sed -i '/Environment="KUBELET_KUBECONFIG_ARGS/a\\Environment="KUBELET_CLOUD_ARGS=--non-masquerade-cidr=10.96.0.0/12 --network-plugin=kubenet --pod-cidr=10.96.0.0/12 --cloud-provider=azure --cloud-config=/etc/kubernetes/azure.json --address=0.0.0.0"' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sed -i '/ExecStart=\/usr/s/$/ $KUBELET_CLOUD_ARGS/' /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

systemctl daemon-reload
systemctl enable kubelet 
systemctl restart kubelet

# kubeadm - master node
# ---------------------
# initialize master
cat >/tmp/kubeadm.yaml <<EOF
---
apiVersion: kubeadm.k8s.io/v1alpha1
kind: MasterConfiguration
token: $KUBEADM_TOKEN
kubernetesVersion: v$KUBERNETES_VERSION
apiServerCertSANs:
- $DNS_NAME
- $IP_ADDRESS
- $LOCAL_IP_ADDRESS
apiServerExtraArgs:
  cloud-provider: azure
  cloud-config: /etc/kubernetes/azure.json
kubeProxy:
  config:
    clusterCIDR: 10.96.0.0/12
controllerManagerExtraArgs:
  cloud-provider: azure
  cloud-config: /etc/kubernetes/azure.json
  cluster-cidr: 10.96.0.0/12
apiServerExtraVolumes:
- name: etc-kubernetes
  hostPath: /etc/kubernetes
  mountPath: /etc/kubernetes
- name: msi
  hostPath: /var/lib/waagent
  mountPath: /var/lib/waagent
controllerManagerExtraVolumes:
- name: etc-kubernetes
  hostPath: /etc/kubernetes
  mountPath: /etc/kubernetes
- name: msi
  hostPath: /var/lib/waagent
  mountPath: /var/lib/waagent
EOF

kubeadm init --config /tmp/kubeadm.yaml

# copy /etc/kubernetes/admin.conf so we can use kubectl
mkdir -p /home/theadmin/.kube/
cp -i /etc/kubernetes/admin.conf /home/theadmin/.kube/config
sudo chown 1000:1000 /home/theadmin/.kube/config

export KUBECONFIG='/etc/kubernetes/admin.conf'

# install pod network
# kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubeadm/1.6/calico.yaml

# install azure storage classes and addon manager
# Setup extra manifest templates
cat >/etc/kubernetes/manifests/kube-addon-manager.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kube-addon-manager
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-addon-manager
    image: k8s-gcrio.azureedge.net/kube-addon-manager-amd64:v8.6
    resources:
      requests:
        cpu: 5m
        memory: 50Mi
    volumeMounts:
    - name: addons
      mountPath: "/etc/kubernetes/addons"
      readOnly: true
    - name: msi
      mountPath: "/var/lib/waagent/ManagedIdentity-Settings"
      readOnly: true
  volumes:
  - name: addons
    hostPath:
      path: "/etc/kubernetes/addons"
  - name: msi
    hostPath:
      path: "/var/lib/waagent/ManagedIdentity-Settings"
EOF

kubectl apply -f /etc/kubernetes/manifests/kube-addon-manager.yaml

mkdir -p /etc/kubernetes/addons
cat >/etc/kubernetes/addons/azure-storage-classes.yaml <<EOF
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: default
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  kind: Managed
  storageaccounttype: Premium_LRS
  cachingmode: None
---
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: managed-premium
  annotations:
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  kind: Managed
  storageaccounttype: Premium_LRS
  cachingmode: None
---
apiVersion: storage.k8s.io/v1beta1
kind: StorageClass
metadata:
  name: managed-standard
  annotations:
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: kubernetes.io/azure-disk
parameters:
  kind: Managed
  storageaccounttype: Standard_LRS
  cachingmode: None
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: azurefile
  annotations:
  labels:
    kubernetes.io/cluster-service: "true"
provisioner: kubernetes.io/azure-file
parameters:
  skuName: Standard_LRS
EOF

kubectl apply -f /etc/kubernetes/addons/azure-storage-classes.yaml

# --------------------------------------------
echo 'configuration complete' > /tmp/hello.txt
