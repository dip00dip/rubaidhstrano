namespace :daemons do
  namespace :delayed_job do
    desc "Start delayed_job process" 
    task :start, :roles => :app do
      run "cd #{current_path}; script/delayed_job start -- #{rails_env}" 
    end

    desc "Stop delayed_job process" 
    task :stop, :roles => :app do
      run "cd #{current_path}; script/delayed_job stop -- #{rails_env}" 
    end

    desc "Restart delayed_job process" 
    task :restart, :roles => :app do
      run "cd #{current_path}; script/delayed_job restart -- #{rails_env}" 
    end
  end
end
on :load do
  if fetch(:enable_delayed_job, false)
    before "deploy:update_code", "daemons:delayed_job:stop"
    before "deploy:restart", "daemons:delayed_job:stop"
    after "deploy:restart", "daemons:delayed_job:start"
  end
end

