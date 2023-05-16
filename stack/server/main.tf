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

locals {
  vault_secrets = [for k in var.server_authorized_keys: k if lookup(k, "vault", null) != null]
  vault_keys = [for i,s in local.vault_secrets: data.vault_generic_secret.authorized_key[i].data[s.key]]
  static_keys = flatten([for k in var.server_authorized_keys: k.static if lookup(k, "static", null) != null])


  authorized_keys = join("\n", concat(
    local.static_keys,
    local.vault_keys,
  ))
}

data vault_generic_secret authorized_key {
  count = length(local.vault_secrets)
  path = local.vault_secrets[0].vault
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
  
  values = [
    yamlencode({
      server = {
        enabled = true
        run_on_control_plain = var.run_on_control_plain
      }
    })
  ]

}