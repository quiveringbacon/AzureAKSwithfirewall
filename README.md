# Azure AKS with Azure Firewall

This is adapted from: https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-terraform?pivots=development-environment-azure-cli and https://learn.microsoft.com/en-us/azure/firewall/protect-azure-kubernetes-service

This lab creates a resource group, a vnet with an Azure Kubernetes Service in the default subnet and an Azure firewall behind it. A route table is added to the default subnet sending all traffic to the firewall and a dnat rule sending incoming port 80 traffic to AKS is added to the firewall policy (along with rules for AKS getting out). You can connect to the firewall public ip on port 80 to see the demo site. This also creates a logic app that will delete the resource group in 24hrs. You'll be prompted for the resource group name, location where you want the resources created, and your subscriptionID.

Topology will look like this:

![azakslabwithfw](https://github.com/user-attachments/assets/149da28f-f2d7-433b-a3e4-65fabc8857f3)

You can run Terraform right from the Azure cloud shell by cloning this git repository with "git clone https://github.com/quiveringbacon/AzureAKSwithfirewall.git ./terraform".

Then, "cd terraform" then, "terraform init" and finally "terraform apply -auto-approve" to deploy.

