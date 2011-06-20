gem "capistrano", :group => [:development]
gem "capistrano-ext", :group => [:development]
gem "rvm", :group => [:development]
gem "ruby-debug", :group => [:development]
gem "capybara", :group => [:development, :cucumber, :test]
gem "cucumber-rails", :group => [:development, :cucumber, :test]
gem "database_cleaner", :group => [:development, :cucumber, :test]
gem "jasmine", :group => [:development, :cucumber, :test]
gem "factory_girl_rails", :group => [:development, :cucumber, :test]
gem "factory_girl_generator", :group => [:development, :cucumber, :test]
gem "headless", :group => [:development, :cucumber, :test]
gem "fakeweb", :group => [:development, :cucumber, :test]
gem "pickle", :group => [:development, :cucumber, :test]
gem "haml-rails"
gem "sass"
gem "jquery-rails"
gem "launchy", :group => [:cucumber, :test]
gem "rspec-rails", :group => [:cucumber, :development, :test]
gem "spork", :group => [:cucumber, :test]
gem "hoptoad_notifier"
gem "newrelic_rpm"

generators = <<-GENERATORS

    config.generators do |g|
      g.test_framework :rspec, :fixture => true, :views => false
      g.integration_tool :rspec
    end
GENERATORS

application generators

gsub_file 'config/application.rb', 'config.filter_parameters += [:password]', 'config.filter_parameters += [:password, :password_confirmation]'

layout = <<-LAYOUT
!!!
%html
  %head
    %title #{app_name.humanize}
    = stylesheet_link_tag :all
    = javascript_include_tag :defaults
    = csrf_meta_tag
  %body
    = yield
LAYOUT

settings = <<-SETTINGS
  defaults = YAML.load(File.open(File.join(Rails.root, 'config','settings.defaults.yml')))
  settings = File.exists?(file_name = File.join(Rails.root, 'config','settings.yml')) ? YAML.load(File.open(file_name)) : {}
  settings = settings[Rails.env.to_sym] || {}
  SETTINGS = defaults.merge(setting)
SETTINGS

settings_default = <<-SETTINGS_DEFAULT
#This file has all the default settings for the app
#to override please create a settings.yml file in the same directory
#this has environment specific settings
# eg:
# :development:
SETTINGS_DEFAULT

remove_file "app/views/layouts/application.html.erb"
create_file "app/views/layouts/application.html.haml", layout
create_file "config/initializers/settings.rb", settings
create_file "config/settings.defaults.yml", settings_default

create_file "log/.gitkeep"
create_file "tmp/.gitkeep"

git :init
git :add => "."

docs = <<-DOCS

Run the following commands to complete the setup of #{app_name.humanize}:

% cd #{app_name}
% rvm use --create --rvmrc default@#{app_name}
% gem install bundler
% bundle install
% script/rails generate jquery:install
% script/rails generate rspec:install
% script/rails generate cucumber:install --rspec --capybara
% script/rails generate hoptoad --api-key your_key_here

DOCS

log docs
