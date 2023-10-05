resource kubernetes_namespace ns {    
    metadata {
        name = local.stackd.namespace
    }
}

variable run_on_control_plain {
  default = false
  type        = bool  
  description = "Run on control plain"
}

variable server_authorized_keys {
  default = []
  
  description = "Authorized keys for server"
}
variable "chart_version" {
  default = "0.0.11"
}

variable nodeSelector {
  default = {}
}

variable "tolerations" {
  default = []
}
  


locals {
  
  vault_secrets = lookup(var.server_authorized_keys, "vault", [])
  vault_keys = [for i,s in local.vault_secrets: data.vault_generic_secret.authorized_key[i].data[s.key]]
  static_keys = lookup(var.server_authorized_keys, "static", [])

  authorized_keys = join("\n", concat(
    local.static_keys,
    local.vault_keys,
  ))
}

output authorized_keys {
  value       = local.authorized_keys
  sensitive   = true  
}


data vault_generic_secret authorized_key {
  count = length(local.vault_secrets)
  path = local.vault_secrets[count.index].path
}


resource kubernetes_secret authorized_keys {
  metadata {
    name = "sshts-authorized-keys"
    namespace = local.stackd.namespace
  }

  data = {
    "authorized_keys" = local.authorized_keys
  }
}


resource "helm_release" "server" { 
    depends_on = [kubernetes_namespace.ns]    
    name       = local.stackd.service
    namespace  = local.stackd.namespace
    chart = local.stackd.chart_path
    version = var.chart_version
  values = [
    yamlencode({
      image = {
        tag = var.chart_version
      }
      nodeSelector = var.nodeSelector
      tolerations = var.tolerations
      server = {
        enabled = true
        run_on_control_plain = var.run_on_control_plain
      }
    })
  ]

}