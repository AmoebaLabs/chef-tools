if node.deployment.provider
  node.default.deployment = data_bag_item('providers', node.deployment.provider).raw_data
end

group node.deployment.group do
  gid       5000
end

user node.deployment.user do
  comment   'Chef deployment user'
  uid       5000
  gid       5000
  shell     '/bin/bash'
  home      node.deployment.home
  supports  :manage_home => true
end

sudo node.deployment.user do
  user      node.deployment.user
  group     node.deployment.group
  commands  ['ALL']
  nopasswd  true
end

authorized_keys 'root' do
  user      node.deployment.user
  home      node.deployment.home
end
