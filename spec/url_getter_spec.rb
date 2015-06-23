require 'spec_helper'

describe Viva::URLGetter do

  describe '#get' do
    context 'both' do
      it 'returns the actual URL of the track' do
        series = 'mahouka-koukou-no-rettousei'
        track = 'rising hope'
        url = 'http://www.musicaanime.org/aannmm11/519/imagen001.mp3'
        expect(Viva::URLGetter.get(series, track)).to eq url
      end
    end
    context 'unraw series' do
      it 'returns the actual URL of the track' do
        series = 'true tears'
        track = 'reflectia'
        url = 'http://www.musicaanime.org/aannmm11/255/imagen002.mp3'
        expect(Viva::URLGetter.get(series, track)).to eq url
      end
    end
    context 'series only' do
      it 'returns the dictionary of available tracks' do
        expect(Viva::URLGetter.get('mahouka-koukou-no-rettousei')).to \
          be_kind_of(Hash)
        expect(Viva::URLGetter.get('foobar')).to eq nil
      end
    end
  end

  describe '#search' do
    describe 'both' do
      it 'searches using both track and series' do
        expect(Viva::URLGetter.search(['mahouka', 'rising hope'])).not_to \
          be_empty
      end
    end
    describe 'track only' do
      it 'searches using only track name' do
        expect(Viva::URLGetter.search('reflectia').size).to eq 1
      end
    end
    describe 'series only' do
      it 'searches using only series name' do
        expect(Viva::URLGetter.search('jormungand')).not_to \
          be_empty
      end
    end
    describe 'invalid utf8 string' do
      it 'performs searchs where results have invalid utf8 strings' do
        expect {Viva::URLGetter.search('kamisama no memo') }.not_to raise_error
      end
    end
  end

  describe '#closest_raw_name' do
    it 'finds closest matching raw series name' do
      # Dead-on match
      title = 'ano hi mita hana no namae o bokutachi wa mada shirana'
      raw = 'ano-hi-mita-hana-no-namae-o-bokutachi-wa-mada-shirana'
      expect(Viva::URLGetter.closest_raw_name(title)).to eq raw
      expect(Viva::URLGetter.closest_raw_name(
        'mahouka-koukou-no-rettousei'
      )).to eq 'mahouka-koukou-no-rettousei'
      expect(Viva::URLGetter.closest_raw_name(
        'arpeggio of blue steel'
      )).to eq 'arpeggio-of-blue-steel'
      # A bit different
      expect(Viva::URLGetter.closest_raw_name('Steins; Gate')).to \
        eq 'steins-gate'
      # Totally different
      expect(Viva::URLGetter.closest_raw_name('foobar')).to eq nil
      expect(Viva::URLGetter.closest_raw_name('some bogus title')).to \
        eq nil
    end
  end

  describe '#get_tracks' do
    it 'returns the available tracks' do
      # Already raw
      expect(Viva::URLGetter.get_tracks('mahouka-koukou-no-rettousei')).not_to \
        be_empty
      expect(Viva::URLGetter.get_tracks('arpeggio of blue steel')).not_to \
        be_empty
      # A bit different
      expect(Viva::URLGetter.get_tracks('Steins; Gate')).not_to \
        be_empty
      # Totally different
      expect(Viva::URLGetter.get_tracks('foobar')).to eq nil
      expect(Viva::URLGetter.get_tracks('some bogus title')).to \
        eq nil
    end
  end

  describe '#series_names' do
    it 'returns the available series names' do
      expect(Viva::URLGetter.series_names).not_to be_empty
    end
  end
end
