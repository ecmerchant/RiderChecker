namespace :get_report do
  desc "相乗り監視"

  task :get_report, [:user] => :environment do |task, args|
    cuser = args[:user]
    GetReportJob.perform_later(cuser)
  end
end
