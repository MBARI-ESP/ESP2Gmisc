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

require 'mbarilib'  #sundry 'C' extensions including Kernel.doze method

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
    alias_method newId, oldId unless instance_methods.include? (newId.to_s)
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
  def intern  #Symbol class overrides this. All classes respond to it
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
  def with hash
  #assign fields of struct specified in given hash(-like) object
    hash.each {|fieldName, value| self[fieldName]=value }
    self
  end

end

