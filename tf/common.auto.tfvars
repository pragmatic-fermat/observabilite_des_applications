# DigitalOcean API token
## do_token = 
# Resources will be prefixed with this to avoid clashing names
prefix = "seoa"
# Region where resources should be created
region_name = "ams3"
# Droplet size
droplet_size = "s-4vcpu-8gb-intel"
##droplet_size = "s-2vcpu-2gb"
droplet_image = "docker-20-04"
tag_name = "seoa"

## TO BE CUSTOMIZED BY YOUR NEEDS ###
domain_name = "monlab.top"
ssh_keys = [ "2260515" ]

##
variable "grp_count" {
  description = "Nombre de grp"
  type        = number
  default     = 1
}