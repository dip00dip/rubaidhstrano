desc <<-TEXT
Clone the deployment environment to your current environment. This will back
up the current database and any assets from the production environment, copy
them locally and load them. WARNING: This will totally and utterly destroy the
current data contents of your local environment. Don't do this unless you're
paying attention!
TEXT
task :replicate, :roles => [ :db ], :only => { :primary => true } do
  source_env = fetch(:rails_env, 'production')
  target_env = ENV['TARGET_ENV'] || 'development'

  find_and_execute_task("db:download")
  find_and_execute_task("assets:download")

  if defined?(Bundler)
    run_locally "bundle exec rake RAILS_ENV=#{target_env} SOURCE_ENV=#{source_env} db:backup:load"
  else
    run_locally "rake RAILS_ENV=#{target_env} SOURCE_ENV=#{source_env} db:backup:load"
  end

  unless asset_directories.empty?
    asset_directories.each do |dir|
      run_locally "rm -rf #{dir}"
    end
    if defined?(Bundler)
      run_locally "bundle exec rake RAILS_ENV=#{target_env} SOURCE_ENV=#{source_env} assets:backup:load"
    else
      run_locally "rake RAILS_ENV=#{target_env} SOURCE_ENV=#{source_env} assets:backup:load"
    end
  end
end

on :load do
  if fetch(:database_type, "mysql") == "mysql"
    depend :local, :command, "mysql"
  else
    depend :local, :command, "psql"
  end
  depend :local, :command, "bzcat"
  depend :local, :command, "tar"
end

