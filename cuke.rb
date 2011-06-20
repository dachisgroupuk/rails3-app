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

puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts "Initial setup"
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

# Delete unnecessary files
run "rm public/index.html"
#run "rm public/favicon.ico"
run "rm public/images/rails.png"
run 'rm README'
run 'touch README'

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
git :commit => "-a -m 'Initial commit'"

puts "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
puts "Capify application"
puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

if yes?("\nWill you be using Capistrano to deploy your application?(y/n)")
  capify!
  file "config/deploy.rb", <<-EOF
# USAGE: cap staging/production CAPISTRANO TASK
# Example: cap staging deploy:setup

require 'capistrano/ext/multistage'
require "rvm/capistrano"

set :application, "set your application name here"
set :repository,  "git@github.com:headshift/#{application}.git"
set :user, "rails"
set :group, "rails"

set :scm, :git
set :branch, 'master'
set :use_sudo, false
default_run_options[:pty] = true
ssh_options[:forward_agent] = true
set :deploy_via, :remote_cache
set :git_shallow_clone, 1
set :git_enable_submodules, 1

set :rvm_type, :user
set :rvm_ruby_string, "ree@#{application}"

set :sql_user, 'deploy'     # User which will have all permission on above database
set :sql_pass, 'deploy'     # Password for above user

desc "this task will set credentials for staging server"
task :staging do
  role :web, "your web-server here"  # Your HTTP server, Apache/etc
  role :app, "your app-server here"   # This may be the same as your `Web` server
  role :db,  "your primary db-server here", :primary => true   # This is where Rails migrations will run
  role :db,  "your slave db-server here"

  set :domain, 'set your staging domain name here'
  set :rails_env, :staging
  set :application, "set your staging application name here"
  set :deploy_to, "/home/#{'#{ user }'}/websites/#{ '#{ application }' }"
  set :database, "#{'#{ application }' }"
end

desc "this task will set credentials for beta site"
task :production do
  role :web, "your web-server here"  # Your HTTP server, Apache/etc
  role :app, "your app-server here"   # This may be the same as your `Web` server
  role :db,  "your primary db-server here", :primary => true   # This is where Rails migrations will run
  role :db,  "your slave db-server here"

  set :rails_env, :production
  set :domain, 'set your production domain name here'
  set :application, "set your production application name here"
  set :deploy_to, "/home/#{ '#{ user }' }/websites/#{ '#{ application }' }"
  set :database, "#{ '#{ application }' }"
end


namespace :bundler do
  desc "run bundle install to install required gems"
  task :install, :roles => :app, :except => { :no_release => true } do
    run "cd #{ '#{release_path}' } && bundle install --without development test cucumber"
  end
end

namespace :deploy do

  desc "create database.yml in capistrano shared directory."
  task :create_database_yml, :roles => :app do
db = <<-CMD
production:
  adapter: mysql
  database: #{ '#{ database }' }
  username: #{ '#{ sql_user }' }
  password: #{ '#{ sql_pass }' }
  host: localhost
  encoding: utf8
CMD
     put db, "#{  '#{ shared_path }' }/database.yml"
  end

  desc "Restarting mod_rails with restart.txt"
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{ '#{ current_path  }' }/tmp/restart.txt"
  end

  [:start, :stop].each do |t|
    desc "#{ '#{ t }' } task is a no-op with mod_rails"
    task t, :roles => :app do ; end
  end

  task :after_symlink, :roles => :app do
    run "ln -nfs #{ '#{ shared_path }' }/database.yml #{ '#{ current_path }' }/config/database.yml"
  end

  task :after_setup, :roles => :app do
    transaction do
      create_database_yml
      db_setup
    end
  end

  desc "Long deploy will throw up the maintenance.html page and run migrations then it restarts and enables the site again."
  task :long do
    transaction do
      update_code
      web.disable
      symlink
      migrate
      bundler:install
    end
    restart
    web.enable
    cleanup
  end

  desc "create a DB named :database, grant permission to a user :sql_user with password :sql_pass"
  task :db_setup , :roles => :app do
    sudo "mysqladmin create #{ '#{ database }' } -uUSERNAME -pPASSWORD"
    sudo "mysql -uUSERNAME -pPASSWORD -e \\"grant all on #{ '#{ database }' }.* to #{ '#{ sql_user }'  }@localhost identified by '#{ '#{ sql_pass }' }' \\" "
    puts "#####################################################################\\n"
    puts "Databases '#{ '#{ database }' }' created:"
    puts "User    : '#{ '#{ sql_user }' }'"
    puts "Password: '#{ '#{ sql_pass }' }'"
    puts "\\n#####################################################################"
  end

end

task :export do
  remote_branch = "origin/#{branch}"
  filename = "#{branch}-to-deploy.tgz"
  
  system "git archive --format tar origin/#{branch} | gzip >#{filename}"
  puts "Branch #{remote_branch} exported as file #{filename}"
end

EOF

  git :add => "."
  git :commit => "-a -m 'application capified'"
end


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
