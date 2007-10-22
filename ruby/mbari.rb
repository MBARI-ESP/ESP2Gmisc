####################  mbari.rb -- brent@mbari.org  #####################
# $Source$
# $Id$
#
#  MBARI Generic (application-independent) utilites
#
#  Selected Methods:
#   Module.rename_method -> alias_method only if alias dosn't already exist
#   Module.constants_at -> list of constants def'd in Module
#   Hash.join -> convert Hash to a String Array
#
########################################################################

if defined? Mutex and Mutex.instance_methods.include? :sleep

  module Kernel  #v1.9-mbari sleep clears Thread.critical
    alias_method :doze, :sleep
  end

  class String
    def /(index)
      (i=self[index]) && i.ord
    end
  end
  
  class Hash
    def index value
      key value
    end
  end

else  #need our 'C' extension for older ruby versions

  begin
    require 'mbarilib'  #sundry 'C' extensions including Kernel.doze method
  rescue LoadError
    STDOUT.puts "Warning:  missing mbarilib extension"
  end
  
  class String
    def ord
      self[0]
    end
    def /(index)
      self[index]
    end
  end
  
end


class Module
  unless defined? constants_at
    def constants_at
    #return Array of names of constants defined in specified module
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
  
  private
  def rename_method newId,oldId
    alias_method newId, oldId unless respond_to? newId
  end
end
 
class Hash
  def join (sep = " => ", m=:to_s)
  # most useful for displaying hashes with puts hsh.join
    strAry = []
    each {|key,value| strAry << key.inspect+sep+value.method(m).call}
    strAry
  end
end

class Object
  rename_method :type, :class
  
  def intern  #Symbol class overrides this. All classes respond to it
    self
  end
  def intern= identifier  #return identifier for Object.intern
    eval "class << self; def intern; #{identifier.inspect}; end; end"
    identifier
  end
  
  def deepCopy
    Marshal::load(Marshal::dump(self))
  end
  
  def reallyEqual? other  #for recursive equality tests
    self == other
  end
  
  def with hash
  #assign instance variables specified in given hash
    hash.each do |parameter, value|
      send ((parameter.to_s<<?=).intern, value)
    end
    self
  end  
end

class Class  #create an uninitialized class instance
#see http://whytheluckystiff.net/articles/rubyOneEightOh.html
  def allocate
    class_name = to_s
    Marshal.load "\004\006o:"+(class_name.length+5).chr+class_name+"\000"
  end
end

class Struct
  def reallyEqual? other
  #built-in Struct#== gets confused when a singleton
  #method is associated with the Struct.  This version does not.
    unless equal? other.id
      return false unless type.name == other.type.name
      for i in 0...length
        return false unless self[i].reallyEqual? other[i]
      end
    end
    true
  end
end


class Fixnum
  def ord
  #this is for compatibility with Ruby v1.9
    self
  end
end


