# Azure Kubernetes

Azure Kubernetes is a Kubernetes cluster deployed using [Kubeadm](https://kubernetes.io/docs/admin/kubeadm/) tool. It provides full integration with Azure via the Kubernetes Internal Cloud Provider configuration settings. This enables the deployed cluster to automatically provision Azure Load Balancers when a service type LoadBalancer is deployed in the cluster, Persistent disk and File shares, and automatically congiures all the Azure routes necessary when using Kubenet and CNI. 

<!-- TOC -->

- [Azure Kubernetes](#azure-kubernetes)
    - [Updates](#updates)
    - [Prerequisites and dependencies](#prerequisites-and-dependencies)
    - [Including the module](#including-the-module)
    - [Addons](#addons)
    - [Custom addons](#custom-addons)
    - [Tagging](#tagging)

<!-- /TOC -->

## Updates

* 

## Prerequisites and dependencies

* Azure Kubernetes can deploy into an existing Vnet. The examples include Vnet creation .tf scripts if you don't have one setup already. 
* The Terrafrom client needs to be installed [Terraform](https://www.terraform.io). 
* An Azure Service Principle with with contributor RBAC on the target Azure subscription is need for configuring the Terraform AzureRM resource provider .

## Including the module

Although it can be run on its own, the main value is that it can be included into another Terraform configuration.

```hcl
module "kubernetes" {
  source = "kneeberts/kubernetes/azure"

  nb_instance              = 3
  vnet_resource_group_name = ""
  k8s_resource_group_name  = ""
  k8s_cluster_name         = ""
  subnet_id                = ""
  
  # Tags
  tags = {
    Application = "Azure-Kubernetes"
    Source      = "Terraform"
  }
  
  addons = [
    "https://raw.githubusercontent.com/kneeberts/terraform-azure-kubernetes/master/addons/storage-class.yaml",
    "https://raw.githubusercontent.com/kneeberts/terraform-azure-kubernetes/master/addons/heapster.yaml",
    "https://raw.githubusercontent.com/kneeberts/terraform-azure-kubernetes/master/addons/dashboard.yaml",
    "https://raw.githubusercontent.com/kneeberts/terraform-azure-kubernetes/master/addons/external-dns.yaml",
  ]
}
```

An example of how to include this can be found in the [examples](examples/) dir.

## Addons

Currently, following addons are supported:
* Kubernetes dashboard
* Heapster for resource monitoring
* Storage class for automatic provisioning of persisitent volumes
* External DNS 
* Ingress
* Logging with Fluentd + ElasticSearch + Kibana

The addons will be installed automatically based on the Terraform variables. 

## Custom addons

Custom addons can be added if needed. For every URL in the `addons` list, the initialization scripts will automatically call `kubectl -f apply <Addon URL>` to deploy it. The cluster is using RBAC. So the custom addons have to be *RBAC ready*.
