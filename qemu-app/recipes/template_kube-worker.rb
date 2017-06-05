# node.default['qemu']['current_config']['hostname'] = 'host'
node.default['qemu']['current_config']['cloud_config_path'] = "/img/cloud-init/#{node['qemu']['current_config']['hostname']}"

node.default['qemu']['current_config']['chef_interval'] = '30min'
node.default['qemu']['current_config']['chef_recipes'] = [
  "recipe[system_update::debian]",
  "recipe[kubernetes-app::_worker]",
]

node.default['qemu']['current_config']['memory'] = 4
node.default['qemu']['current_config']['vcpu'] = 2

node.default['qemu']['current_config']['runcmd'] = [
  "apt-get -y install apt-transport-https ca-certificates gnupg2 dirmngr",
  "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D",

  "echo deb https://apt.dockerproject.org/repo debian-stretch main > /etc/apt/sources.list.d/docker.list",
  "echo deb http://deb.debian.org/debian sid main contrib non-free > /etc/apt/sources.list.d/sid.list",
  "apt-get -y update"
]

include_recipe "qemu-app::_cloud_config_common"
include_recipe "qemu-app::_libvirt_common"
include_recipe "qemu-app::_systemd_common"
include_recipe "qemu-app::_deploy_common"
