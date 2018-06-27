class RiderCheckJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Do something later
    temp = Product.new
    temp.crawl(args)
  end
end
