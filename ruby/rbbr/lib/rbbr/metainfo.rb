=begin

  rbbr/metainfo.rb - API for Meta-level Information

  $Author$
  $Date$

  Copyright (C) 2002 Ruby-GNOME2 Project

  Copyright (C) 2000-2002 Hiroshi Igarashi <iga@ruby-lang.org>

  This program is free software.
  You can distribute/modify this program under
  the terms of the Ruby Distribute License.

=end

require 'find'

class Object
  alias :type :class  if defined?(:class)
end
  
class Module
  private
  def inner_name
    name.split("::")[-1]
  end
  public
  def outer_name
    onames = name.split("::")[0..-2]
    if self == Object
      nil
    elsif onames == nil
      "Object"
    elsif onames.empty?
      "Object"
    else
      onames.join("::")
    end
  end
  def outer_module
    if outer_name.nil?
      nil
    else
      eval(outer_name)
    end
  end
  protected
  def _outer_modules
    if outer_module.nil?
      [self]
    else
      outer_module._outer_modules + [self]
    end
  end
  public
  def outer_modules
    _outer_modules - [self]
  end
end

unless Module.method_defined?(:constants_at)

  class Module
    def constants_at
      acs = ancestors
      cs = constants
      if acs.length > 1
        acs[1..-1].each do |ac|
          both = ac.constants & cs
          both = both.select{|c| ac.const_get(c) == const_get(c)}
          cs -= both if both
        end
      end
      cs
    end
  end

end

class Module
  unless Module.method_defined?(:included_modules_at)
    def included_modules_at
      ams = ancestors
      case ams.size # > 0
      when 1 # root modules
	[]
      when 2 # 2nd gen. modules and class Object
	[ams[1]]
      else   # ams.size>2  other modules and classes
	ims = ams
	i = 1
	while i < ams.size
	  m = ams[i]
	  if m.type == Class
	    ims -= m.ancestors
	    break
	  end
	  ims -= m.included_modules_at
	  i += 1
	end
	ims - [self]
      end
    end
  end

end

module RBBR

  module MetaInfo

    class ModuleNesting

      def initialize
	update
      end

      def add_module(outer, inner)
	unless @tree.key?(outer)
	  @tree[outer] = []
	end
	@tree[outer] << inner
      end

      def update
	@tree = {}
	ObjectSpace.each_object(Module) do |m|
	  add_module(m.outer_module, m)
	end
      end

      def inner_modules(modul, node_only=true)
	if node_only
	  @tree[modul].select do |m|
	    not inner_modules(m, false).empty?
	  end
	else
	  if @tree.key?( modul)
	    @tree[modul].dup
	  else
	    []
	  end
	end
      end
      
      def true_constants(modul)
	modul.constants_at.select do |name|
	  not modul.const_get(name).is_a?(Module)
	end
      end

      class << self
	
	def inner_modules( modul, node_only=true )
	  modul.constants_at.collect do |name|
	    [name, modul.const_get( name )]
	  end.select do |name, constant|
	    constant.is_a?( Module ) and (constant != Object) and
	      not (node_only and inner_modules( constant, false ).empty?)
	  end.collect do |name, constant|
	    constant
	  end
	end
	
	def true_constants( modul )
	  modul.constants_at.select do |name|
	    not modul.const_get( name ).is_a?( Module )
	  end
	end
	
      end
      
    end
    
    class ModuleDAG
      
      def initialize
	@dag = {}
	@roots = []
      end
      
      def roots
	@roots.dup
      end
      def arc( sm )
	a = @dag[ sm ]
	if a
	  a.dup
	else
	  []
	end
      end
      
      def add( super_module, modul )
	if super_module.nil?
	  @roots |= [ modul ]
	else
	  if @dag[ super_module ].nil?
	    @dag[ super_module ] = []
	  end
	  @dag[ super_module ] |= [ modul ]
	end
      end
      
      private
      def _each( super_module, modul, &block )
	sub_modules = @dag[ modul ]
	Kernel.catch( :prune ) do
	  block.call( super_module, modul, :in )
	  if sub_modules
	    sub_modules.sort do |x, y|
	      x.name <=> y.name
	    end.each do |sub_module|
	      _each( modul, sub_module, &block )
	    end
	  end
	  block.call( super_module, modul, :out )
	end
      end
      
      public
      def each( &block )
	@roots.sort do |x, y|
	  x.name <=> y.name
	end.each do |root|
	  _each( nil, root, &block )
	end
      end
      
      class << self
	
	private
	
	def add_module( dag, m )
	  if m.is_a?( Class )
	    sc = m.superclass
	    dag.add( sc, m )
	    add_module( dag, sc ) unless sc.nil?
	  end
	  ims = m.included_modules_at
	  if ims.empty? and (not m.is_a?( Class ))
	    dag.add( nil, m )
	  else
	    ims.each do |im|
	      dag.add( im, m )
	      add_module( dag, im )
	    end
	  end
	end
	
	public
	
	def full_module_dag
	  dag = ModuleDAG.new
	  ObjectSpace.each_object(Module) do |m|
	    add_module(dag, m)
	  end
	  dag
	end
	
	def filtered_module_dag( namespaces )
	  dag = ModuleDAG.new
	  ObjectSpace.each_object(Module) do |m|
	    if namespaces.find {|ns| m.outer_module == ns or m == ns}
	      add_module(dag, m)
	    end
	  end
	  dag
	end
	
      end
      
    end
    
    class Library
      attr_reader(:feature, :filename, :libtype)
      
      def initialize(feature, filename, libtype)
	@feature = feature
	@filename = filename
	@libtype = libtype
      end

      def <=>(other)
	case other
	when type
	  feature <=> other.feature
	else
	  raise ArgumentError.new
	end
      end
      
      def self.libraries
	libraries = {}
	($: - ["."]).each do |path|
	  path_prefix = Regexp.compile(path + File::Separator)
	  Find.find(path) do |filename|
	    if /(.*)\.(rb|so)$/ === filename
	      lm = Regexp.last_match
	      feature = lm[1].gsub(path_prefix, "")
	      libtype = lm[2]
	      unless libraries.has_key?(filename)
		libraries[filename] = new(feature, filename, libtype)
	      end
	    end
	  end
	end
	libraries.values
      end
      
    end

  end

end
