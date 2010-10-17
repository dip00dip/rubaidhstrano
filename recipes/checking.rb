namespace :deploy do
  desc "Make sure that we haven't forgotten to push to the origin repo"
  task :check_revision, :roles => [:web] do
    unless `git rev-parse HEAD` == `git rev-parse origin/#{branch}`
      puts ""
      puts "  \033[1;33m**************************************************\033[0m"
      puts "  \033[1;33m* WARNING: HEAD is not the same as origin/#{branch} *\033[0m"
      puts "  \033[1;33m**************************************************\033[0m"
      puts ""

      exit
    end
  end

  desc "Require positive confirmation of deployment to production"
  task :ask_production do
    ask_prompt = fetch(:production_deployment_prompt, "Are you sure you want to work with production? \nIf so, type in \"yes\" (anything else is a \"no\"): ");
    exit unless Capistrano::CLI.ui.ask(ask_prompt).downcase == 'yes'
  end

end