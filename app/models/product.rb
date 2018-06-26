class Product < ApplicationRecord

  require 'peddler'

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

    tt = Product.where(user: user).group(:asin)

    asinlist = tt.pluck(:asin)
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
        response = client.get_lowest_offer_listings_for_asin(asins,{item_condition:"New", exclude_me: "false"})
        response2 = client.get_lowest_offer_listings_for_asin(asins,{item_condition:"New", exclude_me: "true"})
        parser = response.parse
        parser2 = response2.parse
        uhash = {}
        parser.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          uhash[asin] = {asin: asin}
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
          th = uhash[asin]
          if ch1 == false || ch2 == false then
            tnum = 0
          end
          th[:snum] = tnum
          th[:price] = tprice
          uhash[asin] = th
        end

        parser2.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
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
          th = uhash[asin]
          th[:rnum] = tnum
          uhash[asin] = th
        end

        uhash.each do |ss|
          logger.debug(ss[1])
          t_asin = ss[1][:asin]
          t_price = ss[1][:price]
          t_snum = ss[1][:snum]
          t_rnum = ss[1][:rnum]
          temps = tt.find_by(asin: t_asin)
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
              stask(msg, apitoken,roomid, ids)
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
