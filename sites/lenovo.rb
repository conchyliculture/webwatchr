require_relative "../lib/site"

class LenovoOVP < Site::SimpleString
  def get_content()
    res = "<ul>\n"
    @parsed_content.css("div.rowLineItem").each do |art|
      name = art.css("div#dr_pdName").text.strip()
      ship_status = art.css("li.dr_trackShipment").text.strip()
      ship_extra = art.css("div.dr_extraOVPInfo").text.strip()
      res += "<li><a href='#{@url}'>#{name}</a>: #{ship_status} #{ship_extra}</li>\n"
    end
    res += "</ul>\n"
    return ResultObject.new(res)
  end
end

# Example:
#LenovoOVP.new(
#    # The order confirm email you got, looks like
#    url: "http://checkout.lenovo.com/store?SiteID=lenovoeu&Action=DisplayCustomerServiceOrderDetailPage&requisitionID=11111111111&Locale=fr_CH&lenovoOrderToken=XFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF%3D",
#    )
#
