require 'viva/version'
require 'viva/url_getter'
require 'viva/player'
require 'viva/translator'
require 'viva/database'
require 'thread/pool'
require 'ruby-progressbar'

# Adds a method to check whether string is an integer
class String
  def int?
    to_i.to_s == self
  end
end

class Viva
  # Only show this many results
  MAX_RESULTS = 50
  DEBUG = false

  attr_reader :db

  def initialize(db_file = "#{ENV['HOME']}/.viva.db")
    @db = Viva::Database.new(db_file)
  end

  # Given one or an array of Track's, plays one of them.
  # Prompts the user for one track if an array is given
  # TODO: Play all of them?
  def play(tracks, save_file_name = nil)
    track = prompt(tracks)
    return if track.nil?

    player = Viva::Player.new(track)
    player.play
    player.save(save_file_name) unless save_file_name.nil?
  end

  # Searches and plays a track
  def search_and_play(term, save_file_name = nil)
    case term
    when String
      tracks = @db.search_tracks(term)
    when Viva::Database::Track
      tracks = term
    end

    if tracks.empty?
      puts "No track matches '#{term}'"
      return
    end

    play(tracks, save_file_name)
  end

  def search_series_and_play(term, save_file_name = nil)
    series = @db.search_series(term)

    selected = prompt(series)
    return if selected.nil?

    tracks = Viva::Database::Track.where(series_id: selected[:id])
    play(tracks, save_file_name)
  end

  def scrape(threads: 1, rescrape: false)
    Viva::Database::Track.where(scraped: true).delete_all if rescrape

    pool = Thread::Pool.new(threads)
    printf "Using %d thread%s to download links\n",
           threads,
           threads == 1 ? '' : 's'

    # Put it in a local variable to avoid race condition
    # File size is only < 3 MB or so, so it's no big deal
    results = {}

    Viva::URLGetter.series_names.each do |raw_name, series_number|
      results[raw_name] = {}
      results[raw_name][:tracks] = []

      pool.process results, raw_name do |results, raw_name|
        (to_use_jpn, to_use_eng) = Viva::Translator.guess_titles(raw_name)
        printf "%s\r%s\r", ' ' * 80, (to_use_jpn || to_use_eng || raw_name)

        results[raw_name][:series] = {
          jpn: to_use_jpn,
          eng: to_use_eng,
          raw: raw_name,
          series_number: series_number
        }

        Viva::URLGetter.get_tracks(raw_name).each do |default_title, url|
          track_properties = {
            default_title: default_title,
            url: url,
            scraped: true
          }

          results[raw_name][:tracks] << track_properties
        end
      end
    end

    pool.shutdown

    puts
    puts 'Now adding tracks to the database. This may take a while.'
    fmt = '%a %E %c/%C %J%% |%b>%i|'
    progress = ProgressBar.create(format: fmt, total: results.size)
    results.each do |raw_name, properties|
      @db.add_series(properties[:series])
      @db.add_track(properties[:tracks], raw_name)
      progress.increment
    end
  end

  def print_items(items)
    longest = items.max { |a, b| a.width <=> b.width }
    items.each_with_index do |item, i|
      item.print(i, longest.width)
    end
  end

  # Prompts for a number. Returns nil if quit or invalid answer
  def prompt(items)
    return items.first if items.size < 2

    print_items(items)

    print 'Enter number (Enter for first, q to quit): '

    valid_range = 0...[items.size, MAX_RESULTS].min
    input = STDIN.gets.chomp
    case
    when input.empty?
      # Empty input means the first
      items.first
    when input == 'q'
      nil
    when input.int? && valid_range.include?(input.to_i)
      items[input.to_i]
    end
  end
end
