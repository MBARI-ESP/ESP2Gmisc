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
#     list|edit|view|reload Module|Method|Integer|Symbol|Exception|String|Thread
#
#   Module operates on the list of files that comprise the Module
#   Method operates on the text of the Method
#   Integer n operates on the most recent backtrace at level n
#   Symbol :sym searches backtrace for level corresponding to :sym
#   Exception operates on the source where the exception occured
#   String fn:nnn operates on file "fn" at line nnn
#   no argument is equivalent to backtrace level 0
#   Thread operates on that thread's most recent exception
#
############################################################################

      
class String
  def to_srcRef
  # parse a source reference from string of form fn:line#
    strip!
    a = split(':')
    return SourceRef.new (self, 0) if a.length < 2
    sym=nil
    if a.length > 2 and a[-1][0,3] == 'in '
      s=a.pop
      s=s[4,s.length-5]
      s="" unless s
      sym=s.intern
    end
    SourceRef.new (a[0..-2].join(':'), a[-1].to_i, sym)
  end
end

class Exception
  def to_srcRef (level=0)
  # default given any exception the best guess as to its location
    SourceRef.from_back_trace(backtrace, level)
  end
  def rootCause
  # define as a NOP so subclasses can override
    self
  end
end

class SyntaxError < ScriptError
  # Decode the Source Ref from a compiler error message
  def to_srcRef (level=nil)
    return super level if level
    to_s.split("\s",2)[0].to_srcRef
  end
end


class SourceRef   #combines source file name and line number

  def initialize (file_name, line=0, symbol=nil)
    @file = file_name
    @line = line
    @symbol = symbol
  end
  attr_reader :file, :line, :symbol
  
  def to_s
    return file unless line > 0
    return file+':'+line.to_s unless symbol
    file+':'+line.to_s+':in `'+symbol.to_s+"'"
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
      
  
  class <<@@remoteStub = Object.new
    def system localCmd
      Kernel.system (localCmd)
    end
    def remap localPath
      localPath
    end
  end
  @@remote = @@remoteStub unless defined? @@remote
    
  def self.remote= remoteObject
# configure SourceRef for remote editting
# remoteObject must implement remap to convert pathnames and
# must implement the method :system(string) similar to Kernel::system
    @@remote = remoteObject || @@remoteStub
  end
    
  def self.remote 
    @@remote
  end

  def sys os_cmd
    @@remote.system os_cmd
  end  
  private :sys
    
  def edit (options=nil, readonly=false)
  # start an editor session on file at line
  # If X-windows display available, try nedit client, then nedit directly
    if disp=ENV["DISPLAY"]
      path = @@remote.remap(File.expand_path (file))
      if disp.length>1
        neditArgs = ""
        neditArgs<< "-read " if readonly
        neditArgs<< "-line #{line} " if line > 1
        neditArgs<< "-lm Ruby #{options} \"#{path}\""
        return self if sys (
   "PATH=~/bin:$PATH nohup redit #{neditArgs} >/dev/null || nedit #{neditArgs}")
      end
      return self if
        sys ("TERM=#{ENV["TERM"]} nano -m #{"-v " if readonly}#{
          "+#{line} " if line>1}\"#{path}\"")
    end
  # if all else fails, fall back on the venerable local 'vi'
    system ("vi #{"-R " if readonly}#{"-c"+line.to_s+" " if line>1}\"#{file}\"")
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
  

  def self.find_in_back_trace (trace, symbol)
  # return first element in trace containing symbol
  # returns nil if no such stack level found
    for msg in trace
      src = msg.to_srcRef
      return src if src.symbol == symbol
    end
    return nil
  end
   
  def self.from_back_trace (trace, level=0)
  # return sourceref at level in backtace
  #  or return level if no such level found
    return find_in_back_trace (trace, level) if level.kind_of? Symbol    
    return unless lvl = trace[level]
    lvl.to_srcRef
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

  
  def self.doMethod (m, *args)
    src = args.length==0 ? IRB.CurrentContext.thread.lastErr : args.shift
    #convert src to an appropriate SourceRef by whatever means possible
    #Modified irb.rb saves last back_trace & exception in IRB.conf
    case src
      when Module
        srcs=(src.sources).each {|srcRef| srcRef.send m, *args}
        return srcs
      when Integer, Symbol
        #assume parameter is a backtrace level or method name
        srcFromTrace = IRB.CurrentContext.thread.lastErr.to_srcRef src
        src = srcFromTrace if srcFromTrace
      when Thread
        src = src.exception.last.rootCause
    end
    if src.respond_to? :to_srcRef
      src.to_srcRef.send m, *args
    else
      print "No source file corresponds to ",src.type,':',src.inspect,"\n"
    end
  end


  module CommandBundle   #add convenient commands for viewing source code
    private
    
    Code::OPS.each{|m|define_method(m){|*args|SourceRef.doMethod(m,*args)}}

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
