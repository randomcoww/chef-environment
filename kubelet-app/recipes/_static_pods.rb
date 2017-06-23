node['kubelet']['static_pods'].each do |f, config|
  kubernetes_pod ::File.join(node['kubernetes']['manifests_path'], f) do
    config config
    action :create
  end
end

if ::File.directory?(node['kubernetes']['manifests_path'])
  Dir.entries(node['kubernetes']['manifests_path']).each do |f|
    next if node['kubelet']['static_pods'].has_key?(f)

    path = ::File.join(node['kubernetes']['manifests_path'], f)
    next unless ::File.file?(path)

    kubernetes_pod path do
      action :delete
    end
  end
end
