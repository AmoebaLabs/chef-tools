%w( capistrano javascript rvm db nginx unicorn ssh init foreman cron ).map {|r| include_recipe "app::#{r}"}
