set :asset_directories, []
set(:shared_assets_path) { File.join(shared_path, 'assets') }

namespace :deploy do
  # TODO: Merge into assets namespace
  # TODO: Add dependency checking

  desc 'Bundle and minify the JS and CSS files'
  task :precache_assets, :roles => [:app] do
    root_path = File.expand_path(File.dirname(__FILE__) + '/../..')
    assets_path = "#{root_path}/public/assets"
    run_locally "jammit"
    top.upload assets_path, "#{current_release}/public", :via => :scp, :recursive => true
  end

  # re-linking for config files on public repos
  desc "Re-link config files"
  task :link_config, :roles => [:app] do
    config_files = fetch(:config_files, {})
    config_files.each do |k,v|
      link Hash[k,v]
    end
  end
end

namespace :assets do
  desc "Compress javascripts and stylesheets"
  task :compress, :except => { :no_release => true } do
    rubaidh_run_rake "assets:compress"
  end

  namespace :directories do
    desc "[internal] Create all the shared asset directories"
    task :create, :roles => [ :app, :web ], :except => { :no_release => true } do
      asset_directories.each do |dir|
        run "umask 0002 && mkdir -p #{File.join(shared_assets_path, dir)}"
      end
    end

    desc "[internal] Symlink the shared asset directories into the new deployment"
    task :symlink, :roles => [ :app, :web ], :except => { :no_release => true } do
      asset_directories.each do |dir|
        run <<-CMD
          rm -rf #{latest_release}/#{dir} &&
          ln -s #{shared_assets_path}/#{dir} #{latest_release}/#{dir}
        CMD
      end
    end
  end

  desc "Create a backup of all the shared assets"
  task :backup, :roles => [ :app, :web ], :except => { :no_release => true } do
    tar = fetch(:tar, "tar")
    rails_env = fetch(:rails_env, "production")

    run "if [ -d #{shared_assets_path} ]; then cd #{shared_assets_path} && #{tar} cjf #{rails_env}-assets.tar.bz2 #{asset_directories.join(" ")}; fi"
  end

  task :download, :roles => [ :app, :web ], :except => { :no_release => true } do
    unless asset_directories.empty?
      backup

      rails_env = fetch(:rails_env, "production")

      get "#{shared_assets_path}/#{rails_env}-assets.tar.bz2", "#{rails_env}-assets.tar.bz2"
    end
  end
end

after 'deploy:setup',           'assets:directories:create'
after 'deploy:finalize_update', 'assets:directories:symlink'

# Add the assets directories to the list of dependencies we check for.
on :load do
  asset_directories.each do |dir|
    depend :remote, :directory, File.join(shared_assets_path, dir)
    depend :remote, :command, fetch(:tar, "tar")
  end

  if fetch(:compress_assets, false)
    depend :remote, :command, "java"
    before 'deploy:finalize_update', 'assets:compress'
  end
end

def link(link)
  source, target = link.keys.first, link.values.first
  run "ln -nfs #{target} #{source}"
end
