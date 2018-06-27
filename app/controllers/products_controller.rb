class ProductsController < ApplicationController

  require 'nokogiri'
  require 'uri'
  require 'csv'
  require 'peddler'
  require 'typhoeus'
  require 'date'
  require 'kconv'

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    redirect_to root_url, :alert => exception.message
  end

  def show
    @login_user = current_user
    #temp = Product.find_or_create_by(user:current_user.email)
    @products = Product.where(user:current_user.email)
  end

  def delete
    Product.delete_all
    redirect_to root_url
  end

  def check
    if params[:commit] == "監視開始" then
      #temp = Product.new
      #temp.crawl(current_user.email)
      RiderCheckJob.perform_later(current_user.email)
    end
    redirect_to products_show_path
  end

  def update
    tag = params[:chk]
    if tag != nil then
      products = Product.where(user:current_user.email)
      tag.each do |tasin|
        tm = products.find_by(asin: tasin)
        if tm != nil then
          tm.update(checked: true)
        end
      end
    end
    redirect_to products_show_path
  end

  def setup
    @login_user = current_user
    @account = Account.find_or_create_by(user:current_user.email)
    if request.post? then
      @account.update(user_params)
    end
  end

  def upload
    if request.post? then
      data = params[:file]
      if data != nil then
        list = CSV.read(data.path, headers:true)
        temp = Product.where(user:current_user.email)
        list.each do |row|
          logger.debug(row[0].to_s)
          temp2 = temp.find_or_create_by(asin:row[0])
          #temp2.update(asin:row[1], price:row[2])
        end
      end
    end
    redirect_to products_show_path
  end

  private
  def user_params
     params.require(:account).permit(:user, :seller_id, :aws_key, :secret_key, :cw_api_token, :cw_room_id, :cw_ids)
  end

end
