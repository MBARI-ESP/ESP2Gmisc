##############  sourceref.rb   2/13/03  brent@mbari.org  ###################
#
#  The SourceRef class relies on a patched version of ruby/eval.c
#  to provide access to the source file and line # where every Method
#  or Proc is defined.  SourceRef is a container for these and implements
#  methods to:
#
#    list source code to stdout,
#    view source code in an editor,
#    edit source code
#    reload source code
#
#  This file also adds methods to Object and Module to list, view, and
#  edit methods directly as a convenience.
#
#  Examples:
#     SourceRef.instance_method (:list).source  ==> ./sourceref.rb:47
#     SourceRef.instance_method (:list).edit    ==>  opens an editor window
#     SourceRef.source[:list].edit              ==>  opens an editor window
#     Date.edit    ==> edits all files that define methods in class Date
#     Date.source  ==> returns hash of Date methods to SourceRefs
#     puts Date.source.join  ==> display Data methods with SourceRefs
#     Date.sources ==> returns the list of files containing Date methods
#     Date.reload  ==> (re-)loads Date.sources
#
############################################################################


class SourceRef   #combines source_file_name and line number

  def initialize (file_name, line=0)
    @file = file_name
    @line = line
  end

  attr_reader :file, :line
  
  def to_s
    return file unless line > 0
    file+':'+line.to_s
  end
  
  def list (lineCount=16, lineOffset=0)
  # return the next lineCount lines of source text
  # or "" if no source is available
    text = ""; lineno=0
    begin
      File.open (file) {|f|
        2.upto(line+lineOffset) { f.readline; lineno+=1 }
        1.upto(lineCount) { text += f.readline; lineno+=1 }
      }
    rescue EOFError  # don't sweat EOF unless its before target line #
      if lineno < line
        $stderr.puts "--> Truncated ruby source file: #{self}"
      end
    rescue
      $stderr.puts "--> Missing ruby source: #{self}"
    end
    text
  end
  
  def edit (options=nil, readonly=false)
  # start an editor session on file at line
  # If X-windows display available, try nedit client, then nedit directly
    if ENV["DISPLAY"]
      neditArgs = "-lm Ruby #{options} '#{file}'"
      neditArgs = "-line #{line} " + neditArgs if line > 0
      neditArgs = "-read " + neditArgs if readonly
      return self if system ("nclient -noask -svrname ruby #{neditArgs}") || 
                     system ("nedit #{neditArgs}")
    end
  # if all else fails, fall back on the venerable 'vi'
    system ("vi #{"-R " if readonly} + #{file}")
    self
  end
  
  def view (options=nil)
  # start a read-only editor session on file at line
    edit (options, true)
  end
  
  def reload
  # load file referenced by receiver
    begin
      load file
    rescue LoadError
      $stderr.puts "--> Missing ruby source fle: #{file}" 
    end
  end
  

  module Code #for objects supporting source_file_name & source_line

    def source
      SourceRef.new (source_file_name, source_line)
    end
    
    (OPS = [ :list, :edit, :view, :reload ]).each {|m|
      define_method (m) { | *args | source.method(m).call(*args) }
    }

  end #module SourceRef::Code

end #class SourceRef

#mix source code manipulation utilites into the appropriate classes
class Proc; include SourceRef::Code; end
class Method; include SourceRef::Code; end
  
class Module

  def sourceHash (methodType, methodNameArray)
  # private method to build a hash of methodNames to sourceRefs
  # exclude methods for which no ruby source is available
    h = {};
    methodGetter = method(methodType)
    methodNameArray.each {|m|
      m = m.intern
      src = methodGetter[m].source
      h[m] = src if src.line > 0 && src.file != "(eval)"
    }
    h
  end
  private :sourceHash    

  def singleton_source
  # return hash on receiver's singleton methods to corresponding SourceRefs
    sourceHash (:method, singleton_methods)
  end
  
  def instance_source (includeAncestors=false)
  # return hash on receiver's instance methods to corresponding SourceRefs
  #        optionally include accessible methods in ancestor classes
    sourceHash (:instance_method,
                private_instance_methods+
                protected_instance_methods(includeAncestors)+
                public_instance_methods(includeAncestors))
  end
  
  def source (*args)
  # return hash on receiver's methods to corresponding SourceRefs
    singleton_source.update(instance_source(*args))
  end
    
  def sources (*args)
  # return array of unique source file names for all receiver's methods
    (singleton_source.values+instance_source(*args).values).collect{|s|
       s.file
    }.uniq.collect{|fn| SourceRef.new(fn)}    
  end
    
  def reload (*args)
  # load all source files that define receiver's methods
    sources(*args).each {|s| s.reload}
  end
  
  def edit (*args)
  # start editor sessions on all files that define receiver's methods
    sources(*args).each{|srcFile| srcFile.edit}
  end

  def view (*args)
  # start read-only editor sessions on files containing receiver's methods
    sources(*args).each{|srcFile| srcFile.view}
  end
  
  def list (*args)
  # return first few lines of all files containing self.methods
    result=""
    sources.each{|srcFile| result+=srcFile.list (*args)}
    result
  end

end


class String
  def to_srcRef
  # parse a source reference from string of form fn:line#
    strip!
    a = split(sep=':')
    return SourceRef.new (self, 0) if a.length < 2
    SourceRef.new (a[0..-2].join(sep), a[-1].to_i)
  end
end

  
class Hash

  def join (sep = " => ")
  # most useful for displaying hashes with puts hsh.join
    strAry = []
    each {|key,value| strAry << key.inspect+sep+value.to_s}
    strAry
  end
  
end
       

module Kernel   #add convenient commands for viewing source code

  SourceRef::Code::OPS.each {|m|
    define_method (m) { |src, *args|      
      if src.kind_of?(Module)
        src.sources.each {|srcRef| srcRef.method(m).call (*args)}
      else 
        if src.kind_of?(Method) || src.kind_of?(Proc)
          src = src.source
        else
          src = src.to_srcRef if src.respond_to? :to_srcRef       
        end
        src.method(m).call (*args)
      end
    }
  }
      
end  
