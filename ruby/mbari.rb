##################  generic.rb -- brent@mbari.org  #####################
# $Source$
# $Id$
#
#  MBARI Generic (application-independent) utilites
#
#  Selected Methods:
#   Module.rename_method -> alias_method only if alias dosn't already exist
#   ObjectSpace.each -> search after collecting the trash
#   Hash.join -> convert Hash to a String Array
#
########################################################################

class Module
  private
  def rename_method newId,oldId
    alias_method newId, oldId unless instance_methods.include? (newId.to_s)
  end
end

module ObjectSpace
  def self.each (classOrMod=Object, &block)
  #first remove unref'd garbage, then iterate over the objects
    garbage_collect
    each_object (classOrMod, &block)
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
