# If you use whenever to manage cron jobs inside of your Rails app
namespace :cron do
  desc "Update the current crontab with the configuration in config/schedule.rb"
  task :update, :roles => :db, :only => { :primary => true } do
    rails_env = fetch(:rails_env, "production")
    if defined?(Bundler)
      run "cd #{release_path} && bundle exec whenever --update-crontab --set environment=#{rails_env} -i #{application}"
    else
      run "cd #{release_path} && whenever --update-crontab --set environment=#{rails_env} -i #{application}"
    end
  end
end
# To activate:
#   after "deploy:symlink", "cron:update"

