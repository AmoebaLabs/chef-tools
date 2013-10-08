job_config = File.join(app.config_path, "jenkins-config.xml")

jenkins_job app.name do
  action :nothing
  config job_config
end

template job_config do
  source 'jenkins/build-config.xml.erb'
  mode 0644
  owner app.user.name
  notifies :update, resources(jenkins_job: app.name), :immediately
  notifies :build,  resources(jenkins_job: app.name), :immediately
  action :create_if_missing
end

include_recipe 'jenkins::server'
jenkins_commands = service_commands('jenkins')
monitrc 'jenkins' do
  template_source   'monit/jenkins.conf.erb'
  template_cookbook 'app'
  variables jenkins_commands
end
