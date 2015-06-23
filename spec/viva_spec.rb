require 'spec_helper'

describe Viva do
  let!(:v) { Viva.new('test.db') }
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

  before do
    series.each do |s|
      v.db.add_series(s)
    end

    v.db.add_track(tracks[0], series[0][:raw])
    v.db.add_track(tracks[1], series[3][:raw])
    v.db.add_track(tracks[2], series[4][:raw])
  end

  describe '#search_and_play' do
    it 'should play rising hope' do
      allow(ARGF).to receive(:gets) { '0' }

      expect{ v.search_and_play('rising hope') }.not_to raise_error
    end

    it 'should play resuscitated hope -tv size-' do
      allow(ARGF).to receive(:gets) { "\n" }

      expect do
        v.search_and_play('resuscitated hope -tv size-')
      end.not_to raise_error
    end

    it 'should play arigato... (off vocal)' do
      allow(ARGF).to receive(:gets) { '3' }

      expect{ v.search_series_and_play('gosick') }.not_to raise_error
    end
  end

  after do
    File.delete('test.db')
  end
end
