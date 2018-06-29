class Product < ApplicationRecord

  require 'peddler'
  require 'date'
  require 'csv'

  def crawl(user)
    #MWSにアクセス
    mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.seller_id
    skey = temp.secret_key
    awskey = temp.aws_key

    apitoken = temp.cw_api_token
    roomid = temp.cw_room_id
    ids = temp.cw_ids

    tt = Product.where(user: user)
    border = tt.stock_border
    #asinlist = tt.pluck(:asin)
    asinlist = tt.pluck(:sku)
    client = MWS.products(
      primary_marketplace_id: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    asins = []

    j = 0
    asinlist.each do |taisn, i|
      asins.push(taisn)
      if j == 9 or i == asinlist.length - 1 then
        asins.slice!(j, 9 - asins.length)
        response = client.get_lowest_offer_listings_for_sku(asins,{item_condition:"New", exclude_me: "false"})
        response2 = client.get_lowest_offer_listings_for_sku(asins,{item_condition:"New", exclude_me: "true"})
        parser = response.parse
        parser2 = response2.parse
        uhash = {}
        parser.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          sku = product.dig('Product', 'Identifiers', 'SKUIdentifier', 'SellerSKU')

          uhash[sku] = {asin: asin, sku:sku}

          tprice = 0
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          buf1 = product.dig('Product', 'LowestOfferListings')
          tnum = 0
          if buf1 != nil then
            #出品アリ
            if buf.class == Array then
              #複数出品
              ch1 = false
              ch2 = false
              buf.each do |ttt, k|
                if ttt.dig('Qualifiers', 'FulfillmentChannel') == 'Amazon' then
                  ch1 = true
                elsif ttt.dig('Qualifiers', 'FulfillmentChannel') == 'Merchant' then
                  ch2 = true
                end
                tnum = tnum + ttt.dig('NumberOfOfferListingsConsidered').to_i
              end
              tprice =  buf[0].dig('Price', 'LandedPrice', 'Amount').to_i
            else
              tprice =  buf.dig('Price', 'LandedPrice', 'Amount').to_i
              #tnum = buf.dig('NumberOfOfferListingsConsidered').to_i
            end
          end
          th = uhash[sku]
          if ch1 == false || ch2 == false then
            tnum = 0
          end
          logger.debug(tprice)
          th[:snum] = tnum
          th[:price] = tprice
          uhash[sku] = th
        end

        parser2.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          sku = product.dig('Product', 'Identifiers', 'SKUIdentifier', 'SellerSKU')
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          buf1 = product.dig('Product', 'LowestOfferListings')
          tnum = 0
          if buf1 != nil then
            #出品アリ
            if buf.class == Array then
              #複数出品
              buf.each do |ttt|
                if ttt.dig('Qualifiers', 'ItemCondition') == "New" then
                  tnum = tnum + ttt.dig('NumberOfOfferListingsConsidered').to_i
                end
              end
            else
              if buf.dig('Qualifiers', 'ItemCondition') == "New" then
                tnum = buf.dig('NumberOfOfferListingsConsidered').to_i
              end
            end
          else
            tnum = 0
          end
          th = uhash[sku]
          th[:rnum] = tnum
          uhash[sku] = th
        end

        uhash.each do |ss|
          logger.debug('======= Info Start =========')
          t_asin = ss[1][:asin]
          t_sku = ss[1][:sku]
          t_price = ss[1][:price]
          t_snum = ss[1][:snum]
          t_rnum = ss[1][:rnum]
          logger.debug(t_asin)
          logger.debug(t_sku)
          logger.debug(t_price)
          logger.debug(t_snum)
          logger.debug(t_rnum)
          logger.debug('======= Info END =========')
          temps = tt.find_by(sku: t_sku)
          if temps == nil then break end
          if t_snum > 0 then
            temps.update(jriden: true)
            msg = "注意!: 自社相乗り \n" + "ASIN: " + t_asin + "\n" + "URL: https://www.amazon.co.jp/dp/" + t_asin
          else
            temps.update(jriden: false)
          end
          if t_rnum > 0 then
            temps.update(riden: true)
            msg = "【警告!!】: 他社相乗り \n" + "ASIN: " + t_asin + "\n" + "URL: https://www.amazon.co.jp/dp/" + t_asin
          else
            temps.update(riden: false)
          end
          if t_price > 0 then
            temps.update(price: t_price)
          end

          if t_snum > 0 || t_rnum > 0 then
            if temps.checked != true then
              if temps.fba_stock > border then
                logger.debug("==== Alert ====")
                stask(msg, apitoken,roomid, ids)
              end
            end
          end
        end

        asins = []
        j = 0
      else
        j += 1
      end
    end
  end

  #FBA在庫数の確認
  def fba_check(user)
    logger.debug("\n===== Start FBA check =====")
    mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.seller_id
    skey = temp.secret_key
    awskey = temp.aws_key
    products = Product.where(user:user)

    dt = DateTime.now.gmtime
    endate = dt.yesterday.beginning_of_day.ago(9.hours).iso8601
    stdate = dt.yesterday.beginning_of_day.ago(9.hours).iso8601

    report_type = "_GET_FBA_FULFILLMENT_CURRENT_INVENTORY_DATA_"
    mws_options = {
      start_date: stdate,
      end_date: endate
    }
    logger.debug(mws_options)
    client = MWS.reports(
      primary_marketplace_id: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    response = client.request_report(report_type, mws_options)
    parser = response.parse
    reqid = parser.dig('ReportRequestInfo', 'ReportRequestId')

    mws_options = {
      report_request_id_list: reqid,
    }
    process = ""
    logger.debug(reqid)
    while process != "_DONE_" && process != "_DONE_NO_DATA_"
      response = client.get_report_request_list(mws_options)
      parser = response.parse
      process = parser.dig('ReportRequestInfo', 'ReportProcessingStatus')
      logger.debug(process)
      if process == "_DONE_" then
        genid = parser.dig('ReportRequestInfo', 'GeneratedReportId')
        break
      elsif process == "_DONE_NO_DATA_" then
        genid = "NODATA"
        break
      end
      sleep(30)
    end

    logger.debug("====== generated id =======")
    logger.debug(genid)

    if genid.to_s != "NODATA" then
      response = client.get_report(genid)
      parser = response.parse
      logger.debug("====== report data is ok =======\n")
      parser.each do |row|
        if row[6] == 'SELLABLE' then
          tsku = row[2]
          quantity = row[4]
          t1 = products.find_by(sku: tsku)
          if t1 != nil then
            t1.update(fba_stock: quantity)
          end
          logger.debug("SKU: " + tsku + " ,FBA stock: " + quantity.to_s)
        end
      end
    end
    logger.debug("\n===== End FBA check =====\n")
  end

  def msend(message, api_token, room_id)
    base_url = "https://api.chatwork.com/v2"
    endpoint = base_url + "/rooms/" + room_id  + "/messages"
    request = Typhoeus::Request.new(
      endpoint,
      method: :post,
      params: { body: message },
      headers: {'X-ChatWorkToken'=> api_token}
    )
    request.run
    res = request.response.body
    logger.debug(res)
  end

  def stask(message, api_token, room_id, to_ids)
    base_url = "https://api.chatwork.com/v2"
    endpoint = base_url + "/rooms/" + room_id  + "/tasks"
    request = Typhoeus::Request.new(
      endpoint,
      method: :post,
      params: { body: message, to_ids: to_ids },
      headers: {'X-ChatWorkToken'=> api_token}
    )
    request.run
    res = request.response.body
    logger.debug(res)
  end

end
