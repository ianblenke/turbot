# Author: Robert Jackson (robert.w.jackson@me.com)
# Inspired by epitron/pookie: https://github.com/epitron/pookie/blob/master/handlers/url_handler.rb

require 'uri'
require 'open-uri'
require 'mechanize'

module TurbotPlugins
  class UrlHandler
    include Cinch::Plugin

    listen_to :channel

    def listen(m)
      URI.extract(m.raw, ['http','https']).each do |url|
        link_info = print_link_info(url)
        m.reply link_info
      end
    end

    private

    def print_link_info(url)
      case url
      when twitter_status_regexp
        twitter_status_info(url)
      when twitter_user_regexp
        twitter_user_info(url)
      when github_regexp
        github_info(url)
      when gist_regexp
        gist_info(url)
      when image_regexp
        image_info(url)
      else
        "title: \2#{get_title(url)}\2"
      end
    end

    def twitter_status_regexp
      %r{https?://twitter\.com/(?:#!/)?(.+/status/\d+)}
    end

    def twitter_status_info(url)
      url = cleanup_twitter_hashbang_url(url)
      page = agent.get(url)

      tweet   = clean_text(page.at(".tweet-text"))
      tweeter = page.at(".permalink-tweet .username").text

      "tweet: <\2#{tweeter}\2> #{tweet}"
    end

    def twitter_user_regexp
      %r{(https?://twitter\.com/)(?:#!/)?([^/]+)/?$}
    end

    def twitter_user_info(url)
      url = cleanup_twitter_hashbang_url(url)
      page = agent.get(url)

      username  = twitter_user_regexp.match(url)[2]
      fullname  = page.at(".user-actions")["data-name"]

      tweets    = clean_text(page.at("ul.stats li a[data-element-term='tweet_stats'] strong"))
      followers = clean_text(page.at("ul.stats li a[data-element-term='follower_stats'] strong"))
      following = clean_text(page.at("ul.stats li a[data-element-term='following_stats'] strong"))

      "tweeter: \2@#{username}\2 (\2#{fullname}\2) | tweets: \2#{tweets}\2, following: \2#{following}\2, followers: \2#{followers}\2"
    end

    def cleanup_twitter_hashbang_url(url)
      if url =~ %r{#!/(.+)}
        url = 'https://twitter.com/' + $1
      end

      url
    end

    def github_regexp
      %r{https?://(?:www\.)?github\.com/([^/]+?)/([^/]+)}
    end

    def github_info(url)
      username, repository = url.scan(github_regexp).first

      url = "https://api.github.com/repos/#{username}/#{repository}"
      api_data = get_json_data(url)

      watchers, forks, desc = api_data.values_at('watchers','forks', 'description')

      "github: \2#{username}/#{repository}\2 - #{desc} (watchers: \2#{watchers}\2, forks: \2#{forks}\2)"
    end

    def gist_regexp
      %r{https?://gist\.github\.com/(\w+)$}
    end

    def gist_info(url)
      gist_number = gist_regexp.match(url)[1]
      url = 'https://api.github.com/gists/' + gist_number

      api_data = get_json_data(url)
      description, user, forks = api_data.values_at('description', 'user', 'forks')

      "gist: \2#{user['login']}\2 forks: \2#{forks.length}\2 desc:\2#{(description[0..140])}\2"
    end

    def get_json_data(url)
      page = agent.get(url)
      JSON.parse(page.body)
    end

    def image_regexp
      %r{(\.png|\.tif|\.jpg|\.gif)}
    end

    def image_info(url)
      image = agent.head(url)

      mimetype, size = image.response.values_at('content-type', 'content-length')

      "image: \2#{mimetype}\2 (#{size.to_i / 1024} KiB)"
    end

    def get_title(url)
      page = agent.get(url)

      cleanup_title(page.search("title").first)
    end

    def cleanup_title(title)
      clean_text(title)[0..255]
    end

    def agent
      @agent ||= Mechanize.new
    end

    def clean_text(element)
      if element.respond_to?(:inner_text)
        CGI.unescapeHTML(element.inner_text.strip.gsub(/\s*\n+\s*/, " "))
      else
        element.to_s
      end
    end
  end
end