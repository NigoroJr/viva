# coding: utf-8
require 'json'
require 'uri'
require 'open-uri'
require 'nokogiri'

class Viva
  module Translator
    ACCEPTED = ['(アニメ)', '(テレビアニメ)', '(漫画)', '(anime)', '(manga)', '(visual novel)']
    REJECTED = ['系アニメ']

    # Queries Wikipedia to find the related wikipedia page title
    module Wikipedia
      module_function

      EN_BASE_URL = 'https://en.wikipedia.org/wiki'
      JP_BASE_URL = 'https://ja.wikipedia.org/wiki'
      EN_API_URL = 'https://en.wikipedia.org/w/api.php?' \
        'action=query&list=search&format=json&srsearch=' \
        '{}%20anime&srnamespace=0&srwhat=text&srprop='
      JP_API_URL = 'https://ja.wikipedia.org/w/api.php?' \
        'action=query&list=search&format=json&srsearch=' \
        '{}%20%E3%82%A2%E3%83%8B%E3%83%A1&srnamespace=0&srwhat=text&srprop='

      def eng_title(term, all = false)
        # Note: EN_API_URL already has the term 'anime' included, but adding
        # another 'anime' term seems to improve the accuracy of the results
        res = get_dictionary(term + ' anime', EN_API_URL)
        titles = res['query']['search'].map { |h| h['title'] }
        all ? titles : titles.first
      end

      def jpn_title(term, all = false)
        res = get_dictionary(term, JP_API_URL)
        titles = res['query']['search'].map { |h| h['title'] }
        all ? titles : titles.first
      end

      # Looks up the title for the Japanese Wikipedia page
      # Returns nil if not found
      def eng_to_jpn_title(title)
        return nil if title.nil?
        get_equivalent_title(title, EN_BASE_URL, 'ja')
      rescue OpenURI::HTTPError
        nil
      end

      def jpn_to_eng_title(title)
        return nil if title.nil?
        get_equivalent_title(title, JP_BASE_URL, 'en')
      rescue OpenURI::HTTPError
        nil
      end

      private

      module_function

      def get_dictionary(term, api_url)
        url = api_url.sub('{}', URI.escape(term))
        doc = Nokogiri::HTML.parse(open(url))
        res = JSON.parse(doc.xpath('/html/body/p').text)
        res
      end

      def get_equivalent_title(base_title, base_url, target_language)
        url = File.join(base_url, URI.escape(base_title))
        doc = Nokogiri::HTML.parse(open(url))
        path = "//*[@id='p-lang']/div/ul/li/a[@hreflang='#{target_language}']"
        # Empty array?
        return nil if doc.xpath(path).empty?
        equivalent_url = File.join('https:', doc.xpath(path).attr('href'))

        doc = Nokogiri::HTML.parse(open(equivalent_url))
        doc.xpath('//*[@id="firstHeading"]').text.strip
      end
    end

    module_function

    # Guesses the Japanese and English titles from the raw name
    # Returns [Japanese title, English title]
    def guess_titles(raw)
      tokenized = raw.gsub('-', ' ')
      eng_title = Wikipedia.eng_title(tokenized)
      jpn_title = Wikipedia.jpn_title(tokenized)
      eng_trans = Wikipedia.jpn_to_eng_title(jpn_title)
      jpn_trans = Wikipedia.eng_to_jpn_title(eng_title)

      # Ignore 'List of' something
      eng_title = nil if !eng_title.nil? && eng_title.start_with?('List of')
      eng_trans = nil if !eng_trans.nil? && eng_trans.start_with?('List of')

      # Use translated title for Japanese
      # (since there's less "noise" in English Wikipedia)
      guess_jpn = choose(jpn_title, jpn_trans, jpn_trans)
      # Use API result for English since raw name is in English
      guess_eng = choose(eng_title, eng_trans, eng_title)
      [guess_jpn, guess_eng]
    end

    private

    module_function

    # Chooses which title to use
    def choose(one, two, prioritize)
      return nil if one.nil? && two.nil?

      case
      when one == two
        one
      when one.nil?
        two
      when two.nil?
        one
      when ACCEPTED.any? { |word| one.end_with?(word) }
        ACCEPTED.each do |word|
          one.sub!(word, '')
        end
        one
      when ACCEPTED.any? { |word| two.end_with?(word) }
        ACCEPTED.each do |word|
          two.sub!(word, '')
        end
        two
      when REJECTED.any? { |word| two.end_with?(word) }
        one
      when REJECTED.any? { |word| one.end_with?(word) }
        two
      else
        other = one == prioritize ? two : one
        puts "    #{prioritize} (#{other})" if Viva::DEBUG
        prioritize
      end
    end
  end
end
