module "naming" {
  source  = "codectl/naming/azure"
  version = "~> 0.1"

  suffix = ["demo", "dev"]
}

module "regions" {
  source  = "codectl/locations/azure"
  version = "~> 1.0"

  location = {
    primary = "sweden central"
  }
}

module "rg" {
  source  = "codectl/rg/azure"
  version = "~> 1.0"

  groups = {
    demo = {
      name     = module.naming.resource_group.name_unique
      location = module.regions.location.primary.name
    }
  }
}

module "identity" {
  source  = "codectl/uai/azure"
  version = "~> 1.0"

  identity = {
    name                = module.naming.user_assigned_identity.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "kv" {
  source  = "codectl/kv/azure"
  version = "~> 1.0"

  vault = {
    name                = module.naming.key_vault.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
  }
}

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"

  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      nodes = {
        network_security_group = {}
        address_prefixes       = ["10.18.1.0/24"]
      }
    }
  }
}

module "aks" {
  source  = "codectl/aks/azure"
  version = "~> 1.0"

  keyvault = module.kv.vault.id

  cluster = {
    name                = module.naming.kubernetes_cluster.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    profile             = "linux"
    dns_prefix          = "demo"

    generate_ssh_key = {
      enable = true
    }

    identity = {
      type         = "UserAssigned"
      identity_ids = [module.identity.identity.id]
    }

    default_node_pool = {
      vm_size        = "Standard_DS2_v2"
      vnet_subnet_id = module.network.subnets.nodes.id
    }

    network_profile = {
      network_plugin      = "azure"
      network_plugin_mode = "overlay"
      outbound_type       = "loadBalancer"

      load_balancer_profile = {
        managed_outbound_ip_count = 2
        idle_timeout_in_minutes   = 10
      }
    }
  }
  depends_on = [module.kv]
}
