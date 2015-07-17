require 'active_record'
require 'unicode/display_width'

class Viva
  class Database
    # Series
    class Series < ActiveRecord::Base
      has_many :tracks

      def print(i = nil, name_width = 50)
        name = jpn || eng || raw
        padding = ' ' * (name_width - name.display_width)
        printf "%2s %s%s\n",
          i || '',
          name,
          padding
      end

      def width
        column = jpn || eng || raw
        column.display_width
      end

      def to_s(detailed: false)
        str = ''
        str += "Japanese: #{jpn}\n" unless jpn.nil?
        str += "English: #{eng}\n" unless eng.nil?

        if detailed
          str += "Raw: #{raw}"
          str += " (Series ##{series_number})" unless series_number.nil?
          str += "\n"
        end

        str
      end
    end

    # Track
    class Track < ActiveRecord::Base
      belongs_to :series

      # TODO: Other info such as artist, album
      def print(i = nil, name_width = 50)
        name = title || default_title
        padding = ' ' * (name_width - name.display_width)
        series_name = series.jpn || series.eng || series.raw unless series.nil?
        printf "%2s %s%s %s\n",
          i || '',
          name,
          padding,
          series_name
      end

      def width
        column = title || default_title
        column.display_width
      end

      def to_s(detailed: false)
        str = title || default_title
        if series
          name = series.jpn || series.eng || series.raw
          str = format '%s from %s', str, name
        end

        if detailed
          additional = []
          additional << format('Artist: %s', artist) unless artist.nil?
          additional << format('Album: %s', album) unless album.nil?
          additional << format('URL: %s', url)
          str = format "%s\n%s", str, additional.join(' ')
        end

        str
      end
    end

    # Initialize tables
    class InitSchema < ActiveRecord::Migration
      def up
        create_table :series do |t|
          t.string  :raw, null: false
          t.string  :jpn
          t.string  :eng
          t.integer :series_number
        end

        create_table :tracks do |t|
          t.string  :title
          t.string  :default_title, null: false
          t.string  :url, null: false
          t.string  :artist
          t.string  :album
          t.boolean :scraped, default: false

          t.integer :series_id
        end
      end

      def down
        drop_table :series
        drop_table :tracks
      end
    end
  end
end
