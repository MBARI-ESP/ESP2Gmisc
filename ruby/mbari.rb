####################  mbari.rb -- brent@mbari.org  #####################
# $Source$
# $Id$
#
#  MBARI Generic (application-independent) utilites
#
#  Selected Methods:
#   Module.rename_method -> alias_method only if alias dosn't already exist
#   Module.constants_at -> list of constants def'd in Module
#   ObjectSpace.each -> search after collecting the trash
#   Hash.join -> convert Hash to a String Array
#
########################################################################

class Module
  def constants_at
  #return Array of names of constants defined at specified module
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

class Symbol
  def intern  #just for mathematical completeness!
    self
  end
end
