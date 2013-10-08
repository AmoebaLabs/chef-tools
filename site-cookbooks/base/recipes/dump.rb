require 'json'

file "#{node.deployment.home}/node.json" do
  owner     node.deployment.user
  group     node.deployment.group
  mode      0640
  content   JSON(node.to_hash.merge(node.for_json))
end
