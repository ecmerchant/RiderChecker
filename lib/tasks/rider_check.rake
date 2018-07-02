namespace :rider_checker do
  desc "相乗り監視"

  task :rider_checker, [:user] => :environment do |task, args|
    cuser = args[:user]
    RiderCheckJob.perform_later(cuser)
  end
end
