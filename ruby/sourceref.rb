##################  sourceref.rb -- brent@mbari.org  #####################
# $Source$
# $Id$
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
#  This file also adds methods to Object and Module to list, view, 
#  edit, and reload methods and modules as a convenience.
#
#  Examples:
#     SourceRef.instance_method (:list).source  ==> ./sourceref.rb:47
#     SourceRef.instance_method (:list).edit    ==>  opens an editor window
#     (SourceRef/:list).edit                    ==>  opens same window
#     SourceRef.source[:list].view              ==>  opens same window r/o
#     Date.edit    ==> edits all files that define methods in class Date
#     Date.source  ==> returns hash of Date methods to SourceRefs
#     puts Date.source.join  ==> display Data methods with SourceRefs
#     Date.sources ==> returns the list of files containing Date methods
#     Date.reload  ==> (re-)loads Date.sources
#
#   With a version of irb.rb modified to store the last backtrace,
#   the following features are available at the irb prompt:
#
#     list|edit|view|reload  Module|Method|Integer|Symbol|Exception|String
#
#   Module operates on the list of files that comprise the Module
#   Method operates on the text of the Method
#   Integer n operates on the most recent backtrace at level n
#   Symbol :sym searches backtrace for level corresponding to :sym
#   Exception operates on the source where the exception occured
#   String fn:nnn operates on file "fn" at line nnn
#   no argument is equivalent to backtrace level 0
#
############################################################################

      
class SourceRef   #combines source file name and line number

  def initialize (file_name, line=0)
    @file = file_name
    @line = line
  end

  attr_reader :file, :line
  
  def to_s
    return file unless line > 0
    file+':'+line.to_s
  end
  alias_method :inspect, :to_s
  
  def to_srcRef
    self
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
        raise $!,"--> Truncated ruby source file: #{self}"
      end
    rescue
      raise $!,"--> Missing ruby source: #{self}"
    end
    text
  end
  
  def edit (options=nil, readonly=false)
  # start an editor session on file at line
  # If X-windows display available, try nedit client, then nedit directly
    if ENV["DISPLAY"]
      neditArgs = "-lm Ruby #{options} '#{file}'"
      neditArgs = "-line #{line} " + neditArgs if line > 1
      neditArgs = "-read " + neditArgs if readonly
      # nclient will normally be a symlink to /usr/bin/X11/nc
      return self if 
        system ("nclient -noask -svrname ruby #{neditArgs} 2>/dev/null") || 
        system ("nedit #{neditArgs} &")
    end
  # if all else fails, fall back on the venerable 'vim' or busybox 'vi'
    system ("vi #{"-R " if readonly}'#{file}'") unless 
      system ("vim #{"-R " if readonly}#{"+"+line.to_s+" " if line>1}'#{file}'")
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
      raise $!, "--> Missing ruby source fle: #{file}" 
    end
  end
  

  def SourceRef.find_in_back_trace (trace, symbol)
  # return first element in trace containing symbol
  # returns nil if no such stack level found
    for msg in trace
      if inPart = msg.split(':',4)[2]
        name = inPart.split('in\s*', 2)[1][1...-1]
        return msg if symbol == name.intern
      end
    end
    return nil
  end
   
  def SourceRef.from_back_trace (trace, level=0)
  # return sourceref at level in backtace
  #  or return level if no such level found
    traceLvl=level.kind_of?(Symbol) ?
                SourceRef.find_in_back_trace (trace, level) : trace[level]
    return nil if traceLvl.nil?
    possibleIRBprefix, traceLvl = traceLvl.split(' ', 3)
    traceLvl = possibleIRBprefix unless possibleIRBprefix == "from"
    traceLvl.split(':',3)[0..1].join(':').to_srcRef
  end


  module Code #for objects supporting __file__ & __line__

    def source
      SourceRef.new (__file__, __line__)
    end
    alias_method :to_srcRef, :source
    
    # can't use define_method because in ruby 1.6 self would be SourceRef::Code
    (OPS = [ :list, :edit, :view, :reload ]).each {|m|
      eval "def #{m}; source.#{m}; end"
    }
    
  end #module SourceRef::Code

  
  module CommandBundle   #add convenient commands for viewing source code
    private
    
    Code::OPS.each {|m|
      define_method (m) { |*args|
        src = args.length==0 ? IRB.conf[:exception] : args.shift
        #convert src to an appropriate SourceRef by whatever means possible
        #Modified irb.rb saves last back_trace & exception in IRB.conf
        if src.kind_of?(Module)
          src.sources.each {|srcRef| srcRef.method(m).call (*args)}
        else
          if src.kind_of?(Integer) || src.kind_of?(Symbol) 
            #assume parameter is a backtrace level or method name
            srcFromTrace = IRB.conf[:exception].to_srcRef src
            src = srcFromTrace unless srcFromTrace.nil?
          end
          if src.respond_to? :to_srcRef
            src.to_srcRef.method(m).call (*args)
          else
            print "No source file corresponds to ",src.type,':',src.inspect,"\n"
          end
        end
      }
    }

    def startRBBR  #start another Ruby Class Browser
      require 'rbbr'
      (rbbrThread=Thread.new {RBBR.main}).priority=Thread.current.priority+1
      rbbrThread    
    end
    
  end  

end #class SourceRef


#mix source code manipulation utilites into the appropriate classes
class Proc; include SourceRef::Code; end
class Method; include SourceRef::Code; end
class Object; include SourceRef::CommandBundle; end


class Symbol
  def intern  #just for mathematical completeness!
    self
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

class String
  def to_srcRef
  # parse a source reference from string of form fn:line#
    strip!
    a = split(':')
    return SourceRef.new (self, 0) if a.length < 2
    SourceRef.new (a[0..-2].join(':'), a[-1].to_i)
  end
end

class Exception
  def to_srcRef (level=0)
  # default given any exception the best guess as to its location
    SourceRef.from_back_trace(backtrace, level)
  end
end

class SyntaxError < ScriptError
  # Decode the Source Ref from the compiler error message
  def to_srcRef (level=nil)
    return super.to_srcRef level if level.nil?
    to_s.split("\s",2)[0].to_srcRef
  end
end

  
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
  # note that instance_methods will overwrite singletons of the same name
    singleton_source.update(instance_source(*args))
  end
  
  def % (method_name)
  # return singleton method named method_name in module
  # Use / below unless method_name is also an instance method
    method method_name
  end
    
  def / (method_name)
  # return method named method_name in module
    begin
      return instance_method method_name
    rescue NameError
    end
    method method_name
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
    sources(*args).each{|srcFile| srcFile.edit (*args)}
  end

  def view (*args)
  # start read-only editor sessions on files containing receiver's methods
    sources(*args).each{|srcFile| srcFile.view (*args)}
  end
  
  def list (*args)
  # return first few lines of all files containing self.methods
    result=""
    sources.each{|srcFile| result+=srcFile.list (*args)}
    result
  end

end
