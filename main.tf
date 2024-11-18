provider "azurerm" {
features {}
subscription_id = var.F-SubscriptionID
}


#variables
variable "A-location" {
    description = "Location of the resources, example: eastus2"
    
}

variable "B-resource_group_name" {
    description = "Name of the resource group to create"
}

variable "F-SubscriptionID" {
  description = "Subscription ID to use"
  
}

resource "azurerm_resource_group" "RG" {
  location = var.A-location
  name     = var.B-resource_group_name
}

#logic app to self destruct resourcegroup after 24hrs
data "azurerm_subscription" "sub" {
}

resource "azurerm_logic_app_workflow" "workflow1" {
  location = azurerm_resource_group.RG.location
  name     = "labdelete"
  resource_group_name = azurerm_resource_group.RG.name
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.RG,
  ]
}
resource "azurerm_role_assignment" "contrib1" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_logic_app_workflow.workflow1.identity[0].principal_id
  depends_on = [azurerm_logic_app_workflow.workflow1]
}


resource "azurerm_resource_group_template_deployment" "apiconnections" {
  name                = "group-deploy"
  resource_group_name = azurerm_resource_group.RG.name
  deployment_mode     = "Incremental"
  template_content = <<TEMPLATE
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {},
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Web/connections",
            "apiVersion": "2016-06-01",
            "name": "arm-1",
            "location": "${azurerm_resource_group.RG.location}",
            "kind": "V1",
            "properties": {
                "displayName": "labdeleteconn1",
                "authenticatedUser": {},
                "statuses": [
                    {
                        "status": "Ready"
                    }
                ],
                "connectionState": "Enabled",
                "customParameterValues": {},
                "alternativeParameterValues": {},
                "parameterValueType": "Alternative",
                "createdTime": "2023-05-21T23:07:20.1346918Z",
                "changedTime": "2023-05-21T23:07:20.1346918Z",
                "api": {
                    "name": "arm",
                    "displayName": "Azure Resource Manager",
                    "description": "Azure Resource Manager exposes the APIs to manage all of your Azure resources.",
                    "iconUri": "https://connectoricons-prod.azureedge.net/laborbol/fixes/path-traversal/1.0.1552.2695/arm/icon.png",
                    "brandColor": "#003056",
                    "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm",
                    "type": "Microsoft.Web/locations/managedApis"
                },
                "testLinks": []
            }
        },
        {
            "type": "Microsoft.Logic/workflows",
            "apiVersion": "2017-07-01",
            "name": "labdelete",
            "location": "${azurerm_resource_group.RG.location}",
            "dependsOn": [
                "[resourceId('Microsoft.Web/connections', 'arm-1')]"
            ],
            "identity": {
                "type": "SystemAssigned"
            },
            "properties": {
                "state": "Enabled",
                "definition": {
                    "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
                    "contentVersion": "1.0.0.0",
                    "parameters": {
                        "$connections": {
                            "defaultValue": {},
                            "type": "Object"
                        }
                    },
                    "triggers": {
                        "Recurrence": {
                            "recurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "evaluatedRecurrence": {
                                "frequency": "Minute",
                                "interval": 3,
                                "startTime": "${timeadd(timestamp(),"24h")}"
                            },
                            "type": "Recurrence"
                        }
                    },
                    "actions": {
                        "Delete_a_resource_group": {
                            "runAfter": {},
                            "type": "ApiConnection",
                            "inputs": {
                                "host": {
                                    "connection": {
                                        "name": "@parameters('$connections')['arm']['connectionId']"
                                    }
                                },
                                "method": "delete",
                                "path": "/subscriptions/@{encodeURIComponent('${data.azurerm_subscription.sub.subscription_id}')}/resourcegroups/@{encodeURIComponent('${azurerm_resource_group.RG.name}')}",
                                "queries": {
                                    "x-ms-api-version": "2016-06-01"
                                }
                            }
                        }
                    },
                    "outputs": {}
                },
                "parameters": {
                    "$connections": {
                        "value": {
                            "arm": {
                                "connectionId": "[resourceId('Microsoft.Web/connections', 'arm-1')]",
                                "connectionName": "arm-1",
                                "connectionProperties": {
                                    "authentication": {
                                        "type": "ManagedServiceIdentity"
                                    }
                                },
                                "id": "/subscriptions/${data.azurerm_subscription.sub.subscription_id}/providers/Microsoft.Web/locations/${azurerm_resource_group.RG.location}/managedApis/arm"
                            }
                        }
                    }
                }
            }
        }
    ]
}
TEMPLATE
}

resource "random_pet" "name" {
  length = 1
}

#log analytics workspace
resource "azurerm_log_analytics_workspace" "LAW" {
  name                = "LAW-${random_pet.name.id}"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  
}


#vnets and subnets
resource "azurerm_virtual_network" "hub-vnet" {
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.RG.location
  name                = "AZ-hub-vnet"
  resource_group_name = azurerm_resource_group.RG.name
  dns_servers = ["10.0.2.4"]
  subnet {
    address_prefixes     = ["10.0.0.0/24"]
    name                 = "default"
    
  }
  subnet {
    address_prefixes     = ["10.0.1.0/24"]
    name                 = "GatewaySubnet" 
  }
  subnet {
    address_prefixes     = ["10.0.2.0/24"]
    name                 = "AzureFirewallSubnet" 
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}


#route table
resource "azurerm_route_table" "RT" {
  name                          = "all-to-fw"
  location                      = azurerm_resource_group.RG.location
  resource_group_name           = azurerm_resource_group.RG.name
  
  
  route {
    name           = "inet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.2.4"
  }
    
  route {
    name           = "toAZFWpip"
    address_prefix = "${azurerm_public_ip.azfw-pip.ip_address}/32"
    next_hop_type  = "Internet"
    
  }
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}

resource "azurerm_subnet_route_table_association" "onhubdefaultsubnet" {
  subnet_id      = azurerm_virtual_network.hub-vnet.subnet.*.id[0]
  route_table_id = azurerm_route_table.RT.id
  timeouts {
    create = "2h"
    read = "2h"
    
    delete = "2h"
  }
  
}




#Public IP's
resource "azurerm_public_ip" "azfw-pip" {
  name                = "azfw-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  allocation_method = "Static"
  sku = "Standard"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}

resource "azurerm_public_ip" "aks-pip" {
  name                = "aks-pip"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_kubernetes_cluster.aks1.node_resource_group
  allocation_method = "Static"
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}



#Azfirewall and policy
resource "azurerm_firewall_policy" "azfwpolicy" {
  name                = "azfw-policy"
  resource_group_name = azurerm_resource_group.RG.name
  location            = azurerm_resource_group.RG.location
  sku = "Premium"
  dns {
    proxy_enabled = true
    
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
}
resource "azurerm_firewall_policy_rule_collection_group" "azfwpolicyrcg" {
  name               = "azfwpolicy-rcg"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id
  priority           = 500
  network_rule_collection {
    name     = "network_rule_collection1"
    priority = 300
    action   = "Allow"
    
    rule {
      name                  = "aksudp"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["AzureCloud.${var.A-location}"]
      destination_ports     = ["1194"]
    }
    rule {
      name                  = "akstcp"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["AzureCloud.${var.A-location}"]
      destination_ports     = ["9000"]
    }
    rule {
      name                  = "time"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_fqdns     = ["ntp.ubuntu.com"]      
      destination_ports     = ["123"]
    }
  }
  application_rule_collection {
    name = "application_rule_collection"
    priority = 400
    action = "Allow"
    rule {
      name = "aksapp1"
      source_addresses = ["*"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdn_tags = ["AzureKubernetesService"]
      
    }
    rule {
      name = "aksapp2"
      source_addresses = ["10.0.0.0/16"]      
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = ["*.blob.storage.azure.net","*.blob.core.windows.net","*.microsoft.com"]
    }
    rule {
      name = "aksapp3"
      source_addresses = ["10.0.0.0/16"]      
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = ["ghcr.io", "*.docker.io", "*.docker.com","*.githubusercontent.com"]
    }
  }
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
    }
  
}
resource "azurerm_firewall" "azfw" {
  name                = "AzureFirewall"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Premium"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_virtual_network.hub-vnet.subnet.*.id[2]
    public_ip_address_id = azurerm_public_ip.azfw-pip.id
  }
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
  }
  
}
#firewall logging
resource "azurerm_monitor_diagnostic_setting" "fwlogs"{
  name = "fwlogs-${random_pet.name.id}"
  target_resource_id = azurerm_firewall.azfw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.LAW.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "AZFWNetworkRule"
  }
  enabled_log {
    category = "AZFWApplicationRule"
  }
  enabled_log {
    category = "AZFWNatRule"
  }
  enabled_log {
    category = "AZFWThreatIntel"
  }
  enabled_log {
    category = "AZFWIdpsSignature"
  }
  enabled_log {
    category = "AZFWDnsQuery"
  }
  enabled_log {
    category = "AZFWFqdnResolveFailure"
  }
  enabled_log {
    category = "AZFWFatFlow"
  }
  enabled_log {
    category = "AZFWFlowTrace"
  }
}

resource "azurerm_kubernetes_cluster" "aks1" {
  name                = "aks1"
  location            = azurerm_resource_group.RG.location
  resource_group_name = azurerm_resource_group.RG.name
  dns_prefix          = "aks1"
  node_resource_group = "aks1nodeRG"
  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_D2_v2"
    vnet_subnet_id = azurerm_virtual_network.hub-vnet.subnet.*.id[0]
    
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    outbound_type     = "userDefinedRouting"
    service_cidr = "10.99.0.0/16"
    dns_service_ip = "10.99.0.10"
    
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [ azurerm_subnet_route_table_association.onhubdefaultsubnet, azurerm_firewall_policy_rule_collection_group.azfwpolicyrcg ]
}

resource "azurerm_role_assignment" "contrib2" {
  scope = azurerm_resource_group.RG.id
  role_definition_name = "Contributor"
  principal_id  = azurerm_kubernetes_cluster.aks1.identity[0].principal_id
  depends_on = [azurerm_kubernetes_cluster.aks1]
}


provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks1.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks1.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks1.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks1.kube_config.0.cluster_ca_certificate)
}

resource "kubernetes_stateful_set" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    template {
      metadata {
        labels = {
          app = "rabbitmq"
        }
      }

      spec {
        volume {
          name = "rabbitmq-enabled-plugins"

          config_map {
            name = "rabbitmq-enabled-plugins"

            items {
              key  = "rabbitmq_enabled_plugins"
              path = "enabled_plugins"
            }
          }
        }

        container {
          name  = "rabbitmq"
          image = "mcr.microsoft.com/mirror/docker/library/rabbitmq:3.10-management-alpine"

          port {
            name           = "rabbitmq-amqp"
            container_port = 5672
          }

          port {
            name           = "rabbitmq-http"
            container_port = 15672
          }

          env {
            name  = "RABBITMQ_DEFAULT_USER"
            value = "username"
          }

          env {
            name  = "RABBITMQ_DEFAULT_PASS"
            value = "password"
          }

          resources {
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }

            requests = {
              cpu    = "10m"
              memory = "128Mi"
            }
          }

          volume_mount {
            name       = "rabbitmq-enabled-plugins"
            mount_path = "/etc/rabbitmq/enabled_plugins"
            sub_path   = "enabled_plugins"
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }

    service_name = "rabbitmq"
  }
}

resource "kubernetes_config_map" "rabbitmq_enabled_plugins" {
  metadata {
    name = "rabbitmq-enabled-plugins"
  }

  data = {
    rabbitmq_enabled_plugins = "[rabbitmq_management,rabbitmq_prometheus,rabbitmq_amqp1_0].\n"
  }
}

resource "kubernetes_service" "rabbitmq" {
  metadata {
    name = "rabbitmq"
  }

  spec {
    port {
      name        = "rabbitmq-amqp"
      port        = 5672
      target_port = "5672"
    }

    port {
      name        = "rabbitmq-http"
      port        = 15672
      target_port = "15672"
    }

    selector = {
      app = "rabbitmq"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "order_service" {
  metadata {
    name = "order-service"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "order-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "order-service"
        }
      }

      spec {
        init_container {
          name    = "wait-for-rabbitmq"
          image   = "busybox"
          command = ["sh", "-c", "until nc -zv rabbitmq 5672; do echo waiting for rabbitmq; sleep 2; done;"]

          resources {
            limits = {
              cpu    = "75m"
              memory = "128Mi"
            }

            requests = {
              cpu    = "1m"
              memory = "50Mi"
            }
          }
        }

        container {
          name  = "order-service"
          image = "ghcr.io/azure-samples/aks-store-demo/order-service:latest"

          port {
            container_port = 3000
          }

          env {
            name  = "ORDER_QUEUE_HOSTNAME"
            value = "rabbitmq"
          }

          env {
            name  = "ORDER_QUEUE_PORT"
            value = "5672"
          }

          env {
            name  = "ORDER_QUEUE_USERNAME"
            value = "username"
          }

          env {
            name  = "ORDER_QUEUE_PASSWORD"
            value = "password"
          }

          env {
            name  = "ORDER_QUEUE_NAME"
            value = "orders"
          }

          env {
            name  = "FASTIFY_ADDRESS"
            value = "0.0.0.0"
          }

          resources {
            limits = {
              cpu    = "75m"
              memory = "128Mi"
            }

            requests = {
              cpu    = "1m"
              memory = "50Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "3000"
            }

            initial_delay_seconds = 3
            period_seconds        = 3
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "3000"
            }

            initial_delay_seconds = 3
            period_seconds        = 5
            failure_threshold     = 3
          }

          startup_probe {
            http_get {
              path = "/health"
              port = "3000"
            }

            initial_delay_seconds = 20
            period_seconds        = 10
            failure_threshold     = 5
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "order_service" {
  metadata {
    name = "order-service"
  }

  spec {
    port {
      name        = "http"
      port        = 3000
      target_port = "3000"
    }

    selector = {
      app = "order-service"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "product_service" {
  metadata {
    name = "product-service"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "product-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "product-service"
        }
      }

      spec {
        container {
          name  = "product-service"
          image = "ghcr.io/azure-samples/aks-store-demo/product-service:latest"

          port {
            container_port = 3002
          }

          env {
            name  = "AI_SERVICE_URL"
            value = "http://ai-service:5001/"
          }

          resources {
            limits = {
              cpu    = "2m"
              memory = "20Mi"
            }

            requests = {
              cpu    = "1m"
              memory = "1Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "3002"
            }

            initial_delay_seconds = 3
            period_seconds        = 3
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "3002"
            }

            initial_delay_seconds = 3
            period_seconds        = 5
            failure_threshold     = 3
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "product_service" {
  metadata {
    name = "product-service"
  }

  spec {
    port {
      name        = "http"
      port        = 3002
      target_port = "3002"
    }

    selector = {
      app = "product-service"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_deployment" "store_front" {
  metadata {
    name = "store-front"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "store-front"
      }
    }

    template {
      metadata {
        labels = {
          app = "store-front"
        }
      }

      spec {
        container {
          name  = "store-front"
          image = "ghcr.io/azure-samples/aks-store-demo/store-front:latest"

          port {
            name           = "store-front"
            container_port = 8080
          }

          env {
            name  = "VUE_APP_ORDER_SERVICE_URL"
            value = "http://order-service:3000/"
          }

          env {
            name  = "VUE_APP_PRODUCT_SERVICE_URL"
            value = "http://product-service:3002/"
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "512Mi"
            }

            requests = {
              cpu    = "1m"
              memory = "200Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = "8080"
            }

            initial_delay_seconds = 3
            period_seconds        = 3
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = "8080"
            }

            initial_delay_seconds = 3
            period_seconds        = 3
            failure_threshold     = 3
          }

          startup_probe {
            http_get {
              path = "/health"
              port = "8080"
            }

            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }
        }

        node_selector = {
          "kubernetes.io/os" = "linux"
        }
      }
    }
  }
}

resource "kubernetes_service" "store_front" {
  metadata {
    name = "store-front"
  }

  spec {
    port {
      port        = 80
      target_port = "8080"
    }

    selector = {
      app = "store-front"
    }

    type = "LoadBalancer"
    load_balancer_ip = "${azurerm_public_ip.aks-pip.ip_address}" 
  }
}




resource "azurerm_firewall_policy_rule_collection_group" "azfwpolicyrcg2" {
  name               = "azfwpolicy-rcg2"
  firewall_policy_id = azurerm_firewall_policy.azfwpolicy.id
  priority           = 500
  
  
  nat_rule_collection {
    name = "dnat_rule_collection1"
    priority = 250
    action = "Dnat"
    rule {
      name = "dnat1"
      destination_address = azurerm_public_ip.azfw-pip.ip_address
      destination_ports = ["80"]
      translated_port = 80
      protocols = ["TCP","UDP"]
      source_addresses = ["*"]
      translated_address = azurerm_public_ip.aks-pip.ip_address
    }
  }
  
  
  timeouts {
    create = "2h"
    read = "2h"
    update = "2h"
    delete = "2h"
    }
  
}