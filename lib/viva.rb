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

  # Given a Hash, Track, or an ActiveRecord::Relation object,
  # this method plays the corresponding file by passing it to the player.
  # TODO: multiple tracks
  def play(tracks_info, save_file_name = nil)
    track = Viva.singularlize(tracks_info, prompt_if_multi: true)
    return if track.nil?

    track = db.search_strict(track) if track.is_a?(Hash)

    player = Viva::Player.new(track)
    player.play
    player.save(save_file_name) unless save_file_name.nil?
  end

  # TODO: modulize into multiple methods
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
        to_use_jpn = raw_name if to_use_jpn.nil?
        to_use_eng = raw_name if to_use_eng.nil?
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
    items = [items].flatten unless items.is_a?(Enumerable)
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

  # Given one Track, this method prints out that track's information.
  # ActiveRecord::Relation can be given (result from Track.where), but
  # it will print out the first Track element.
  def self.print_track_info(track, detailed = false)
    return if track.nil?
    return unless track.is_a?(ActiveRecord::Relation) \
      || track.is_a?(Viva::Database::Track)
    track = track.first if track.is_a?(ActiveRecord::Relation)

    puts track.to_s(detailed: detailed)
  end

  # Given any kind of data from the database, this method returns one entry.
  # Normally, this method is used so that there is no need to worry about
  # doing Model.where(foo: bar).first or checking whether the result is empty.
  # When prompt_if_multi is true, this method will call Viva::prompt to ask
  # the user for one choice.
  def self.singularlize(data, prompt_if_multi: false, unique: false)
    return nil if data.nil?

    case data
    when ActiveRecord::Relation || Enumerable
      fail "Multiple candidates: #{data}" if unique && data.size > 1
      prompt_if_multi ? prompt(data) : data.first
    else
      data
    end
  end
end
