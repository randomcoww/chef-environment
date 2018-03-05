base = {
  "passwd" => {
    "users" => [
      {
        "name" => "core",
        # "passwordHash" => "$6$c6en5k51$fJnDYVaIDbasJQNWo.ezDdX4zfW9jsVlZAQwztQbMvRVUei/iGfGzBlhxqCAWCI6kAkrQLwy2Yr6D9HImPWWU/",
        "sshAuthorizedKeys" => node['environment_v2']['ssh_authorized_keys']['default']
      }
    ]
  }
}


cert_generator = OpenSSLHelper::CertGenerator.new(
  'deploy_config', 'kubernetes_ssl', [['CN', 'kube-ca']]
)
ca = cert_generator.root_ca


etcd_cert_generator = OpenSSLHelper::CertGenerator.new(
  'deploy_config', 'etcd_ssl', [['CN', 'etcd-ca']]
)
etcd_ca = etcd_cert_generator.root_ca


kube_config = {
  "apiVersion" => "v1",
  "kind" => "Config",
  "clusters" => [
    {
      "name" => node['kubernetes']['cluster_name'],
      "cluster" => {
        "server" => "http://127.0.0.1:#{node['kubernetes']['insecure_port']}"
      }
    }
  ],
  "users" => [
    {
      "name" => "kube",
    }
  ],
  "contexts" => [
    {
      "name" => "kube-context",
      "context" => {
        "cluster" => node['kubernetes']['cluster_name'],
        "user" => "kube"
      }
    }
  ],
  "current-context" => "kube-context"
}


cni_conf = JSON.pretty_generate(node['kubernetes']['cni_conf'].to_hash)
flannel_cfg = JSON.pretty_generate(node['kubernetes']['flanneld_conf'].to_hash)


node['environment_v2']['set']['dns']['hosts'].uniq.each do |host|

  ip = node['environment_v2']['host'][host]['ip']['store']

  ##
  ## etcd ssl
  ##
  etcd_key = etcd_cert_generator.generate_key
  etcd_cert = etcd_cert_generator.node_cert(
    [
      ['CN', "etcd-#{host}"]
    ],
    etcd_key,
    {
      "basicConstraints" => "CA:FALSE",
      "keyUsage" => 'nonRepudiation, digitalSignature, keyEncipherment',
    },
    {}
  )

  ##
  ## kube ssl
  ##
  key = cert_generator.generate_key
  cert = cert_generator.node_cert(
    [
      ['CN', "kube-#{host}"]
    ],
    key,
    {
      "basicConstraints" => "CA:FALSE",
      "keyUsage" => 'nonRepudiation, digitalSignature, keyEncipherment',
    },
    {
      'DNS.1' => 'kubernetes',
      'DNS.2' => 'kubernetes.default',
      'DNS.3' => 'kubernetes.default.svc',
      'DNS.4' => "kubernetes.default.svc.#{node['kubernetes']['cluster_domain']}",
      'IP.1' => node['kubernetes']['cluster_service_ip'],
      'IP.2' => node['environment_v2']['set']['haproxy']['vip']['store'],
      'IP.3' => ip
    }
  )

  directories = []

  files = [
    {
      "path" => "/etc/hostname",
      "mode" => 420,
      "contents" => "data:,#{host}"
    },
    ## flannel
    {
      "path" => node['kubernetes']['flanneld_conf_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(flannel_cfg)}"
    },
    {
      "path" => node['kubernetes']['cni_conf_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(cni_conf)}"
    },
    ## kube ssl
    {
      "path" => node['kubernetes']['key_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(key.to_pem)}"
    },
    {
      "path" => node['kubernetes']['cert_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(cert.to_pem)}"
    },
    {
      "path" => node['kubernetes']['ca_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(ca.to_pem)}"
    },
    ## kubeconfig
    {
      "path" => node['kubernetes']['client']['kubeconfig_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(kube_config.to_hash.to_yaml)}"
    },
    ## etcd ssl
    {
      "path" => node['etcd']['key_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(etcd_key.to_pem)}"
    },
    {
      "path" => node['etcd']['cert_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(etcd_cert.to_pem)}"
    },
    {
      "path" => node['etcd']['ca_path'],
      "mode" => 420,
      "contents" => "data:;base64,#{Base64.encode64(etcd_ca.to_pem)}"
    },
  ]


  networkd = []

  interfaces = node['environment_v2']['host'][host]['if'].to_hash.dup

  interfaces.each do |i, interface|

    addr = node['environment_v2']['host'][host]['ip'][i]
    gw = node['environment_v2']['host'][host]['gw'][i]

    if !interface.nil? &&
      !addr.nil? &&
      !gw.nil?

      subnet_mask = node['environment_v2']['subnet'][i].split('/').last

      networkd << {
        "name" => "#{interface}.network",
        "contents" => {
          "Match" => {
            "Name" => interface
          },
          "Network" => {
            "LinkLocalAddressing" => "no",
            "DHCP" => "no",
            "DNS" => [
              '127.0.0.1',
              '8.8.8.8'
            ]
          },
          "Address" => {
            "Address" => "#{addr}/#{subnet_mask}"
          },
          "Route" => {
            "Gateway" => gw,
            "Metric" => 2048
          }
        }
      }
    end
  end

  systemd = [
    {
      "name" => "kubelet.service",
      "contents" => {
        "Service" => {
          "Environment" => [
            "KUBELET_IMAGE_TAG=v#{node['kubernetes']['version']}_coreos.0",
            %Q{RKT_RUN_ARGS="#{[
              "--uuid-file-save=/var/run/kubelet-pod.uuid",
              "--volume var-log,kind=host,source=/var/log",
              "--mount volume=var-log,target=/var/log",
              "--volume dns,kind=host,source=/etc/resolv.conf",
              "--mount volume=dns,target=/etc/resolv.conf"
            ].join(' ')}"}
          ],
          "ExecStartPre" => [
            "/usr/bin/mkdir -p /etc/kubernetes/manifests",
            "/usr/bin/mkdir -p /var/log/containers",
            "-/usr/bin/rkt rm --uuid-file=/var/run/kubelet-pod.uuid"
          ],
          "ExecStart" => [
            "/usr/lib/coreos/kubelet-wrapper",
            "--register-node=true",
            "--cni-conf-dir=#{::File.dirname(node['kubernetes']['cni_conf_path'])}",
            "--network-plugin=cni",
            "--container-runtime=docker",
            "--allow-privileged=true",
            "--manifest-url=#{node['environment_v2']['url']['manifests']}/#{host}",
            "--hostname-override=#{ip}",
            "--cluster_dns=#{node['kubernetes']['cluster_dns_ip']}",
            "--cluster_domain=#{node['kubernetes']['cluster_domain']}",
            "--kubeconfig=#{node['kubernetes']['client']['kubeconfig_path']}",
            "--docker-disable-shared-pid=false",
            "--image-gc-high-threshold=0",
            "--image-gc-low-threshold=0",
            # "--feature-gates=CustomPodDNS=true"
          ].join(' '),
          "ExecStop" => "-/usr/bin/rkt stop --uuid-file=/var/run/kubelet-pod.uuid",
          "Restart" => "always",
          "RestartSec" => 10
        },
        "Install" => {
          "WantedBy" => "multi-user.target"
        }
      }
    }
  ]

  node.default['ignition']['configs'][host] = {
    'base' => base,
    'files' => files,
    'directories' => directories,
    'networkd' => networkd,
    'systemd' => systemd
  }

end
