variable "tunnels" {
  default = {}
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

output tunnels {
    value = local.tunnels
}

locals {
    tunnels = {for name, tunnel in var.tunnels: name => merge({name = name}, tunnel)}
        
    namespaces = distinct([for name, tunnel in local.tunnels: tunnel.local.namespace])
    create_namespaces = distinct([for name, tunnel in local.tunnels: tunnel.local.namespace if lookup(tunnel.local, "create_namespace", false)])
}

resource kubernetes_namespace ns {
    count = length(local.create_namespaces)
    metadata {
        name = local.create_namespaces[count.index]
    }
}

resource "helm_release" "client" { 
    for_each = local.tunnels
    depends_on = [kubernetes_namespace.ns, kubernetes_secret.ssh]
    
    name       = each.value.name 
    namespace  = each.value.local.namespace
    chart = local.stackd.chart_path
    version = var.chart_version
  
  values = [
    yamlencode({
      tunnel = each.value,
    }),
    yamlencode({
      image = {
        tag = var.chart_version
      }
      nodeSelector = var.nodeSelector
      tolerations = var.tolerations
      tunnel = {
        enabled = true
      }
    })
  ]

}

// save ssh key to vault
resource "tls_private_key" "ssh" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "vault_generic_secret" "ssh" {
  path = "${local.stackd.module_secret}/ssh"
  data_json = jsonencode({
    id_ecdsa = tls_private_key.ssh.private_key_openssh
    "id_ecdsa.pub"  = tls_private_key.ssh.public_key_openssh
  })
}

data vault_generic_secret ssh {
    depends_on = [vault_generic_secret.ssh]
  path = "${local.stackd.module_secret}/ssh"
}

// create kubernetes secret in every namespace

resource kubernetes_secret ssh {
    count = length(local.namespaces)
    metadata {
        name = "sshts-client"
        namespace = local.namespaces[count.index]
    }

    data = data.vault_generic_secret.ssh.data
}