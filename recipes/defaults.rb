# Repository defaults
set :scm, :git
set :git_enable_submodules, true
set(:repository) { "git@github.com:#{github_user}/#{application}.git" }
set :deploy_via, :remote_cache

# Deployment configuration
set :daemon_strategy, :passenger
set(:user) { application.gsub('_', '') }
set :use_sudo, false

on :load do
  role(:app)                  { host }
  role(:web)                  { host }
  role(:db, :primary => true) { host }

  set(:branch) { fetch(:stage, 'master').to_s }
  set(:rails_env) { fetch(:stage, 'production').to_s }
end

# A bunch of features provided by this plugin that I want to enable for most
# of our applications.
set :backup_database_before_migrations, true
set :disable_web_during_migrations,     true
if defined?(Bundler)
  set :build_gems,                      false
else
  set :build_gems,                      true
end
set :tag_on_deploy,                     true
set :cleanup_on_deploy,                 true
# compress_assets: :jammit, :yui, :none
set :compress_assets,                   :jammit
# sync_assets_via: :scp, :rsync, :none
set :sync_assets_via,                    :scp
set :enable_delayed_job,                false
set :database_type,                     "postgresql"

# SSH options
ssh_options[:forward_agent] = true
ssh_options[:keys] = [
  File.join(ENV['HOME'], '.ssh', 'identity'),
  File.join(ENV['HOME'], '.ssh', 'id_rsa'),
  File.join(ENV['HOME'], '.ssh', 'id_dsa')
]

on :load do
  after_any_deployment "deploy:cleanup" if fetch(:cleanup_on_deploy, false)
end
