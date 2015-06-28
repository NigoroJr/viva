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

    def add(data)
      case
      when !data[:track].nil?
        add_tracks(data[:track], data[:series])
      when !data[:series].nil?
        add_series(data[:series])
      end
    end

    # Given a Hash or an Array of Hash, creates a new series in the database.
    def add_series(series)
      type_check(series, :series)
      Series.create(series)
    end

    # Given a Hash or an Array of Hash, adds the track(s) to the database.
    # Optional Hash with the series information (raw name, Japanese name, or
    # English name) can be given to relate the track(s) to that series.
    def add_tracks(tracks, series = nil)
      type_check(tracks, :track, 'Tracks')
      created = Track.create(tracks)

      return if series.nil?
      return if series.is_a?(Hash) && series.all? { |_k, v| v.nil? }

      if series.is_a?(Hash)
        series = Viva.singularlize(search_series(series), unique: true)
      end
      fail "#{series.class} when Series expected"  unless series.is_a?(Series)
      # Save everything in one transaction
      Track.transaction do
        created = [created] unless created.is_a?(Enumerable)
        created.each do |t|
          t.series = series
          t.save
        end
      end
    end

    # Updates the series with the new information.
    # Hash or a Viva::Database::Series can be given
    def update_series(old, new)
      case old
      when Viva::Database::Series
        current = old
      when Hash
        current = Viva.singularlize(search_series(old), unique: true)
      else
        fail "Invalid class #{series.class} given to update"
      end
      current.update(new)
      current.save
    end

    # Updates the track with new information.
    # Hash or a Viva::Database::Track can be given.
    # Optional Series will relate the track to that series.
    def update_track(old, new, series = nil)
      case old
      when Viva::Database::Track
        current = old
      when Hash
        current = Viva.singularlize(search_tracks(old), unique: true)
      else
        fail "Invalid class #{track.class} given to update"
      end
      current.update(new)
      current.save

      return if series.nil?
      return if series.is_a?(Hash) && series.all? { |_k, v| v.nil? }

      if series.is_a?(Hash)
        series = Viva.singularlize(search_series(series), unique: true)
      end
      fail "#{series.class} when Series expected"  unless series.is_a?(Series)

      current.series = series
      current.save
    end

    # Given a String, Array of String, or a Hash, searches for both the
    # series and titles. Passing a Hash is the same as calling search_strict.
    # Returns an array of Viva::Database::Track that contains matching tracks.
    # Empty Array is returned if nothing applies.
    # TODO: call to search_strict not needed?
    def search(terms)
      return search_strict(terms) if terms.is_a?(Hash)

      terms = [terms] unless terms.is_a?(Enumerable)

      series = Series.all
      tracks = Track.all
      terms.each do |term|
        unless series.empty?
          res = search_series(term, series)
          series = res.empty? ? [] : res
        end

        unless tracks.empty?
          res = search_tracks(term, tracks)
          tracks = res.empty? ? [] : res
        end
      end

      series.each do |s|
        tracks << s.tracks unless s.tracks.empty?
      end

      tracks.flatten
    end

    # Given a Hash, searches for tracks that matches to all the keys.
    # However, the individual keys do not need to be an exact match.
    # Hash can contain either a :track or a :series key that stores a Hash.
    # TODO: Hash of Array of Hash also?
    def search_strict(conditions)
      matches = []

      if !conditions[:series].nil?
        if conditions[:series].is_a?(Hash)
          matched_series = search_series_strict(conditions[:series])
        else
          matched_series = search_series(conditions[:series])
        end

        series_ids = matched_series.map { |s| s.id }
        matches = Track.where(series_id: series_ids)
      end

      if !conditions[:track].nil?
        if conditions[:track].is_a?(Hash)
          matches = search_tracks_strict(conditions[:track], matches)
        else
          matches = search_tracks(conditions[:track], matches)
        end
      end

      matches
    end

    # Searches series in the database.
    # `terms' can either be a Hash, String, or an Array of String.
    # A starting collection can be given as the `base'.
    def search_series(terms, base = nil)
      return search_series_strict(terms, base) if terms.is_a?(Hash)

      terms = [terms] unless terms.is_a?(Enumerable)

      series = base || Series.all
      terms.each do |term|
        escaped = escape_like(term)
        res = series.where('jpn LIKE ? OR eng LIKE ? OR raw LIKE ?',
                           escaped, escaped, escaped)
        return res if res.empty?
        series = res
      end
      series
    end

    # Searches for a series that matches to all the conditions given.
    def search_series_strict(conditions, base = nil)
      fail 'Hash not given' unless conditions.is_a?(Hash)

      matches = base || Series.all
      matches = narrow(matches, 'jpn', conditions)
      matches = narrow(matches, 'eng', conditions)
      matches = narrow(matches, 'raw', conditions)

      matches
    end

    # Given a Hash, String, or an Array of String, searches for tracks that
    # match. When given a Hash, it searches for tracks that match all of the
    # specified conditions.
    def search_tracks(terms, base = nil)
      return search_tracks_strict(terms, base) if terms.is_a?(Hash)

      terms = [terms] unless terms.is_a?(Enumerable)

      sql = 'title LIKE ? OR default_title LIKE ?' \
            ' OR artist LIKE ? OR album LIKE ?'

      tracks = base.nil? ? Track.all : base
      terms.each do |term|
        escaped = escape_like(term)
        res = tracks.where(sql, *([escaped] * 4))

        return res if res.empty?
        tracks = res
      end

      tracks
    end

    def search_tracks_strict(conditions, base = nil)
      fail 'Hash not given' unless conditions.is_a?(Hash)

      matches = base || Track.all
      matches = narrow(matches, 'title', conditions)
      matches = narrow(matches, 'default_title', conditions)
      matches = narrow(matches, 'url', conditions)
      matches = narrow(matches, 'artist', conditions)
      matches = narrow(matches, 'album', conditions)
      matches = narrow(matches, 'scraped', conditions)

      matches
    end

    private

    # Checks for the parameter's data type.
    # Fails when `properties' is not a Hash or an Array of Hash
    def type_check(properties, key, name = nil)
      unless properties.is_a?(Hash) || \
             properties.is_a?(Array) && properties.first.is_a?(Hash)
        what = name || key.to_s.capitalize
        fail "#{what} is #{properties.class} not a Hash nor an Array of Hash"
      end

      true
    end

    # Escapes the special characters used in LIKE and adds '%'
    def escape_like(term)
      "%#{term.gsub(/(?=[\\%_])/, '\\')}%"
    end

    def like(column)
      "#{column} LIKE ?"
    end

    # Narrow down the current_matches with the given condition
    # This method returns current_matches if conditions[key] is nil
    def narrow(current_matches, column_name, conditions, key = nil)
      key = key || column_name.to_sym
      return current_matches if conditions.nil? || conditions[key].nil?

      terms = [conditions[key]].flatten
      res = current_matches

      terms.each do |term|
        case current_matches
        when ActiveRecord::Relation
          res = current_matches.where(like(column_name), escape_like(term))
        when Enumerable
          res = current_matches.flatten.select { |data| data[key].match(term) }
        else
          return current_matches
        end

        return res if res.empty?

        current_matches = res
      end

      res
    end
  end
end
