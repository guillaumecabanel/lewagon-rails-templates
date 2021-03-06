run "pgrep spring | xargs kill -9"

# GEMFILE
########################################
run "rm Gemfile"
file 'Gemfile', <<-RUBY
source 'https://rubygems.org'
ruby '#{RUBY_VERSION}'

gem 'rails', '#{Rails.version}'
gem 'puma'
gem 'pg'
gem 'figaro'
gem 'jbuilder', '~> 2.0'
gem 'devise'
gem 'redis'

gem 'sass-rails'
gem 'jquery-rails'
gem 'uglifier'
gem 'semantic-ui-sass', git: 'https://github.com/doabit/semantic-ui-sass.git'
gem 'font-awesome-sass'
gem 'simple_form'
gem 'autoprefixer-rails'

group :development, :test do
  gem 'binding_of_caller'
  gem 'better_errors'
  #{Rails.version >= "5" ? nil : "gem 'quiet_assets'"}
  gem 'pry-byebug'
  gem 'pry-rails'
  gem 'spring'
  #{Rails.version >= "5" ? "gem 'listen', '~> 3.0.5'" : nil}
  #{Rails.version >= "5" ? "gem 'spring-watcher-listen', '~> 2.0.0'" : nil}
end

#{Rails.version < "5" ? "gem 'rails_12factor', group: :production" : nil}
RUBY

# Ruby version
########################################
file ".ruby-version", RUBY_VERSION

# Procfile
########################################
file 'Procfile', <<-YAML
web: bundle exec puma -C config/puma.rb
YAML

# Puma conf file
########################################
if Rails.version < "5"
  puma_file_content = <<-RUBY
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }.to_i

threads     threads_count, threads_count
port        ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }
RUBY

  file 'config/puma.rb', puma_file_content, force: true
end

# Clevercloud conf file
########################################
file 'clevercloud/ruby.json', <<-EOF
{
  "deploy": {
    "env": "production",
    "rakegoals": ["assets:precompile", "db:migrate"],
    "static": "/public"
  }
}
EOF

# Database conf file
########################################
inside 'config' do
  database_conf = <<-EOF
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: #{app_name}_development

test:
  <<: *default
  database: #{app_name}_test

production:
  adapter:  postgresql
  encoding: utf8
  poll:     10
  host:     <%= ENV['POSTGRESQL_ADDON_HOST'] %>
  port:     <%= ENV['POSTGRESQL_ADDON_PORT'] %>
  database: <%= ENV['POSTGRESQL_ADDON_DB'] %>
  username: <%= ENV['POSTGRESQL_ADDON_USER'] %>
  password: <%= ENV['POSTGRESQL_ADDON_PASSWORD'] %>
EOF
  file 'database.yml', database_conf, force: true
end

# Assets
########################################
run "rm -rf app/assets/stylesheets"
run "curl -L https://github.com/guillaumecabanel/stylesheets/raw/master/stylesheets.zip > stylesheets.zip"
run "unzip stylesheets.zip -d app/assets && rm stylesheets.zip"

run 'rm app/assets/javascripts/application.js'
file 'app/assets/javascripts/application.js', <<-JS
//= require jquery
//= require jquery_ujs
// Loads all Semantic javascripts
//= require semantic-ui
//= require_tree .
JS

file 'app/assets/javascripts/flashes.js', <<-JS
// Close dismissable ui messages
$('.message .close')
  .on('click', function() {
    $(this)
      .closest('.message')
      .transition('fade')
    ;
  })
;

JS

# Dev environment
########################################
gsub_file('config/environments/development.rb', /config\.assets\.debug.*/, 'config.assets.debug = false')

# Layout
########################################
run 'rm app/views/layouts/application.html.erb'
file 'app/views/layouts/application.html.erb', <<-HTML
<!DOCTYPE html>
<html>
  <head>
    <title>TODO</title>
    <%= csrf_meta_tags %>
    #{Rails.version >= "5" ? "<%= action_cable_meta_tag %>" : nil}
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <%= stylesheet_link_tag    'application', media: 'all' %>
  </head>
  <body>
    <%= render 'shared/navbar' %>
    <%= render 'shared/flashes' %>

    <div class="ui container">
      <%= yield %>
    </div>

    <%= javascript_include_tag 'application' %>
  </body>
</html>
HTML

file 'app/views/shared/_flashes.html.erb', <<-HTML
<% if notice %>
  <div class="ui info message">
    <i class="close icon"></i>
    <p><%= notice %></p>
  </div>
<% end %>

<% if alert %>
  <div class="ui warning message">
    <i class="close icon"></i>
    <p><%= alert %></p>
  </div>
<% end %>
HTML

# README
########################################
markdown_file_content = <<-MARKDOWN
Rails app generated with [guillaumecabanel/rails-templates](https://github.com/guillaumecabanel/rails-templates) inspired by the [lewagon/rails-templates](https://github.com/lewagon/rails-templates), created by the [Le Wagon coding bootcamp](https://www.lewagon.com) team.
MARKDOWN
file 'README.md', markdown_file_content, force: true

# Generators
########################################
generators = <<-RUBY
  config.generators do |generate|
    generate.assets false
    generate.helper false
  end
RUBY

environment generators

# AFTER BUNDLE
########################################
after_bundle do
  # Generators: db + simple form + pages controller
  ########################################
  rake 'db:drop db:create db:migrate'
  rake 'db:migrate'
  generate('simple_form:install')
  generate(:controller, 'pages', 'home', '--no-helper', '--no-assets', '--skip-routes')

  # Config simple form with Semantic ui
  # run "rm -rf config/initializers/simple_form_bootstrap.rb"
  run "rm -rf config/initializers/simple_form.rb"
  run "curl -L https://raw.githubusercontent.com/guillaumecabanel/lewagon-rails-templates/master/simple_form.rb > config/initializers/simple_form.rb"


  # Routes
  ########################################
  route "root to: 'pages#home'"

  # Git ignore
  ########################################
  run "rm .gitignore"
  file '.gitignore', <<-TXT
.bundle
.clever.json
log/*.log
tmp/**/*
tmp/*
*.swp
.DS_Store
public/assets
TXT

  # Devie install + user
  ########################################
  generate('devise:install')
  generate('devise', 'User')

  # App controller
  ########################################
  run 'rm app/controllers/application_controller.rb'
  file 'app/controllers/application_controller.rb', <<-RUBY
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :authenticate_user!
end
RUBY

  # migrate + devie views
  ########################################
  rake 'db:migrate'
  generate('devise:views')

  # Pages Controller
  ########################################
  run 'rm app/controllers/pages_controller.rb'
  file 'app/controllers/pages_controller.rb', <<-RUBY
class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :home ]

  def home
  end
end
RUBY

  # Environments
  ########################################
  environment 'config.action_mailer.default_url_options = { host: "http://localhost:3000" }', env: 'development'
  environment 'config.action_mailer.default_url_options = { host: "http://TODO_PUT_YOUR_DOMAIN_HERE" }', env: 'production'

  # Figaro
  ########################################
  run "bundle binstubs figaro"
  run "figaro install"

  inside 'config' do
    figaro_yml = <<-EOF
# Add configuration values here, as shown below.
#
# GOOGLE_API_BROWSER_KEY: "AI**********oc"
#
# development:
#   FB_ID: "20**********84"
#   FB_SECRET: "2b**********43"

# production:
#   FB_ID: "23**********38"
#   FB_SECRET: "7f**********3b"
production:
  SECRET_KEY_BASE: "#{SecureRandom.hex(64)}"
EOF
    file 'application.yml', figaro_yml, force: true
  end

  # Git
  ########################################
  git :init
  git add: "."
  git commit: %Q{ -m 'Initial commit with devise template' }
end
