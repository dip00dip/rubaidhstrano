namespace :db do
  # If you want to automatically run populations on every deploy
  # after 'deploy:symlink', 'db:populate'
  # Or you may want to update migrations and run populations
  # after 'deploy:symlink', 'db:migrate_and_populate'
  # see http://github.com/ffmike/db-populate for details on populations

  # Enable some common rake database tasks as part of deployments
  ['populate', 'migrate_and_populate', 'migrate', 'reset_sequences'].each do |rake_task|
  desc "Run the db:#{rake_task} rake task on the primary database server"
    task rake_task.to_sym, :roles => [ :db ], :only => { :primary => true } do
      rubaidh_run_rake "db:#{rake_task}"
    end
  end

  desc <<-DESC
    Back up the database from the deployment environment. This task dumps the
    MySQL database in the current deployment environment out to an SQL dump
    file which is bzip compressed. It will overwrite any existing backup from
    there.
  DESC
  task :backup, :roles => :db, :only => { :primary => true } do
    rubaidh_run_rake "db:backup:dump"
  end

  desc <<-DESC
    Back up the database in the deployment environment and take a local copy.
    This can be useful for mirroring the production database to another host
    if, for example, you're looking to reproduce a bug on the production
    server.
  DESC
  task :download, :roles => :db, :only => { :primary => true } do
    backup
    rails_env = fetch(:rails_env, 'production')
    get "#{latest_release}/db/#{rails_env}-data.sql.bz2", "db/#{rails_env}-data.sql.bz2"
  end

  desc "Notify the user if there are pending migrations"
  task :notify_if_pending_migrations, :roles => :db, :only => { :primary => true } do
    rubaidh_run_rake "db:notify_if_pending_migrations"
  end

  # TODO: Ought to use the databases_type config option here
  desc "Creates the database.yml configuration file in shared path."
  task :setup, :except => { :no_release => true } do

    default_template = <<-EOF
    base: &base
      adapter: sqlite3
      timeout: 5000
    development:
      database: #{shared_path}/db/development.sqlite3
      <<: *base
    test:
      database: #{shared_path}/db/test.sqlite3
      <<: *base
    production:
      database: #{shared_path}/db/production.sqlite3
      <<: *base
    EOF

    location = fetch(:template_dir, "config/deploy") + '/database.yml.erb'
    template = File.file?(location) ? File.read(location) : default_template

    config = ERB.new(template)

    run "mkdir -p #{shared_path}/db"
    run "mkdir -p #{shared_path}/config"
    put config.result(binding), "#{shared_path}/config/database.yml"
  end

end

on :load do
  # Note the dependency this code creates on mysqldump/pg_dump and bzip2
  if fetch(:database_type, "mysql") == "mysql"
    depend :remote, :command, 'mysqldump'
  else
    depend :remote, :command, 'pg_dump'
  end
  depend :remote, :command, 'bzip2'

  if fetch(:backup_database_before_migrations, false)
    before "deploy:migrate", "db:backup"
  end

  if fetch(:disable_web_during_migrations, false)
    before "deploy:migrations", "deploy:web:disable"
    after  "deploy:migrations", "deploy:web:enable"
  end

  if fetch(:skip_db_setup, true)
    after "deploy:setup", "db:setup"
  end
end

