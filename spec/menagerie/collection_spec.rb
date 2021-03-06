require 'spec_helper'

require 'fileutils'

describe Menagerie::Collection do
  let(:examples) { 'spec/examples' }
  let(:collection) { Menagerie.new }

  describe '#releases' do
    it 'parses releases in a collection' do
      Dir.chdir("#{examples}/existing") do
        expect(collection.releases.size).to eql 3
        expect(collection.releases.first).to be_a Menagerie::Release
      end
    end

    it 'parses an empty collection as empty' do
      Dir.chdir("#{examples}/empty") do
        expect(collection.releases.size).to eql 0
      end
      Dir.chdir("#{examples}/empty_with_dirs") do
        expect(collection.releases.size).to eql 0
      end
    end

    it 'supports an alternate path for releases' do
      x = Menagerie.new paths: { releases: 'spec/examples/existing/releases' }
      expect(x.releases.size).to eql 3
    end
  end

  describe '#orphans' do
    it 'identifies orphaned artifacts' do
      Dir.chdir("#{examples}/orphaned") do
        expect(collection.orphans.size).to eql 1
        expect(collection.orphans.first).to be_a String
      end
    end

    it 'returns an empty list if there are no orphans' do
      Dir.chdir("#{examples}/existing") do
        expect(collection.orphans.size).to eql 0
      end
    end
  end

  describe '#add_release' do
    before(:each) do
      FileUtils.rm_rf 'spec/examples/scratch'
      FileUtils.cp_r 'spec/examples/existing', 'spec/examples/scratch'
    end

    let(:base_path) { 'spec/examples/scratch' }
    let(:paths) do
      {
        artifacts: "#{base_path}/artifacts",
        releases: "#{base_path}/releases",
        latest: "#{base_path}/latest"
      }
    end
    let(:artifacts) do
      [
        { name: 'a', version: '2.0.0', url: 'https://goo.gl/pWew5I' },
        { name: 'b', version: '3.0.0', url: 'https://goo.gl/fkNplq' }
      ]
    end
    let(:default_collection) { Menagerie.new(paths: paths) }

    it 'rotates existing releases' do
      expect(default_collection.releases.size).to eql 3
      default_collection.add_release(artifacts)
      expect(default_collection.releases.size).to eql 4
    end

    it 'retains a set number of old releases' do
      10.times { default_collection.add_release(artifacts) }
      expect(default_collection.releases.size).to eql 6
    end

    it 'can be configured to allow a differnet number of releases' do
      collection = Menagerie.new(paths: paths, options: { retention: 8 })
      10.times { collection.add_release(artifacts) }
      expect(collection.releases.size).to eql 9
    end

    it 'creates a new release' do
      default_collection.add_release(artifacts)
      expect(default_collection.releases.first.artifacts.size).to eql 2
    end

    it 'reaps orphaned artifacts' do
      FileUtils.touch "#{base_path}/artifacts/a/0.0.4"
      FileUtils.mkdir "#{base_path}/artifacts/d"
      FileUtils.touch "#{base_path}/artifacts/d/0.0.4"
      expect(File.exist?("#{base_path}/artifacts/a/0.0.4")).to be_truthy
      expect(File.exist?("#{base_path}/artifacts/d/0.0.4")).to be_truthy
      default_collection.add_release(artifacts)
      expect(File.exist?("#{base_path}/artifacts/a/0.0.4")).to be_falsey
      expect(File.exist?("#{base_path}/artifacts/d/0.0.4")).to be_falsey
    end

    it 'can be configure to not reap orphaned artifacts' do
      FileUtils.touch "#{base_path}/artifacts/a/0.0.4"
      FileUtils.mkdir "#{base_path}/artifacts/d"
      FileUtils.touch "#{base_path}/artifacts/d/0.0.4"
      expect(File.exist?("#{base_path}/artifacts/a/0.0.4")).to be_truthy
      expect(File.exist?("#{base_path}/artifacts/d/0.0.4")).to be_truthy
      collection = Menagerie.new(paths: paths, options: { reap: false })
      collection.add_release(artifacts)
      expect(File.exist?("#{base_path}/artifacts/a/0.0.4")).to be_truthy
      expect(File.exist?("#{base_path}/artifacts/d/0.0.4")).to be_truthy
    end
  end
end
