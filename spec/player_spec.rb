require 'spec_helper'

describe Viva::Player do
  let(:p1) do
    Viva::Player.new('http://c.mp3c.cc/c.php?q=-69837934_290955473/')
  end
  let(:p2) do
    Viva::Player.new('http://50.7.37.2/ost/senki-zesshou-symphogear-g-op-single-vitalization/twamdoohsr/01%20-%20Vitalization.mp3')
  end

  describe '#play' do
    it 'plays the given URL' do
      # Just check whether it runs without crashing or not
      expect { p1.play }.not_to raise_error
    end
  end

  describe '#save' do
    it 'saves the given URL to a file' do
      expect(p1.save('hoge.mp3')).to satisfy { File.exists?('hoge.mp3') }
    end

    after do
      File.delete('hoge.mp3')
    end
  end

  describe '#save_and_play' do
    it 'saves and plays the given URL' do
      expect(p2.save_and_play('piyo.mp3')).to satisfy do
        File.exists?('piyo.mp3')
      end
    end

    after do
      File.delete('piyo.mp3')
    end
  end
end
