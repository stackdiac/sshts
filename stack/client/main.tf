variable "tunnels" {
  type = any
}

output tunnels {
    value = var.tunnels
}

locals {
    namespaces = distinct([for tunnel in var.tunnels: tunnel.local.namespace])
}

resource kubernetes_namespace ns {
    count = length(local.namespaces)
    metadata {
        name = local.namespaces[count.index]
    }
}

resource "helm_release" "client" { 
    depends_on = [kubernetes_namespace.ns]
    count = length(var.tunnels)
    name       = var.tunnels[count.index].name 
    namespace  = var.tunnels[count.index].local.namespace
    chart = local.stackd.chart_path
  
  values = [
    yamlencode({
      tunnel = var.tunnels[count.index]
    }),
    yamlencode({
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