# THIS IS WORK IN PROGRESS
# Introduction 
This repository contains the infrastructure code needed to create a secure and compliant AKS cluster
The cluster will be deployed in a pre-existent VNet and logs will be streammed to a pre-existent Log Analytics

# Requirements
```
# Cli Az Firewall extension
az --upgrade
az extension add -n azure-firewall
# Update Azure module
Update-Module Az
```

# Notes
Features in preview
AKS Azure Policies
  - No custom policies

# Create a simulated Landing Zone
Open Debug.ps1 and run using F5

# Prerequisites
A subnet with enough IP addresses and subnets:

name: aks-ms-workshop-vnet
address range: 10.0.0.0/16
Subnets:
    aks-subnet: 10.1.0.0/18
    support-subnet: 10.1.100.0/24
Log analytics workspace

## Deploy cluster manually
```
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile ./arm/aks.json -TemplateParameterFile $TemplateParameterFilePath
```

## Connect to the cluster
This is a private cluster, if you are not in the VNet you cannot connect.

### Creating a jumpbox
Create an ubuntu VM and place it in the aks subnet

```
ssh adminuser@publicip -p P@ssword123123
sudo apt install openvpn

```

### Validate AAD authentication

```
az aks show --name .... --resource-group
#Search for tenant and secret
az aks get-credentials --name --resource-group  (--admin will bypass)

code /usr/crgar/.kube/config
#check certificate authority data, and auth-provider

```
kubectl get nodes
does not work, you have no access
lets add the user

### making a cluster admin
kubectl apply -f k8s/rbac_users.yaml
az aks get-credentials --name --resource-group 

### showing audit logs
Cluster resources -> Diagnostic ssettings -> Kube-audit

# Enable policies
az extension install aks-preview
az feature register AKS-PolicyAutoApprove (*)
or in the portal -> POlicies -> enable

Goto azure policies
Filter Category: Kubernetes

Add and create

Check the policies logs:
kubectl get pods --namespace kube-system
kubectl create pod 

# CheatSheet

### Install busybox and ssh into a container
kubectl run -i --tty busybox --image=busybox -- sh
If you want it to run on a specific node

kubectl run -i --tty busybox --image=busybox -- sh --overrides='{ "apiVersion": "apps/v1beta1", "spec": { "template": { "spec": { "nodeSelector": { "kubernetes.io/hostname": "akswin3p1000000" } } } } }'

#### This is how you attach to an existing container
 kubectl exec -it busybox1 /bin/sh