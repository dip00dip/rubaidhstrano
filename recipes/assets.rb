set :asset_directories, []
set(:shared_assets_path) { File.join(shared_path, 'assets') }
# config files to re-link
# supply a hash of desired_location => real_location pairs
# We do this before finalize_update (so that db config will be available to after finalize_update)
#  so use latest_release rather than current_path in building paths
set(:config_files) {{"#{latest_release}/config/database.yml" => "#{shared_path}/config/database.yml"}}

namespace :assets do
  desc "Compress javascripts and stylesheets using YUI"
  task :compress, :except => { :no_release => true } do
    rubaidh_run_rake "assets:compress"
  end

  desc 'Bundle and minify the JS and CSS files using Jammit'
  task :precache_assets, :roles => [:app], :except => { :no_release => true } do
    root_path = File.expand_path(File.dirname(__FILE__) + '/../../../..')
    assets_path = "#{root_path}/public/assets"
    run_locally "jammit"
    case fetch(:sync_assets_via, :none)
    when :scp
      top.upload assets_path, "#{current_release}/public", :via => :scp, :recursive => true
    when :rsync
      find_servers(:roles => [:app], :except => { :no_release => true }).each do |server|
        run_locally rsync_command_for(server, "./public/assets")
      end
    end
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

  namespace :files do
    # re-linking for config files on public repos
    desc "Re-link config files"
    task :symlink, :roles => [:app] do
      config_files = fetch(:config_files, {})
      config_files.each do |k,v|
        link Hash[k,v]
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
before 'deploy:finalize_update', 'assets:files:symlink'

# Add the assets directories to the list of dependencies we check for.
on :load do
  asset_directories.each do |dir|
    depend :remote, :directory, File.join(shared_assets_path, dir)
    depend :remote, :command, fetch(:tar, "tar")
  end

  # check dependencies and set callback for asset deployment strategy
  case fetch(:compress_assets, :none)
  when :yui
    depend :remote, :command, "java"
    before 'deploy:finalize_update', 'assets:compress'
  when :jammit
    depend :remote, :gem, :jammit, ">=0.4.4"
    depend :local, :command, "jammit"
    after 'deploy:symlink', 'assets:precache_assets'
  end

end

def link(link)
  source, target = link.keys.first, link.values.first
  run "ln -nfs #{target} #{source}"
end

def rsync_command_for(server, assets_path)
  "rsync --verbose --progress --stats --compress --rsh='ssh -p #{ssh_port(server)}' #{assets_path}/* #{rsync_host(server)}:#{current_release}/public/assets"
end

def ssh_port(server)
  server.port || ssh_options[:port] || 22
end

def rsync_host(server)
  user = fetch(:user, nil)
  user ? "#{user}@#{server.host}" : server.host
end
