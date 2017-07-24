# node.default['qemu']['current_config']['hostname'] = 'host'
node.default['qemu']['current_config']['cloud_config_path'] = "/data/cloud-init/#{node['qemu']['current_config']['hostname']}"

node.default['qemu']['current_config']['chef_interval'] = '5min'

node.default['qemu']['current_config']['chef_recipes'] = [
  "recipe[system_update::debian]",
  "recipe[dns-pod::pod_dns]",
  "recipe[haproxy-pod::pod_haproxy]",
  "recipe[kea-pod::pod_kea]",
  "recipe[keepalived-pod::pod_keepalived_haproxy]",
  "recipe[ddclient-pod::pod_ddclient]",
  "recipe[kubelet-app::kubelet]",
]

node.default['qemu']['current_config']['memory'] = 4096
node.default['qemu']['current_config']['vcpu'] = 4

node.default['qemu']['current_config']['runcmd'] = []

include_recipe "qemu-app::_cloud_config_common"
include_recipe "qemu-app::_libvirt_common"

include_recipe "qemu-app::_systemd_eth0_static"
include_recipe "qemu-app::_systemd_chef-client"

include_recipe "qemu-app::_deploy_common"