node.default['qemu']['gateway2']['cloud_config_hostname'] = 'gateway2'
node.default['qemu']['gateway2']['cloud_config_path'] = "/img/cloud-init/#{node['qemu']['gateway2']['cloud_config_hostname']}"

node.default['qemu']['gateway2']['chef_recipes'] = [
  "recipe[system_update::debian]",
  "recipe[nftables-app::gateway]",
  "recipe[keepalived-app::gateway]",
  "recipe[ddclient-app::freedns]"
]

node.default['qemu']['gateway2']['systemd_config'] = {
  '/etc/systemd/network/eth0.network' => {
    "Match" => {
      "Name" => "eth0"
    },
    "Network" => {
      "LinkLocalAddressing" => "no",
      "DHCP" => "no"
    },
    "Address" => {
      "Address" => "#{node['environment_v2']['host']['gateway2']['ip_lan']}/#{node['environment_v2']['subnet']['lan'].split('/').last}"
    },
    "Route" => {
      "Gateway" => node['environment_v2']['vip']['gateway_lan'],
      "Metric" => 2048
    }
  },
  '/etc/systemd/network/eth1.network' => {
    "Match" => {
      "Name" => "eth1"
    },
    "Network" => {
      "LinkLocalAddressing" => "no",
      "DHCP" => "no"
    }
  },
  '/etc/systemd/network/eth2.network' => {
    "Match" => {
      "Name" => "eth2"
    },
    "Network" => {
      "LinkLocalAddressing" => "no",
      "DHCP" => "yes",
      "DNS" => [
        node['environment_v2']['vip']['dns_lan'],
        "8.8.8.8"
      ]
    },
    "DHCP" => {
      "UseDNS" => "false",
      "UseNTP" => "false",
      "SendHostname" => "false",
      "UseHostname" => "false",
      "UseDomains" => "false",
      "UseTimezone" => "no",
      "RouteMetric" => 1024
    }
  },
  '/etc/systemd/system/chef-client.service' => {
    "Unit" => {
      "Description" => "Chef Client daemon",
      "After" => "network.target auditd.service"
    },
    "Service" => {
      "Type" => "oneshot",
      "ExecStart" => "/usr/bin/chef-client -o #{node['qemu']['gateway2']['chef_recipes'].join(',')}",
      "ExecReload" => "/bin/kill -HUP $MAINPID",
      "SuccessExitStatus" => 3
    }
  },
  '/etc/systemd/system/chef-client.timer' => {
    "Unit" => {
      "Description" => "chef-client periodic run"
    },
    "Install" => {
      "WantedBy" => "timers.target"
    },
    "Timer" => {
      "OnStartupSec" => "1min",
      "OnUnitActiveSec" => "30min"
    }
  }
}

node.default['qemu']['gateway2']['cloud_config'] = {
  "write_files" => [],
  "password" => "password",
  "chpasswd" => {
    "expire" => false
  },
  "ssh_pwauth" => false,
  "package_upgrade" => true,
  "apt_upgrade" => true,
  "manage_etc_hosts" => true,
  "fqdn" => "#{node['qemu']['gateway2']['cloud_config_hostname']}.lan",
  "runcmd" => [
    [
      "chef-client", "-o",
      node['qemu']['gateway2']['chef_recipes'].join(',')
    ],
    "systemctl enable chef-client.timer",
    "systemctl start chef-client.timer"
  ]
}


node.default['qemu']['gateway2']['libvirt_config'] = {
  "domain"=>{
    "#attributes"=>{
      "type"=>"kvm"
    },
    "name"=>node['qemu']['gateway2']['cloud_config_hostname'],
    "memory"=>{
      "#attributes"=>{
        "unit"=>"GiB"
      },
      "#text"=>"1"
    },
    "currentMemory"=>{
      "#attributes"=>{
        "unit"=>"GiB"
      },
      "#text"=>"1"
    },
    "vcpu"=>{
      "#attributes"=>{
        "placement"=>"static"
      },
      "#text"=>"1"
    },
    "iothreads"=>"1",
    "iothreadids"=>{
      "iothread"=>{
        "#attributes"=>{
          "id"=>"1"
        }
      }
    },
    "os"=>{
      "type"=>{
        "#attributes"=>{
          "arch"=>"x86_64",
          "machine"=>"pc"
        },
        "#text"=>"hvm"
      },
      "boot"=>{
        "#attributes"=>{
          "dev"=>"hd"
        }
      }
    },
    "features"=>{
      "acpi"=>"",
      "apic"=>"",
      "pae"=>""
    },
    "cpu"=>{
      "#attributes"=>{
        "mode"=>"host-passthrough"
      },
      "topology"=>{
        "#attributes"=>{
          "sockets"=>"1",
          "cores"=>"1",
          "threads"=>"1"
        }
      }
    },
    "clock"=>{
      "#attributes"=>{
        "offset"=>"utc"
      }
    },
    "on_poweroff"=>"destroy",
    "on_reboot"=>"restart",
    "on_crash"=>"restart",
    "devices"=>{
      "emulator"=>"/usr/bin/qemu-system-x86_64",
      "disk"=>{
        "#attributes"=>{
          "type"=>"file",
          "device"=>"disk"
        },
        "driver"=>{
          "#attributes"=>{
            "name"=>"qemu",
            "type"=>"qcow2",
            "iothread"=>"1"
          }
        },
        "source"=>{
          "#attributes"=>{
            "file"=>"/img/kvm/#{node['qemu']['gateway2']['cloud_config_hostname']}.qcow2"
          }
        },
        "target"=>{
          "#attributes"=>{
            "dev"=>"vda",
            "bus"=>"virtio"
          }
        }
      },
      "controller"=>[
        {
          "#attributes"=>{
            "type"=>"usb",
            "index"=>"0",
            "model"=>"none"
          }
        },
        {
          "#attributes"=>{
            "type"=>"pci",
            "index"=>"0",
            "model"=>"pci-root"
          }
        }
      ],
      "filesystem"=>[
        {
          "#attributes"=>{
            "type"=>"mount",
            "accessmode"=>"squash"
          },
          "source"=>{
            "#attributes"=>{
              "dir"=>"/img/secret/chef"
            }
          },
          "target"=>{
            "#attributes"=>{
              "dir"=>"chef-secret"
            }
          },
          "readonly"=>""
        },
        {
          "#attributes"=>{
            "type"=>"mount",
            "accessmode"=>"squash"
          },
          "source"=>{
            "#attributes"=>{
              "dir"=>node['qemu']['gateway2']['cloud_config_path']
            }
          },
          "target"=>{
            "#attributes"=>{
              "dir"=>"cloud-init"
            }
          },
          "readonly"=>""
        }
      ],
      "interface"=>[
        {
          "#attributes"=>{
            "type"=>"direct",
            "trustGuestRxFilters"=>"yes"
          },
          "source"=>{
            "#attributes"=>{
              "dev"=>node['environment_v2']['current_host']['if_lan'],
              "mode"=>"bridge"
            }
          },
          "model"=>{
            "#attributes"=>{
              "type"=>"virtio-net"
            }
          }
        },
        {
          "#attributes"=>{
            "type"=>"direct"
          },
          "source"=>{
            "#attributes"=>{
              "dev"=>node['environment_v2']['current_host']['if_vpn'],
              "mode"=>"bridge"
            }
          },
          "model"=>{
            "#attributes"=>{
              "type"=>"virtio-net"
            }
          }
        },
        {
          "#attributes"=>{
            "type"=>"direct"
          },
          "mac"=>{
            "#attributes"=>{
              "address"=>node['environment_v2']['host']['gateway2']['mac_wan']
            }
          },
          "source"=>{
            "#attributes"=>{
              "dev"=>node['environment_v2']['current_host']['if_wan'],
              "mode"=>"bridge"
            }
          },
          "model"=>{
            "#attributes"=>{
              "type"=>"virtio-net"
            }
          }
        }
      ],
      "serial"=>{
        "#attributes"=>{
          "type"=>"pty"
        },
        "target"=>{
          "#attributes"=>{
            "port"=>"0"
          }
        }
      },
      "console"=>{
        "#attributes"=>{
          "type"=>"pty"
        },
        "target"=>{
          "#attributes"=>{
            "type"=>"serial",
            "port"=>"0"
          }
        }
      },
      "input"=>[
        {
          "#attributes"=>{
            "type"=>"mouse",
            "bus"=>"ps2"
          }
        },
        {
          "#attributes"=>{
            "type"=>"keyboard",
            "bus"=>"ps2"
          }
        }
      ],
      "memballoon"=>{
        "#attributes"=>{
          "model"=>"virtio"
        }
      }
    }
  }
}
