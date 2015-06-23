require 'json'
require 'net/http'
require 'open-uri'
require 'nokogiri'
require 'levenshtein'

# Add a method that converts UTF8-unsafe strings to UTF8-safe strings
class String
  def safe
    encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
end

# A module that plays songs.
class Viva
  # Helper module for retrieving list and URLs of the tracks
  module URLGetter
    module_function

    BASE_URL = 'http://www.freeanimemusic.org/anime'
    SEARCH_URL = 'http://www.freeanimemusic.org/song_search.php'
    SERIES_LIST = 'http://www.musicaanime.org/scripts/resources/artists1.php'
    # Actually an XML file that contains the list of tracks available
    TRACK_LIST_FILE = 'button.png'
    # Maximum Levenshtein distance of series name and raw series name
    # This does not include the difference when converting ' ' to '-'
    DIFF_THRESHOLD = 3

    # Returns the URL for the given track name
    # If no track name is given, returns the dictionary
    # of available tracks for the given series.
    # Returns nil if series name is invalid
    def get(series, track = nil)
      track_names = get_tracks(series)
      return track_names if track.nil? || track_names.nil?

      series_name = closest_to(track, track_names.keys)
      track_names[series_name]
    end

    def search(keywords)
      results = []

      res = Net::HTTP.post_form(URI(SEARCH_URL), 'busqueda' => keywords)
      doc = Nokogiri::HTML.parse(res.body)
      base_xpath = '/html/body/table[2]/tr[9]/td/table'
      length = doc.xpath(base_xpath + '/tr').size - 1
      length.times do |i|
        r = i + 2
        # Number
        number = doc.xpath(base_xpath + "/tr[#{r}]/td[1]/span").text
        # Convert e.g. 06. => 6
        number = number.chomp.to_i
        # Track
        track = doc.xpath(base_xpath + "/tr[#{r}]/td[2]/span[2]").text
        # Series
        series = doc.xpath(base_xpath + "/tr[#{r}]/td[3]/a[1]/span").text

        results << {
          series_number: number,
          # track is something like 'kawaru mirai - (open)' so
          # strip off the ' - (open)' part
          default_title: track.safe.downcase.sub(/\.?\s+-\s*\([^)]*\)/, '').strip,
          series: series.safe.downcase.strip
        }
      end

      results
    end

    # Finds the closest raw series name for the given series.
    # The given series name only needs to be approximately the same as the
    # raw series name (without counting the differing '-' and ' ')
    # Returns nil if there appears to be no match
    def closest_raw_name(series)
      # Populate series names
      series_names unless defined? @series

      # If it's a dead-on match
      candidate = @series.find do |k, _v|
        k.gsub('-', ' ') == series.gsub('-', ' ')
      end
      return candidate.first unless candidate.nil?

      # Find the closest raw name to series
      candidates = @series.keys
      closest_to(series, candidates)
    end

    # Returns the dictionary of tracks available
    # default_title => location
    # Returns nil if series name is invalid
    def get_tracks(series)
      raw = closest_raw_name(series)
      return nil if raw.nil?

      xml_url = File.join(BASE_URL, URI.escape(raw), TRACK_LIST_FILE)
      doc = Nokogiri::HTML.parse(open(xml_url))

      tracks = {}
      doc.xpath('//track').each_with_index do |track, i|
        title = track.xpath("//track[#{i + 1}]/title").text.safe.downcase
        location = track.xpath("//track[#{i + 1}]/location").text
        track_name = parse_track_name(title)

        tracks[track_name] = location
      end

      tracks
    end

    # Returns the list of series available.
    # raw series name => series number
    # Raw means you can use the string to retrieve the URL
    def series_names
      doc = Nokogiri::HTML.parse(open(SERIES_LIST))
      res = JSON.parse(doc.xpath('/html/body/p/text()').text)

      @series = {}
      res['data'].each do |val|
        raw_series_name = val['title'].safe.downcase
        series_number = val['artist']

        @series[raw_series_name] = series_number.to_i
      end

      @series
    end

    private

    module_function

    # Extracts the track name from the title which is in the format of:
    #   Track num. Track name - Series name
    # or,
    #   Track num. Track name. - (open) - Series name
    def parse_track_name(title)
      # Remove the '. - (open)' part first
      track_name = title.sub(/\.?\s+-\s*\([^)]*\)/, '')
      # Remove track number
      track_name.sub!(/^\s*\d+\.\s*/, '')
      pattern = /
                (.*)                    # Track name
                \s*-.*$
                /x
      return title unless track_name.match(pattern)

      Regexp.last_match(1).strip
    end

    # Returns the element in arr that is closest
    # (in terms of Levenshtein distance) to name
    # Returns nil if nothing seems to be close enough.
    # REFACTOR: add this to Enumerator
    def closest_to(name, arr)
      distances = arr.map do |e|
        [e, Levenshtein.distance(e, name.downcase, DIFF_THRESHOLD)]
      end

      distances.select! { |_k, v| !v.nil? }
      return nil if distances.empty?

      distances.sort! { |a, b| a.last <=> b.last }
      distances.first.first
    end
  end
end
