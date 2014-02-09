source_paths << File.expand_path("../templates", __FILE__)

append_to_file '.gitignore', %{
coverage
.DS_Store
.vagrant
}

# ruby version at Gemfile
inject_into_file "Gemfile", "ruby '#{RUBY_VERSION}'\n", after: "source 'https://rubygems.org'\n"

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

# Prefer imports to expose Sass mixins
gsub_file 'app/assets/stylesheets/application.css', 'require_tree .', 'require imports'
create_file 'app/assets/stylesheets/imports.css.sass'

# Sass Bootstrap
if yes? 'Would you like to use Sass-Bootstrap?'
  inject_into_file "Gemfile",
    "gem 'bootstrap-sass', '~> 2.3'\n",
    after: "gem 'sass-rails', '~> 4.0.0'\n"

  add_javascript_library :bootstrap
  append_to_file 'app/assets/stylesheets/imports.css.sass', "@import 'bootstrap'"
end

# minitest and simplecov setups
gem_group :development, :test do
  gem 'simplecov'
  gem 'minitest-rails', github: 'blowmage/minitest-rails'
end

# disables jbuilder templates
gems_to_comment = %w{jbuilder}

# disables turbolinks
gems_to_comment << 'turbolinks'

# comment out turbolinks from layout
gsub_file 'app/views/layouts/application.html.erb', /, "data-turbolinks-track" => true/, ''
gsub_file 'app/assets/javascripts/application.js', /\/\/= require turbolinks\n/, ''

# Heroku setup
if yes? "Would you like to deploy to Heroku?"
  gems_to_comment << 'sqlite3'

  inject_into_file "Gemfile", %{
# deploy to a postgres database on heroku
gem 'pg'

# https://devcenter.heroku.com/articles/rails-integration-gems
gem 'rails_12factor'
}, after: "gem 'rails-i18n'\n"

  remove_file 'config/database.yml'
  copy_file 'config/database/postgresql.yml', 'config/database.yml'
  gsub_file 'config/database.yml', /APP_NAME/, app_name.underscore
end

# comments out disabled gems
gems_to_comment.each do |gem|
  gsub_file 'Gemfile', /\w*(gem '#{gem}')/, '# \1'
end

# run bundle install before generators
run 'bundle install'

# then disables default bundle install runner at the end of generator execution
def run_bundle ; end

# Generates MiniTests
generate 'mini_test:install'

prepend_to_file 'test/test_helper.rb', %{require 'simplecov'
SimpleCov.start :rails do
  minimum_coverage 100
end

}

# instantiated fixtures
inject_into_file 'test/test_helper.rb',
  "  self.use_instantiated_fixtures = true\n",
  after: "fixtures :all\n"

gsub_file 'test/test_helper.rb', /\w*(fixtures :all)/, '# \1'

# Configures generators to use minitest and disables unused assets/helpers
application %{
    config.generators do |g|
      g.test_framework :mini_test, spec: true
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
empty_directory 'vagrant'
copy_file 'vagrant/recipes/postgres.sh', 'vagrant/postgres.sh'
run 'vagrant up'

rake 'db:create'
rake 'minitest:all:quick'

git :init
git add: "."
git commit: '-m "First commit!"'
