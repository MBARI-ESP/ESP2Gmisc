#################  objectspace.rb -- brent@mbari.org  ##################
# $Source$
# $Id$
#
#  ObjectSpace enhancements (useful for debugging and introspection) 
#
########################################################################

require 'mbari'

module ObjectSpace
  def self.each (classOrMod=Object, &block)
  #first remove unref'd garbage, then iterate over the objects
    garbage_collect
    each_object (classOrMod, &block)
  end
  
  def self.each_reference (target, klass=nil, &block)
  #execute block with each object that references target
  #useful if you can't figure out why something won't GC
  #VERY SLOW!
    n=0
    block=proc {|mod, names| 
      puts "#{mod}#{names ? "::"+names.inspect : ""}"} unless block
    unless klass
      refs=global_variables
      refs.delete_if {|v| !(eval v).eql? target}
      n+=refs.size
      refs.each &block
      klass=Object
    end
    each (klass) {|obj|
      refs=obj.instance_variables
      refs.delete_if {|v| !(obj.instance_eval v).eql? target}
      if obj.kind_of? Module
        classRefs=obj.constants_at+obj.class_variables
        classRefs.delete_if {|v| !(obj.class_eval v).eql? target}
        refs+=classRefs
      end
      unless refs.empty?
        n+=refs.size
        block[obj, refs]
      end
    }
    n
  end
end
 
