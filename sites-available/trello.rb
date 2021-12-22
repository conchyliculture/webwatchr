#!/usr/bin/ruby
# encoding: utf-8

require_relative "../lib/site.rb"
require "json"
require "mechanize"

class TrelloStruct
  def initialize(json)
    @name = json['name']
    @lists = {}
    @cards = []
    json['lists'].each do |list|
      add_list(list['name'], list['id'])
    end
    json['cards'].each do |card|
      add_card(card['name'], card['id'], card['idList'])
    end
  end
  def add_list(name, id)
    @lists[id] = name
  end
  def add_card(name, id, list_id)
    @cards << {name: name, id:id, list_id:list_id}
  end
  def get_cards_by_list_id(list_id)
    return @cards.select{|c| c[:list_id] == list_id}
  end
  def to_html(ignores:[])
    res = ""
    @lists.each do |li,ln|
      next if ignores.include?(ln)
      res << "<b>#{ln}</b> \n<ul>\n"
      get_cards_by_list_id(li).each do |c|
        res << "  <li>#{c[:name]}</li>\n"
      end
      res << "</ul>\n"
    end
    return res
  end
end

class Trello < Site::DiffString
    def initialize(url: , ignores: [], every:, messages:nil, comment:nil, test:false)
        super(
            url: url,
            every: every,
            test: test,
            comment: comment,
        )
        @json = nil
        @ignores = ignores
    end

    def pull_things()
      mechanize = Mechanize.new
      mechanize.get(@url)
      trello_id = @url[/b\/([^\/]+)/,1]
      mechanize.get("https://trello.com/1/board/#{trello_id}?fields=id,idOrganization")
      res = mechanize.get("https://trello.com/1/Boards/#{trello_id}?lists=open&list_fields=name%2Cclosed%2CidBoard%2Cpos%2Csubscribed%2Climits%2Ccr eationMethod%2CsoftLimit&cards=visible&card_attachments=cover&card_stickers=true&card_fields=badges%2CcardRole%2Cclosed%2Cd ateLastActivity%2Cdesc%2CdescData%2Cdue%2CdueComplete%2CdueReminder%2CidAttachmentCover%2CidList%2CidBoard%2CidMembers%2Cid Short%2CidLabels%2Climits%2Cname%2Cpos%2CshortUrl%2CshortLink%2Csubscribed%2Curl%2ClocationName%2Caddress%2Ccoordinates%2Cc over%2CisTemplate%2Cstart%2Clabels&card_checklists=none&enterprise=true&enterprise_fields=displayName&members=all&member_fi elds=activityBlocked%2CavatarUrl%2Cbio%2CbioData%2Cconfirmed%2CfullName%2CidEnterprise%2CidMemberReferrer%2Cinitials%2Cmemb erType%2CnonPublic%2Cproducts%2Curl%2Cusername&membersInvited=all&membersInvited_fields=activityBlocked%2CavatarUrl%2Cbio%2 CbioData%2Cconfirmed%2CfullName%2CidEnterprise%2CidMemberReferrer%2Cinitials%2CmemberType%2CnonPublic%2Cproducts%2Curl%2Cus ername&memberships_orgMemberType=true&checklists=none&organization=true&organization_fields=name%2CdisplayName%2Cdesc%2Cdes cData%2Curl%2Cwebsite%2Cprefs%2Cmemberships%2ClogoHash%2Cproducts%2Climits%2CidEnterprise%2CpremiumFeatures&organization_ta gs=true&organization_enterprise=true&organization_disable_mock=true&myPrefs=true&fields=name%2Cclosed%2CdateLastActivity%2C dateLastView%2CdatePluginDisable%2CenterpriseOwned%2CidOrganization%2Cprefs%2CpremiumFeatures%2CshortLink%2CshortUrl%2Curl% 2CcreationMethod%2CidEnterprise%2Cdesc%2CdescData%2CidTags%2Cinvitations%2Cinvited%2ClabelNames%2Climits%2Cmemberships%2Cpo werUps%2Csubscribed%2CtemplateGallery&pluginData=true&organization_pluginData=true&boardPlugins=true")
      @json = JSON.parse(res.body)
    end

    def get_content()
      t=TrelloStruct.new(@json)
      return t.to_html(ignores: @ignores)
    end
end

# Example:
#
# Trello.new(
#     url: "https://trello.com/b/AI1A9SJ1/some_trello",
#     ignores: ['General Info', 'Done'], # Ignores specific List names
#     every: 30*60,
#     test: __FILE__ == $0
# ).update

