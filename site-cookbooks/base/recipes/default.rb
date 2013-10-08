node.packages.map{|p| package p}
%w( git ).map{|r| include_recipe r}
%w( deployer swap dump ).map {|r| include_recipe "base::#{r}"}
