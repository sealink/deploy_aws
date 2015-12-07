require 'deploy/version'
require 'yaml'
require 'rugged'
require 'deploy/repository'

module Deploy
  class Deployment
    def self.settings
      @settings ||= YAML.load(File.read(settings_path))
    end

    def self.deploy(tag)
      puts "Configured with settings #{settings}"

      repo = Repository.new
      if repo.index_modified?
        fail "You have staged changes! Please sort your life out mate, innit?"
      end
    end

    private

    def self.settings_path
      File.expand_path(File.dirname(__FILE__) + '/../config/settings.yml')
    end
  end
end
