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
end
