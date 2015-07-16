# coding: utf-8
require 'spec_helper'

describe Viva::Translator::Wikipedia do

  describe '#eng_title' do
    it 'converts English to Japanese' do
      expect(Viva::Translator::Wikipedia.eng_title('mahouka')).to \
        eq 'The Irregular at Magic High School'
    end
  end

  describe '#jpn_title' do
    it 'converts Japanese to English' do
      expect(Viva::Translator::Wikipedia.jpn_title('mahouka')).to \
        eq '魔法科高校の劣等生'
    end
  end

  describe '#eng_to_jpn_title' do
    it 'finds the title for the equivalent Japanese Wikipedia page' do
      expect(Viva::Translator::Wikipedia.eng_to_jpn_title(
        'The Irregular at Magic High School'
      )).to eq '魔法科高校の劣等生'
      expect(Viva::Translator::Wikipedia.eng_to_jpn_title(
        'Gakuen Alice'
      )).to eq '学園アリス'
    end

    it 'should not find any page' do
      expect(Viva::Translator::Wikipedia.eng_to_jpn_title(
        'List of The Irregular at Magic High School characters'
      )).to eq nil
    end
  end

  describe '#jpn_to_eng_title' do
    it 'finds the title for the equivalent English Wikipedia page' do
      expect(Viva::Translator::Wikipedia.jpn_to_eng_title(
        '魔法科高校の劣等生'
      )).to eq 'The Irregular at Magic High School'
    end

    it 'should not find any page' do
      expect(Viva::Translator::Wikipedia.jpn_to_eng_title(
        '化物語'
      )).to eq nil
    end
  end

  describe '#get_title' do
    let(:url) { 'https://ja.wikipedia.org/wiki/%E3%82%B3%E3%83%BC%E3%83%89%E3%82%AE%E3%82%A2%E3%82%B9_%E5%8F%8D%E9%80%86%E3%81%AE%E3%83%AB%E3%83%AB%E3%83%BC%E3%82%B7%E3%83%A5' }
    let(:title) { 'コードギアス 反逆のルルーシュ' }

    it 'gets the title of the article' do
      expect(Viva::Translator::Wikipedia.get_title(url)).to eq title
    end
  end
end
