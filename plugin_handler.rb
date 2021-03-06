module PluginHandler
  def self.plugins
    @plugins ||= []
  end

  def self.add_plugin(plugin)
    self.plugins << plugin
  end

  def self.commands
    output = []
    plugins.each do |plugin|
      next unless plugin.respond_to?(:commands)
      output += Array(plugin.commands)
    end
    output
  end

  def self.matchers
    commands.collect{|c| c.matchers}
  end

  def self.find_commands(matcher)
    commands.select{|c| c.matchers =~ /#{matcher}/}
  end

  def self.command(matcher)
    find_commands(matcher).first
  end
end

class PluginCommand
  attr_accessor :matchers, :description

  def initialize(matchers, description)
    self.matchers    = matchers
    self.description = description
  end

  def display_row
    [matchers, description]
  end
end
