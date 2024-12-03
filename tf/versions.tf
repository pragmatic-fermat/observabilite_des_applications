terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = ">= 2.8.0"
    }
  }
}

variable "do_token" {}

provider "digitalocean" {
  token = var.do_token
  ## TO BE DEFINED IN VARIABLES SETTINGS OF THE TERRAFORM WORSKPACE, AS do_token
}