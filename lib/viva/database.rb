require 'viva/database/tables'
require 'sqlite3'
require 'active_record'

class Viva
  # Handles databes-related operations
  class Database
    def initialize(db_file = "#{ENV['HOME']}/.viva.db")
      ActiveRecord::Base.establish_connection(
        adapter: 'sqlite3',
        database: db_file
      )

      InitSchema.migrate(:up) unless File.exist?(db_file)
    end

    def add_series(series)
      series = [series] unless series.is_a?(Enumerable)

      Series.create(series)
    end

    # Adds track(s) to the database.
    # A (raw) series name can be given to relate the track to that series.
    # TODO: not only raw but also jpn, eng title
    def add_track(track, raw = nil)
      track = [track] unless track.is_a?(Enumerable)

      created = Track.create(track)
      return if raw.nil?

      series = Series.where(raw: raw).first
      created = [created] unless created.is_a?(Enumerable)
      # Save everything in one transaction
      Track.transaction do
        created.each do |t|
          t.series = series
          t.save
        end
      end

    end

    def update_series(series)
      current = Series.where('raw = ?', series[:raw]).first
      if current.nil?
        current = Series.create(series)
      else
        current.update(series)
      end
      current.save
    end

    def update_track(track, raw = nil)
      current_data = Track.where('title = ? OR default_title = ?',
                                 track[:title], track[:default_title]).first
      if current_data.nil?
        current_data = Track.create(track)
      else
        current_data.update(track)
      end

      return if raw.nil?
      current_data.series = Series.where(raw: raw).first
      current_data.save
      # Or this
      #Series.where(raw: raw).first.tracks << current_data
    end

    # Searches for both the series and titles
    # Returns an array of matching tracks.
    # It can be empty if nothing applies
    def search(terms)
      series = Series.all
      tracks = Track.all
      terms.each do |term|
        unless series.empty?
          res = search_series(term, series)
          series = res.empty? ? [] : res
        end

        unless tracks.empty?
          res = search_tracks(term, nil, tracks)
          tracks = res.empty? ? [] : res
        end
      end

      series.each do |s|
        tracks << s.tracks unless s.tracks.empty?
      end

      tracks.flatten
    end

    # Searches series in the database.
    # terms can either be a string, which will be searched as a whole,
    # or a list of terms that will be AND searched.
    # A starting collection can be given.
    def search_series(terms, base = nil)
      terms = [terms] unless terms.is_a?(Enumerable)

      series = base.nil? ? Series.all : base
      terms.each do |term|
        escaped = "%#{escape_like(term)}%"

        res = series.where('jpn LIKE ? OR eng LIKE ? OR raw LIKE ?',
                           escaped, escaped, escaped)
        return res if res.empty?
        series = res
      end
      series
    end

    # TODO: second param series might be useless
    # TODO: When no entry in database, query website
    def search_tracks(cond, series = nil, base = nil)
      case cond
      when Hash
        terms = cond[:title]
        series = cond[:series]
      when Enumerable
        terms = cond
      else
        terms = [cond]
      end

      sql = 'title LIKE ? OR default_title LIKE ?' \
            ' OR artist LIKE ? OR album LIKE ?'

      tracks = base.nil? ? Track.all : base
      terms.each do |term|
        escaped = "%#{escape_like(term)}%"
        res = tracks.where(sql, *([escaped] * 4))

        return res if res.empty?
        tracks = res
      end

      series.nil? ? tracks : tracks.where(series: series)
    end

    private

    # Escapes the special characters used in LIKE
    def escape_like(term)
      term.gsub(/(?=[\\%_])/, '\\')
    end
  end
end
