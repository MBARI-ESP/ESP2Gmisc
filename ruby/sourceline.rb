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

  def initialize (file_name, line)
    @file = file_name
    @line = line
  end

  attr_reader :file, :line
  
  def to_s
    file+':'+line.to_s
  end
  
  def list (lineCount=16, lineOffset=0)
  # return the next lineCount lines of source text
  # or nil if source line is invalid
    f = File.new (file)
    text = ""
    begin
      2.upto(line+lineOffset) { f.readline }
      1.upto(lineCount) { text += f.readline }
    rescue EOFError
    end
    text
  end
  
  def edit (options=nil, readonly=false)
  # start an editor session on @file at @line
  # If X-windows display available, try nedit client, then nedit directly
    if ENV["DISPLAY"]
      neditArgs = "-lm Ruby -line #{@line} #{options} '#{@file}'"
      neditArgs = "-read " + neditArgs if readonly
      return self if system ("nclient -noask -svrname ruby #{neditArgs}") || 
                     system ("nedit #{neditArgs}")
    end
  # if all else fails, fall back on the venerable 'vi'
    system ("vi #{"-R " if readonly} + #{@file}")
    self
  end
  
  def view (options=nil)
  # start a read-only editor session on @file at @line
    edit (options, true)
  end
  
end #class SourceRef


class Object  #is the nearest common ancestor of Proc and Method :-(

  def source
    SourceLine.new (source_file_name, source_line)
  end
  
  def list (lineCount=16, lineOffset=0)
  # return the first lineCount lines of receiver's source text
  # or nil if no source available  
    source.list
  end
  
  def edit
  # start an editor session on the receiver's source
  end
  
  def view
  # start a read-only editor session on the receiver's source
  end

end
  
  
class Module

  def source  
  # return hash of SourceRefs of all self.methods
  end
    
  def sources  
  # return array of unique source file names for all self.methods
  end
    
  def edit
  # start editor sessions on all files containing self.methods
  end

  def view
  # start read-only editor sessions on all files containing self.methods
  end
  
end       
