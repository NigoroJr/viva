# coding: utf-8
require 'spec_helper'

describe Viva::Database do
  let!(:db) { Viva::Database.new('test.db') }

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

  before(:each) do
    Viva::Database::Track.delete_all if Viva::Database::Track.count != 0
    Viva::Database::Series.delete_all if Viva::Database::Series.count != 0
  end

  describe '#add' do
    context 'track only' do
      it 'adds one track to the database at a time' do
        db.add({track: tracks[0]})
        db.add({track: tracks[0]})
        expect(Viva::Database::Track.count).to eq 2
      end

      it 'adds multiple tracks to the database' do
        db.add({track: tracks})
        expect(Viva::Database::Track.count).to eq tracks.size
      end

    end

    context 'series only' do
      it 'adds one series to the database at a time' do
        db.add({series: series[0]})
        db.add({series: series[0]})
        expect(Viva::Database::Series.count).to eq 2
      end

      it 'adds multiple series to the database' do
        db.add({series: series})
        expect(Viva::Database::Series.count).to eq series.count
      end
    end

    context 'add track with series related' do
      let(:s) { series[1] }

      before do
        db.add_series(s)
      end

      it 'adds a track with the series info' do
        db.add({track: tracks[0], series: s})
        t = Viva::Database::Track.where(default_title: tracks[0][:default_title])
        correct_series = Viva::Database::Series.where(raw: s[:raw]).first
        expect(t.first.series).to eq correct_series
      end
    end

    context 'add nothing' do
      it 'passes an empty Hash to the method' do
        db.add({})
        expect(Viva::Database::Track.count).to eq 0
        expect(Viva::Database::Series.count).to eq 0
      end
    end
  end

  describe '#add_series' do
    it 'should add one series to the database at a time' do
      db.add_series(series[0])
      db.add_series(series[0])
      expect(Viva::Database::Series.count).to eq 2
    end
  end

  describe '#add_tracks' do
    before(:each) do
      db.add_series(series)
      Viva::Database::Track.delete_all
    end

    context 'one track at a time' do
      it 'adds tracks to the database' do
        db.add_tracks(tracks[0])
        db.add_tracks(tracks[1])
        db.add_tracks(tracks[2])

        expect(Viva::Database::Track.count).to eq 3
      end
    end

    context 'multiple tracks at once' do
      it 'adds multiple tracks at once' do
        db.add_tracks(tracks)
        expect(Viva::Database::Track.count).to eq tracks.size
      end
    end

    context 'associate track with series' do
      let (:dummy_series) { series[0][:raw] }

      it 'associates multiple tracks with a series Hash ' do
        # Make the associated series for the tracks this
        db.add_tracks(tracks, {raw: dummy_series})
        # All of them should be associated with `dummy_series'
        series = Viva::Database::Series.where(raw: dummy_series)
        matches = Viva::Database::Track.where(series: series)
        expect(matches.count).to eq tracks.size
      end

      it 'relates a track with a Series object' do
        series = Viva::Database::Series.all.sample
        t = tracks.sample
        db.add_tracks(t, series)
        new_t = Viva::Database::Track.where(default_title: t[:default_title])
        expect(new_t.first.series).to eq series
      end
    end

    after(:each) do
      Viva::Database::Track.delete_all
    end
  end

  describe 'update' do
    before(:each) do
      db.add_series(series)
      db.add_tracks(tracks)
    end

    it 'updates a track' do
      new_title = 'updated title'
      to_update = tracks[1]
      db.update_track(to_update, {title: new_title})
      result = Viva::Database::Track.where(title: new_title).first
      expect(result.default_title).to eq to_update[:default_title]
    end

    it 'updates a series' do
      new_title = 'アンパンマン、新しいタイトルよ！'
      to_update = series.sample
      db.update_series(to_update, {jpn: new_title})
      result = Viva::Database::Series.where(jpn: new_title).first
      expect(result.raw).to eq to_update[:raw]
    end

    it 'updates to an empty hash' do
      to_update = Viva::Database::Track.all.sample
      db.update_track(to_update, {})
      updated = Viva::Database::Track.find(to_update.id)
      expect(updated).to eq to_update
    end

    it 'updates a track related to a Series object' do
      to_update = Viva::Database::Track.all.sample
      new_series = Viva::Database::Series.all.sample
      db.update_track(to_update, {}, new_series)
      updated = Viva::Database::Track.find(to_update.id)
      expect(updated.series).to eq new_series
    end

    it 'updates a track related to a series Hash' do
      to_update = Viva::Database::Track.all.sample
      new_series = series.sample
      db.update_track(to_update, {}, {raw: new_series[:raw]})
      updated = Viva::Database::Track.find(to_update.id)
      expect(updated.series.jpn).to eq new_series[:jpn]
    end

    after(:each) do
      Viva::Database::Series.delete_all
      Viva::Database::Track.delete_all
    end
  end

  describe 'search' do
    describe 'terms' do
      before do
        db.add_series(series)

        raw_series = series.map { |s| {raw: s[:raw]} }
        db.add_tracks(tracks[0], raw_series[0])
        db.add_tracks(tracks[1], raw_series[3])
        db.add_tracks(tracks[2], raw_series[4])
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

    describe 'strict search' do
      before do
        db.add_series(series)
        raw_series = series.map { |s| {raw: s[:raw]} }
        db.add_tracks(tracks[0], raw_series[0])
        db.add_tracks(tracks[1], raw_series[3])
        db.add_tracks(tracks[2], raw_series[4])
      end

      describe '#search_strict' do
        it 'searches using one condition' do
          conditions = {series: {jpn: '高校'}}
          result = db.search_strict(conditions)
          # Just one because no tracks for 男子高校の日常 in seed data
          expect(result.count).to eq 1
        end

        it 'searches using two conditions' do
          conditions = {
            series: {
              jpn: '高校',
              eng: 'Magic',
            }
          }
          result = db.search_strict(conditions)
          expect(result.first.series.raw).to eq 'mahouka-koukou-no-rettousei'
        end

        it 'searches with both series and track' do
          conditions = {
            series: {
              jpn: '高校',
            },
            track: {
              default_title: 'hope',
            },
          }
          result = db.search_strict(conditions)
          expect(result.first.title).to eq 'Rising Hope'
        end
      end

      describe '#search_series_strict' do
        it 'searches for a series using one condition' do
          conditions = {jpn: '高校'}
          result = db.search_series_strict(conditions)
          expect(result.count).to eq 2
        end

        it 'searches for a series using two conditions' do
          conditions = {jpn: '高校', eng: 'Magic'}
          result = db.search_series_strict(conditions)
          expect(result.first.raw).to eq 'mahouka-koukou-no-rettousei'
        end
      end

      describe '#search_tracks_strict' do
        it 'searches for a track using one condition' do
          conditions = {default_title: 'rising'}
          results = db.search_tracks_strict(conditions)
          expect(results.first.artist).to eq 'LiSA'
        end

        it 'searches for a track using two conditions' do
          conditions = {default_title: 'hope', url: '164'}
          results = db.search_tracks_strict(conditions)
          expected_title = 'resuscitated hope -tv size-'
          expect(results.first.default_title).to eq expected_title
        end
      end
    end
  end

  describe '#to_s' do
    before do
      db.add_series(series)
      raw_series = series.map { |s| {raw: s[:raw]} }
      db.add_tracks(tracks[0], raw_series[0])
    end

    it 'returns a simple string representation' do
      track = Viva::Database::Track.where(default_title: 'rising hope')
      str = track.first.to_s
      expect(str).to eq 'Rising Hope from 魔法科高校の劣等生'
    end

    it 'returns a detailed string representation' do
      track = Viva::Database::Track.where(default_title: 'rising hope')
      str = track.first.to_s(detailed: true)
      expected = <<EOF
Rising Hope from 魔法科高校の劣等生
Artist: LiSA
EOF
      expect(str).to eq expected.strip
    end
  end

  after(:all) do
    File.delete('test.db')
  end
end
