require "fileutils"
require "tmpdir"
require "test/unit"

require_relative "../lib/webwatchr/alerting"

class ArticleSiteTest < Test::Unit::TestCase
  def fakeupdate(site)
    workdir = Dir.mktmpdir('fakesite')
    cache_dir = File.join(workdir, 'cache')
    last_dir = File.join(workdir, 'last')

    FileUtils.mkdir_p(cache_dir)
    FileUtils.mkdir_p(last_dir)
    site.update(cache_dir: cache_dir, last_dir: last_dir)
    FileUtils.rm_rf(workdir)
  end
end

class TestAlerter < Webwatchr::Alerting::Base
  IDENTIFIER = :testtest
  attr_accessor :result

  def initialize
    super()
    @result = nil
  end

  def alert(site)
    if site.is_a?(Site::Articles)
      @result = site.articles
    elsif site.is_a?(Site::SimpleString)
      @result = site.content
    else
      raise StandardError, "Unknown Site class being tests: #{site.class}"
    end
  end
end
