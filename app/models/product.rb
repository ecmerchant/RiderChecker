class Product < ApplicationRecord

  require 'peddler'

  def crawl(user)
    #MWSにアクセス
    mp = "A1VC38T7YXB528"
    temp = Account.find_by(user: user)
    sid = temp.seller_id
    skey = temp.secret_key
    awskey = temp.aws_key
    tt = Product.where(user:user)
    skulist = tt.pluck(:sku)
    client = MWS.products(
      primary_marketplace_id: mp,
      merchant_id: sid,
      aws_access_key_id: awskey,
      aws_secret_access_key: skey
    )

    skus = []
    j = 0
    skulist.each do |tsku, i|
      skus.push(tsku)
      if j == 9 or i == skulist.length - 1 then
        response = client.get_lowest_offer_listings_for_sku(skus,{exclude_me: "true"})
        #response = client.get_lowest_offer_listings_for_sku(skus,{exclude_me: "false"})
        parser = response.parse

        parser.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          ttsku = product.dig('Product', 'Identifiers', 'SKUIdentifier', 'SellerSKU')
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          #buf = product.dig('Product', 'LowestOfferListings')
          lowestprice = 0
          logger.debug("\n")
          logger.debug(asin)
          tnum = 0
          k = 0
          if buf != nil then
            buf.each do |tp|
              logger.debug(k)
              logger.debug(tp)
              if tp.include?('NumberOfOfferListingsConsidered') then
                tnum = tnum + tp[1].to_i
                logger.debug(tnum)
              end
              logger.debug("\n")
              #logger.debug(tp)
              #if tp.include?('NumberOfOfferListingsConsidered') then
              #  tnum = tnum + tp.dig(1)[1].to_i
              #end
              k += 1
            end
            lowestprice = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing', 0, 'Price', 'ListingPrice','Amount')
            if lowestprice == nil then
              lowestprice = 0
            end
          else
            lowestprice = 0
          end
          logger.debug("Seller num : " + tnum.to_s)
          logger.debug(ttsku)
          if ttsku != nil then
            if tnum > 0 then
              tt.find_by(sku:ttsku).update(riden: true)
            else
              tt.find_by(sku:ttsku).update(riden: false)
            end
          end
        end

        skus = []
        j = 0
      else
        j += 1
      end
    end
  end

end
