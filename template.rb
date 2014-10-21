source_paths << File.expand_path("../templates", __FILE__)

append_to_file '.gitignore', %{
coverage
.DS_Store
.vagrant
*~
}

# ruby version at Gemfile
inject_into_file "Gemfile", "ruby '#{RUBY_VERSION}'", after: "source 'https://rubygems.org'\n"

# rails-i18n and default locale
inject_into_file "Gemfile", "gem 'rails-i18n'\n",
  after: "gem 'rails', '#{Rails::VERSION::STRING}'\n"

gsub_file 'config/application.rb',
  /# config\.i18n\.default_locale = :de/,
  'config.i18n.default_locale = "pt-BR"'

gsub_file 'config/application.rb',
  /# config\.time_zone = 'Central Time \(US & Canada\)'/,
  'config.time_zone = "Brasilia"'

def add_javascript_library(name)
  inject_into_file 'app/assets/javascripts/application.js',
    "\n//= require #{name}", before: "\n//= require_tree ."
end

remove_file 'app/assets/stylesheets/application.css'
create_file 'app/assets/stylesheets/application.css.sass'

# Sass Bootstrap
if yes? 'Would you like to use Sass-Bootstrap?'
  inject_into_file "Gemfile",
    "gem 'bootstrap-sass', '~> 3.2.0'\n",
    after: "gem 'sass-rails', '~> 4.0.3'\n"

  add_javascript_library 'bootstrap-sprockets'

  append_to_file 'app/assets/stylesheets/application.css.sass', "@import 'bootstrap-sprockets'"
  append_to_file 'app/assets/stylesheets/application.css.sass', "@import 'bootstrap'"
end

gsub_file 'Gemfile', "# Use debugger\n# gem 'debugger', group: [:development, :test]\n", ''

development_test_gems = []
test_gems             = []
development_gems      = []
production_gems       = []
after_groups_adjusts  = []

development_gems << Proc.new do
  gem 'spring'
end

after_groups_adjusts << Proc.new do
  gsub_file 'Gemfile',
%{# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
gem 'spring',        group: :development
}, ''

  inject_into_file "Gemfile",
%{# Spring speeds up development by keeping your application running in the background.
  # Read more: https://github.com/rails/spring
  }, before: 'gem "spring"'
end

development_test_gems << Proc.new do
  gem 'minitest-rails', github: 'blowmage/minitest-rails'
  gem 'byebug'
end

test_gems << Proc.new do
  gem 'simplecov'
end

# disables jbuilder templates
gems_to_comment = %w{jbuilder}

# disables turbolinks
gems_to_comment << 'turbolinks'

# comment out turbolinks from layout
gsub_file 'app/views/layouts/application.html.erb', /, 'data-turbolinks-track' => true/, ''
gsub_file 'app/assets/javascripts/application.js', /\/\/= require turbolinks\n/, ''

# PG as default database
gems_to_comment << 'sqlite3'
inject_into_file "Gemfile", %{
# deploy to a postgres database
gem 'pg'

}, after: "gem 'rails-i18n'\n"
remove_file 'config/database.yml'
copy_file 'config/database/postgresql.yml', 'config/database.yml'
gsub_file 'config/database.yml', /APP_NAME/, app_name.underscore

# Heroku setup
deploy_to_heroku = yes? "Would you like to deploy to Heroku?"
if deploy_to_heroku
  copy_file 'config/unicorn.rb', 'config/unicorn.rb'
  copy_file 'config/Procfile', 'Procfile'

  gsub_file 'Gemfile', "# Use unicorn as the app server\n", ''
  gsub_file 'Gemfile', "# gem 'unicorn'\n", ''

  development_gems << Proc.new do
    gem 'rack-handlers'
  end

  production_gems << Proc.new do
    gem 'unicorn'
    gem 'rails_12factor'
  end

  after_groups_adjusts << Proc.new do
  inject_into_file "Gemfile", %{
  # http://stackoverflow.com/questions/15858887/how-can-i-use-unicorn-as-rails-s
  }, before: 'gem "rack-handlers"'

  gsub_file 'Gemfile', 'gem "rack-handlers"', '# gem "rack-handlers"'

  inject_into_file "Gemfile",
%{# https://devcenter.heroku.com/articles/dynos
  # https://devcenter.heroku.com/articles/rails-unicorn
  }, before: 'gem "unicorn"'

  inject_into_file "Gemfile", %{
  # https://devcenter.heroku.com/articles/rails-integration-gems
  }, before: 'gem "rails_12factor"'
  end
end

# comments out disabled gems
gems_to_comment.each do |gem|
  gsub_file 'Gemfile', /\w*(gem '#{gem}')/, '# \1'
end

gem_group :development, :test do
  development_test_gems.each &:call
end

gem_group :development do
  development_gems.each &:call
end

gem_group :test do
  test_gems.each &:call
end

gem_group :production do
  production_gems.each &:call
end

after_groups_adjusts.each &:call

# run bundle install before generators
run 'bundle install'

# then disables default bundle install runner at the end of generator execution
def run_bundle ; end

# Generates MiniTests
generate 'minitest:install'

prepend_to_file 'test/test_helper.rb', %{require 'simplecov'
SimpleCov.start :rails do
  minimum_coverage 100
end

}

# Configures generators to use minitest and disables unused assets/helpers
application %{
    config.generators do |g|
      g.test_framework :minitest, spec: true
      g.assets false
      g.helper false
    end
}

# Sets SASS as preferred syntax
application "config.sass.preferred_syntax = :sass"

# generate default controller and set root path
generate 'controller', 'Home index'
gsub_file 'config/routes.rb', /get "home\/index"/, 'root to: "home#index"'

copy_file 'vagrant/Vagrantfile', 'Vagrantfile'
gsub_file 'Vagrantfile', /APP_NAME/, app_name.underscore

empty_directory 'vagrant'
[:github, :postgres].each {|recipe|
  copy_file "vagrant/recipes/#{recipe}.sh", "vagrant/#{recipe}.sh"
}
run 'vagrant up'

rake 'db:create'
rake 'minitest:all:quick'

git :init
git add: "."
git commit: '-m "First commit!"'

if deploy_to_heroku
  run "heroku plugins:install git://github.com/heroku/heroku-pg-extras.git"

  %w{stg prd}.each do |stage|
    app = "#{app_name.downcase}-#{stage}"
    worker = "#{app}-worker"
    run "heroku apps:create #{app}    --remote #{stage}"
    run "heroku apps:create #{worker} --remote #{stage}w"
    [stage, "#{stage}w"].each {|env| run "git push #{env} master" }

    run "heroku pg:backups schedule DATABASE_URL --app #{app}"

    run "url=$(heroku config --app #{app} | grep DATABASE_URL | sed 's/^.*postgres/postgres/') ; heroku config:add DATABASE_URL=$url --app #{worker} "
    run "heroku ps:scale web=1 worker=0 --app #{app}"
    run "heroku ps:scale web=0 worker=1 --app #{worker}"
  end
end
