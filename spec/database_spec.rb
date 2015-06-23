# coding: utf-8
require 'spec_helper'
# coding: utf-8

describe Viva::Database do
  let(:db) { Viva::Database.new('test.db') }

  # Seed data
  let(:series) do
    [
      {
        jpn: '魔法科高校の劣等生',
        eng: 'The Irregular at Magic High School',
        raw: 'mahouka-koukou-no-rettousei'
      },
      {
        jpn: 'トリニティ・セブン',
        eng: 'Trinity Seven',
        raw: 'trinity-seven'
      },
      {
        jpn: '男子高校の日常',
        eng: 'Daily Lives of High School Boys',
        raw: 'danshi-koukousei-no-nichijou'
      },
      {
        jpn: 'アカネマニアックス〜流れ星伝説剛田〜',
        eng: 'Akane Maniax',
        raw: 'akane-maniax'
      },
      {
        # It has incorrect title...
        jpn: '日常',
        eng: 'Nichijou',
        raw: 'gosick'
      }
    ]
  end

  let(:tracks) do
    [
      {
        title: 'Rising Hope',
        default_title: 'rising hope',
        artist: 'LiSA',
        url: 'http://www.musicaanime.org/aannmm11/519/imagen001.mp3'
      },
      {
        default_title: 'resuscitated hope -tv size-',
        url: 'http://www.musicaanime.org/aannmm11/164/imagen040.mp3'
      },
      {
        default_title: 'arigatou...',
        url: 'http://www.musicaanime.org/aannmm11/803/imagen002.mp3'
      }
    ]
  end

  describe '#add_series' do
    before do
      series.each do |s|
        db.add_series(s)
      end
    end

    it 'should add series to the database' do
      expect(Viva::Database::Series.count).to eq 5
    end
  end

  describe '#add_track' do
    before do
      series.each do |s|
        db.add_series(s)
      end
    end

    context 'one track at a time' do
      it 'adds tracks to the database' do
        db.add_track(tracks[0], series[0][:raw])
        db.add_track(tracks[1], series[3][:raw])
        db.add_track(tracks[2], series[4][:raw])

        expect(Viva::Database::Track.count).to eq 3

      end
      after do
        Viva::Database::Track.all.delete_all
      end
    end

    context 'multiple tracks at once' do
      it 'adds tracks to the databes at once' do
        # Make the associated series for the tracks this
        dummy_series = series[0][:raw]

        db.add_track(tracks, dummy_series)

        expect(Viva::Database::Track.count).to eq 3
        series = Viva::Database::Series.where(raw: dummy_series)
        series_id = series.first.id
        # All of them should be associated with `dummy_series'
        expect(Viva::Database::Track.where(series_id: series_id).count).to eq 3
      end

      after do
        Viva::Database::Track.all.delete_all
      end
    end
  end

  describe 'search' do
    before do
      series.each do |s|
        db.add_series(s)
      end
      db.add_track(tracks[0], series[0][:raw])
      db.add_track(tracks[1], series[3][:raw])
      db.add_track(tracks[2], series[4][:raw])
    end

    describe '#search_series' do
      it 'searches for multiple keywords' do
        res = db.search_series('at Irregular School'.split(' '))
        expect(res.first.jpn).to eq '魔法科高校の劣等生'
      end

      it 'searches using only one keyword' do
        res = db.search_series('at Irregular School')
        expect(res).to be_empty
      end
    end

    describe '#search_tracks' do
      it 'searches using multiple keywords' do
        res = db.search_tracks('tv hope'.split(' '))
        url = 'http://www.musicaanime.org/aannmm11/164/imagen040.mp3'
        expect(res.first.url).to eq url
      end

      it 'searches using one keyword' do
        res = db.search_tracks('hope')
        expect(res.count).to eq 2
      end
    end
  end

  after do
    File.delete('test.db')
  end
end
