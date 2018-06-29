class GetReportJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
   # Do something with the exception
    logger.error exception
  end

  def perform(user)
    # Do something later
    temp = Product.new
    temp.fba_check(user)
  end
end
