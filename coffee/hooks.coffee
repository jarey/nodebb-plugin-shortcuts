#module.exports.addAdminNavigation = Route.addAdminNavigations plugin

module.exports.init = (app, middleware, ignored) ->
#  Route.templateAdmin app, middleware, plugin.adminPage.route
  initSockets()

module.exports.pluginActivation = (id) ->
  cfg.setOnEmpty() if id == plg.id