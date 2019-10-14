#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"

class LenovoOVP < Site::SimpleString

    def initialize(order_id:, email:, every:, comment:nil, test:false)
        super(
          url: "https://ovp.lenovo.com/lenovo-ovp-new/public/showdetail",
            post_data: {orderNumber: order_id, email: email, lang: "en" }, 
            every: every,
            test: test,
            comment: comment,
        )
    end

    def get_content()
    end
end

# Example:
LenovoOVP.new(
    order_id: "1111111",
    email: "lol@gmail.ninja",
    every: 60*60,
    test: __FILE__ == $0
).update


