=begin

  plugin.rb - Plug-in Object Framework

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'thread'
require 'forwardable'
require 'observer'

module Plugin

  class Manager

    include Observable
    extend Forwardable

    attr_reader(:path)

    def_delegator(:@plugins, :[])
    def_delegator(:@plugins, :[], :plugin)
    def_delegator(:@plugins, :keys, :names)
    def_delegator(:@plugins, :values, :plugins)
    def_delegator(:@plugins, :values, :loaded_plugins)

    def initialize(path, suffix=".rb")
      @path = path
      @suffix = suffix
      @plugins = {}
      @validator = nil
      @scan_mutex = Mutex.new
    end

    private

    def new_sandbox(name)
      sandbox = Module.new
      manager = self
      sandbox.instance_eval do
	@manager = manager
	@name = name
      end
      sandbox.instance_eval %Q{
	def register(plugin)
	  @manager.register_plugin(@name, plugin)
	end
      }
      sandbox
    end

    public

    def set_validator(&validator)
      @validator = validator
    end

    def register_plugin(name, plugin)
      @validator.call(name, plugin) if @validator
      @plugins[name] = plugin
    end

    private

    def load_plugin(name)
      begin
	filename = File.join(@path, name)
	code = File.open(filename) do |file| file.read end
	new_sandbox(name).module_eval(code)
      rescue StandardError, ScriptError => exception
	STDERR.puts(exception)
	STDERR.puts(exception.backtrace)
      end
    end

    public

    def found_plugins
      Dir.glob(File.join(@path, "**", "*" + @suffix)).map do |name|
	File.join(name.split(File::SEPARATOR)[1..-1])
      end
    end

    def scan
      @scan_mutex.synchronize do
	found_plugins.each do |name|
	  load_plugin(name)
	end
      end
    end

  end

  class AutoRescanManager < Manager

    attr_accessor(:interval)

    def initialize(path, suffix=".rb", interval=60)
      super(path)
      @interval = interval
      @timestamps = {}
      @thread = nil
    end

    def register_plugin(name, plugin)
      super(name, plugin)
      @timestamps[name] = Time.now
    end

    def rescan
      @scan_mutex.synchronize do
	found_plugins.each do |name|
	  filename = File.join(@path, name)
	  if @timestamps[name].nil? or
	      @timestamps[name] < File.mtime(filename)
	    load_plugin(name)
	  end
	end
      end
    end

    def start
      @thread = Thread.start do
	loop do
	  rescan
	  Kernel.sleep(@interval)
	end
      end
    end

  end

end

if __FILE__ == $0

  manager = Plugin::AutoRescanManager.new(ARGV[0])
  manager.interval = 10
  manager.set_validator do |name, plugin|
    unless Class === plugin
      raise
    end      
    unless plugin.respond_to?(:__plugin_info)
      raise
    end
    # check user config and decide whether load or not
    # unless user_config[name]
    #   raise
    # end
  end

  p(manager.found_plugins)
  p(manager.plugins)
  manager.scan
  p(manager.plugins)

  manager.start

  loop do
    manager.plugins.each do |plugin|
      p([plugin.__plugin_info, plugin.new])
    end
    Kernel.sleep(10)
  end

end
