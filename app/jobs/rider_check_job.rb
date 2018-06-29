class RiderCheckJob < ApplicationJob
  queue_as :default

  rescue_from(StandardError) do |exception|
   # Do something with the exception
    logger.error exception
  end
  
  def perform(*args)
    # Do something later
    temp = Product.new
    temp.crawl(args)
  end
end
