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

module "network" {
  source  = "codectl/vnet/azure"
  version = "~> 1.0"


  vnet = {
    name                = module.naming.virtual_network.name
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    address_space       = ["10.18.0.0/16"]

    subnets = {
      db = {
        address_prefixes = ["10.18.1.0/24"]
      }
      cache = {
        address_prefixes = ["10.18.2.0/24"]
      }
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

module "aks" {
  source  = "codectl/aks/azure"
  version = "~> 1.0"

  keyvault = module.kv.vault.id

  cluster = {
    name                = module.naming.kubernetes_cluster.name_unique
    location            = module.rg.groups.demo.location
    resource_group_name = module.rg.groups.demo.name
    dns_prefix          = "demo"
    profile             = "linux"

    generate_ssh_key = {
      enable = true
    }

    identity = {
      type         = "UserAssigned"
      identity_ids = [module.identity.identity.id]
    }

    default_node_pool = {
      vnet_subnet_id = module.network.subnets.db.id
      upgrade_settings = {
        max_surge = "10%"
      }
    }

    node_pools = {
      db = {
        vnet_subnet_id = module.network.subnets.db.id
        node_count     = 1
        zones          = [1]
        mode           = "User"
        os_type        = "Linux"

        kubelet_config = {
          pod_max_pid = 110
        }

        node_labels = {
          "workload" = "database"
        }
      }
      cache = {
        vnet_subnet_id = module.network.subnets.cache.id
        node_count     = 1
        zones          = [1]
        os_type        = "Linux"

        node_labels = {
          "workload" = "cache"
        }
      }
    }
  }
  depends_on = [module.kv]
}
