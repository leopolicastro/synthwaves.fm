Rails.application.config.generators do |g|
  g.test_framework :rspec,
    fixtures: false,
    view_specs: false,
    helper_specs: false,
    routing_specs: false,
    request_specs: true,
    controller_specs: false,
    model_specs: true

  g.helper = false
  g.assets = false
  g.fixture_replacement :factory_bot, dir: 'spec/factories'
end
