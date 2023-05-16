

resource "hcloud_load_balancer_service" "sshts" {  
  load_balancer_id = var.sys_nodes.master_lb_id
  protocol         = "tcp"
  listen_port      = 32222
  destination_port = 32222
}