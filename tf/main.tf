variable "region_name" {
  type        = string
}
variable "domain_name" {
  type        = string
}
variable "droplet_size" {
  type        = string
}
variable "droplet_image" {
  type        = string
}

variable "tag_name" {
  type        = string
}

variable "ssh_keys" {
  default = []
}

variable "root_password" {
  type      = string
  sensitive = true
}

# Mot de passe du terminal web (ttyd), communique aux participants.
variable "webshell_password" {
  type      = string
  sensitive = true
}

variable "group_count" {
    type = number
}

resource "digitalocean_tag" "tag" {
  name = var.tag_name
##  lifecycle {
##    prevent_destroy = true
##  }
}

resource "digitalocean_droplet" "clt" {
  count = var.group_count
  image  = var.droplet_image
  name   = "clt-${count.index}"
  region = var.region_name
  size   = var.droplet_size
  tags               = [digitalocean_tag.tag.id]
  monitoring         = "true"
  ssh_keys           = var.ssh_keys
  user_data = templatefile("${path.module}/cloud-init-clt.yaml", {
    root_password     = var.root_password
    webshell_password = var.webshell_password
    lab_domain        = var.domain_name
    clt_machine       = "clt-${count.index}"
  })
}

resource "digitalocean_droplet" "srv" {
  count = var.group_count
  image  = var.droplet_image
  name   = "srv-${count.index}"
  region = var.region_name
  size   = var.droplet_size
  tags               = [digitalocean_tag.tag.id]
  monitoring         = "true"
  ssh_keys           = var.ssh_keys
  user_data = templatefile("${path.module}/cloud-init-srv.yaml", {
    root_password     = var.root_password
    webshell_password = var.webshell_password
    lab_domain        = var.domain_name
    srv_machine       = "srv-${count.index}"
  })
}

resource "digitalocean_record" "clt_dns" {
  count    = var.group_count
  domain = var.domain_name
  type   = "A"
  name     = "clt-${count.index}"
  value    = digitalocean_droplet.clt[count.index].ipv4_address
  ttl    = 60
}

resource "digitalocean_record" "srv_dns" {
  count    = var.group_count
  domain = var.domain_name
  type   = "A"
  name     = "srv-${count.index}"
  value    = digitalocean_droplet.srv[count.index].ipv4_address
  ttl    = 60
}

resource "digitalocean_project" "training" {
  name        = "training"
  description = "Projet"
  purpose     = "Web Application"
  environment = "Development"
  resources = flatten([
    [for droplet in digitalocean_droplet.clt : droplet.urn],
    [for droplet in digitalocean_droplet.srv : droplet.urn]
  ])
}
