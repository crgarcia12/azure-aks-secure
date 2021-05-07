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
Install-Module -Name Az.ManagedServiceIdentity -AllowPrerelease
```

# Notes
Features in preview
AKS Azure Policies
  - No custom policies

# Create a simulated Landing Zone
Open Debug.ps1 and run using F5

## Deploy cluster manually
```
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile ./arm/aks.json -TemplateParameterFile $TemplateParameterFilePath
```

## Connect to the cluster
This is a private cluster, if you are not in the VNet you cannot connect.

### Creating a jumpbox
Configure the Linux Jumpbox
```
ssh adminuser@publicip  // password P@ssword123123
sudo bash
apt install openvpn

https://www.ovpn.com/en/guides/ubuntu-cli

sudo echo "adminuser" >> /etc/openvpn/credentials
sudo echo "P@ssword123123" >> /etc/openvpn/credentials

# Install docker
apt-get update
apt-get upgrade

# requirements
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# add docker official repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# install docker
 sudo apt-get update
 sudo apt-get install docker-ce docker-ce-cli containerd.io

sudo docker run hello-world

# install Azure cli
sudo apt remove azure-cli -y && sudo apt autoremove -y
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

sudo az aks install-cli

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


 #BYO MI
 $rg = "crgar-aks-mi"
az identity create --name "crgar-aks-cp-identity" --resource-group  $rg 