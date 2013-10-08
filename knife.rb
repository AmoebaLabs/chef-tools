base = File.expand_path('..', __FILE__)
nodes_path                File.join(base, 'nodes')
role_path                 File.join(base, 'roles')
data_bag_path             File.join(base, 'data_bags')
cookbook_path             %w(site-cookbooks cookbooks).map {|d| File.join(base, d)}
