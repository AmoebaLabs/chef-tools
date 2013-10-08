if app.ci == 'jenkins'
  override.jenkins.server.home = "#{app.path}/jenkins"
  override.jenkins.server.user = app.user.name

  override.application.database.environments.test = {
    name: app.database.name + '_test'
  }
end
