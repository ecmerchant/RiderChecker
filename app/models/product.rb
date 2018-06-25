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
        skus.slice!(j,9-skus.length)
        response = client.get_lowest_offer_listings_for_sku(skus,{exclude_me: "false"})
        response2 = client.get_lowest_offer_listings_for_sku(skus,{exclude_me: "true"})
        parser = response.parse
        parser2 = response2.parse
        uhash = {}
        parser.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          ttsku = product.dig('Product', 'Identifiers', 'SKUIdentifier', 'SellerSKU')
          uhash[ttsku] = {asin: asin, sku: ttsku}
          buf = product.dig('Product', 'LowestOfferListings', 'LowestOfferListing')
          buf1 = product.dig('Product', 'LowestOfferListings')
          tnum = 0
          if buf1 != nil then
            #出品アリ
            if buf.class == Array then
              #複数出品
              ch1 = false
              ch2 = false
              buf.each do |ttt|
                if ttt.dig('Qualifiers', 'FulfillmentChannel') == 'Amazon' then
                  ch1 = true
                elsif ttt.dig('Qualifiers', 'FulfillmentChannel') == 'Merchant' then
                  ch2 = true
                end
                tnum = tnum + ttt.dig('NumberOfOfferListingsConsidered').to_i
              end
            else
              #tnum = buf.dig('NumberOfOfferListingsConsidered').to_i
            end
          end
          th = uhash[ttsku]
          if ch1 == false || ch2 == false then
            tnum = 0
          end
          th[:snum] = tnum
          uhash[ttsku] = th
        end

        parser2.each do |product|
          asin = product.dig('Product', 'Identifiers', 'MarketplaceASIN', 'ASIN')
          ttsku = product.dig('Product', 'Identifiers', 'SKUIdentifier', 'SellerSKU')
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
          end
          th = uhash[ttsku]
          th[:rnum] = tnum
          uhash[ttsku] = th
        end

        uhash.each do |ss|
          logger.debug(ss[1])
          t_sku = ss[1][:sku]
          t_snum = ss[1][:snum]
          t_rnum = ss[1][:rnum]
          temps = tt.find_by(sku:t_sku)
          if temps == nil then break end
          if t_snum > 0 then
            temps.update(jriden: true)
          else
            temps.update(jriden: false)
          end
          if t_rnum > 0 then
            temps.update(riden: true)
          else
            temps.update(riden: false)
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
