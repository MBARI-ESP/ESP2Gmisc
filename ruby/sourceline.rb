#############  sourceline.rb   2/11/03  brent@mbari.org  ###################
#
#  The SourceLine class relies on a patched version of ruby/eval.c
#  to provide access to the source file and line # where every Method
#  or Proc is defined.  SourceLine is a container for these and implements
#  methods to:
#
#    list source code to stdout,
#    view source code in an editor,
#    edit source code
#
#  This file also adds methods to Object and Module to list, view, and
#  edit methods directly as a convenience.
#
#  Examples:
#     SourceLine.instance_method (:list).source  ==> ./sourceline.rb:47
#     SourceLine.instance_method (:list).edit    ==>  opens an editor window
#     Date.edit    ==> edits all files that define methods in class Date
#     Date.source  ==> returns hash of Date methods to SourceLines
#     Date.sources ==> returns the list of files containing Date methods
#
############################################################################


class SourceLine   #combines source_file_name and line number

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
  
end #class SourceRef


class Object  #is the nearest common ancestor of Proc and Method :-(

  def source
    SourceLine.new (source_file_name, source_line)
  end
  
  def list (lineCount=16, lineOffset=0)
  # return the first lineCount lines of receiver's source text
    source.list (lineCount, lineOffset)
  end
  
  def edit
  # start an editor session on the receiver's source
    source.edit
  end
  
  def view
  # start a read-only editor session on the receiver's source
    source.view
  end

  def reload
  # load entire file containing receiver's source text
    source.reload
  end
  
end
  
  
class Module

  def source  
  # return hash on receiver's methods to corresponding SourceLines
  # exclude methods for which no ruby source is available
    h = {};
    singleton_methods.each {|m|
      m = m.intern
      src = method(m).source
      h[m] = src if src.line > 0 && src.file != "(eval)"
    }
    instance_methods.each {|m|
      m = m.intern
      src = instance_method(m).source
      h[m] = src if src.line > 0 && src.file != "(eval)"
    }
    h
  end
    
  def sources
  # return array of unique source file names for all receiver's methods
    (source.values.collect{|s| s.file}.uniq).collect{|fn| SourceLine.new(fn)}    
  end
    
  def reload
  # load all source files that define receiver's methods
    sources.each {|s| s.reload}
  end
  
  def edit
  # start editor sessions on all files that define receiver's methods
    sources.each{|srcFile| srcFile.edit}
  end

  def view
  # start read-only editor sessions on files containing receiver's methods
    sources.each{|srcFile| srcFile.view}
  end
  
  def list (lineCount=16, lineOffset=0)
  # return first few lines of all files containing self.methods
    result=""
    sources.each{|srcFile| result+=srcFile.list (lineCount, lineOffset)}
    result
  end

end       
