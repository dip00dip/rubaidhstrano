namespace :deploy do
  desc <<-DESC
    Start the application servers. Since the app servers are managed through
    Phusion Passenger, this is a no-op.
  DESC
  task :start, :roles => :app do; end

  desc <<-DESC
    Stop the application servers. Since the app servers are managed through
    Phusion Passenger, this is a no-op.
  DESC
  task :stop,  :roles => :app do; end

  desc <<-DESC
    Restarts your application. This works by touching tmp/restart.txt which
    indicates to Passenger that the currently running processes should be
    restarted.
  DESC
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path, "tmp","restart.txt")}"
  end
end