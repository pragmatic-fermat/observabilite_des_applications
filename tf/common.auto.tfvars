# DigitalOcean API token
## do_token = 
# Region where resources should be created
region_name = "ams3"
# Droplet size
droplet_size = "s-4vcpu-8gb-intel"
##droplet_size = "s-2vcpu-2gb"
droplet_image = "docker-20-04"
##tag_name = 

## TO BE CUSTOMIZED BY YOUR NEEDS ###
##domain_name = 
ssh_keys = [ "24566267" ]

# Plage dont chaque groupe tire son /24 de VPC (groupe N : 10.20.N.0/24).
vpc_base_range = "10.20.0.0/16"

##
##group_count = 1