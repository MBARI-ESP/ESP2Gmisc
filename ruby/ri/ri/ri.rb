RI_VERSION = "0.8a"


###########################################################################
USAGE = <<_EOU_

usage:
      #{File.basename($0)} [opts] name ...

 opts:
      --version,     -v       display version and exit
      --line-length, -l nn    set the line length for the output 
                              (minimum 30 chars)
      --synopsis,    -s       display just a synopsis
      --format,      -f name  use the 'name' module (default 'Plain')
                              for output formatting. Available modules:
!MODULELIST!

 name:
      Class | Class::method | Class#method | Class.method | method


'ri' displays documentation for the named classes or methods. All names 
can be abbreviated to their minimum non-ambiguous size.
_EOU_
############################################################################


require 'ri/refdoc.rb'
require 'rbconfig'

include Config

$sitedir = CONFIG["sitedir"]
$datadir = File.join($sitedir, "ri")
$opdir   = File.join($datadir, "op")

##
# Return a formatted list of the descriptions of 
# each of the available output formatters

def moduleList()
  res = ""
  leader = "                                  "
  begin
    Dir.foreach($opdir) do |name|
      next unless name =~ /(.*)\.rb$/
      require File.join("ri/op", $1)
      klass = eval $1
      modDesc = klass::desc
      res << leader << $1 << ":  " << modDesc << "\n"
    end
  rescue
    puts $!
    res = leader + "no modules found..."
  end
  res
end

##
# Manage the list of known classes, based on the names of files
# available in the datadir
#

module ClassIndex
  ##
  # Preload the list of classes

  Dir.open($datadir) do |dir|
      @@classes = dir.grep(/^[A-Z]/)
  end

  ##
  # Return an array of class names
  
  def ClassIndex.classes
    @@classes
  end

  ##
  # Return an array of those classes whose names start
  # with a given string

  def ClassIndex.findClasses(pattern)
    name = Regexp.escape(pattern)
    @@classes.grep(/^#{name}/)
  end

  ##
  # Return true iff the given name is a known class
  
  def ClassIndex.classExists?(name)
    @@classes.include?(name)
  end
end

##
# Manage the index which maps method names to classes that
# implement that method
#

class MethodIndex
  @@index = nil
  @@names = nil

  def MethodIndex.loadIndex
    begin
      File.open(File.join($datadir, "index")) do |f|
        @@index = Marshal.load(f)
        @@names = @@index.names
      end
    rescue
      @@index = {}
    end
  end

  # If the given name exactly matches a known method, return an
  # array of classes implementing that method, otherwise
  # use the name as a glob and search for matches
  def MethodIndex.findMethods(name)
    MethodIndex.loadIndex unless @@index
    return [] unless name && name.length > 0
    res = @@index[name]
    if !res
      name = Regexp.escape(name)
      nameList = @@names.grep(/^#{name}/)
      res = []
      nameList.each {|n| res.concat @@index[n]}
      res.sort
    end
    res
  end
end


class RI

  # Match a class or module name. We accept Name, Name::, or Name::Name

  CN_PATTERN = '[A-Z]\w*(?:::(?:[A-Z]\w*)?)?'
      

  attr_accessor :synopsis

  def initialize
    @synopsis = false
    @desc_files = {}
  end

  def version
    RI_VERSION
  end

  def setOutputFormatter(op)
    @op = op
  end

  ##
  # Return given a possibly abbreviated class name, return
  # either the matching exact name or an array of
  # matching names

  def findClassesThatMatch(name)
    fname = name.tr(':', '_')
    return ClassIndex.findClasses(fname)
  end

  ##
  # Find an exact class match

  def findExactClassMatch(name)
    fname = name.tr(':', '_')
    return ClassIndex.classExists?(fname)
  end

  ##
  # Read in a serialized class description
  #
  def findClass(name)

    cl = findClassesThatMatch(name)

    # now a slight problem. If the user said 'File', we'll
    # have matched 'File' and 'File__Stat', but really
    # just 'File' was wanted, so...

    cl = [ name ] if cl.size > 1 && cl.include?(name)

    case cl.size
    when 0
      @op.error("Couldn't find class/module `#{name}'.\n" +
                "Use #$0 with no parameter for a list")
      throw :exit, 1

    when 1
      file_name = File.join($datadir, cl[0])
      res = @desc_files[file_name]
      if not res
        File.open(file_name) do |f|
          res = @desc_files[file_name] =  Marshal.load(f)
        end
      end
      return res
    else
      return cl
    end  
  end
  
  ##
  # Print a list of fragments in a nice pretty way
  #
  
  def printFragments(source)

    @op.putFragmentBlock do 
      source.eachFragment do |f|
        
        case f
        when Verbatim
          @op.putVerbatim(f.to_s)
          
        when Paragraph
          @op.putParagraph(f.to_s)
        end
      end
    end
  end
  
  
  ##
  # Print a simple list of classes and exit
  #
  def usage

    unless @synopsis
      @op.error(USAGE.sub(/!MODULELIST!/, moduleList()))
      
      @op.error("\n'ri' has documentation for the classes and modules:\n\n")
    end

    names = ClassIndex.classes.map {|n| n.tr('_', ':') }
    if names.size.zero?
      @op.error("Configuration error: could not find class list")
    else
      @op.putMethodList(names)
    end
  end
  
  ##
  # The user asked for X.y, and the 'X' part matches more than
  # one class. For each, find all potential matching methods
  # and report on each
  
  def matchMethodsInClasses(classList, type, mname)
    res = []
    
    for cname in classList
      cl = findClass(cname)
      res.concat cl.findMethods(mname, type == "::")
#      meths.each {|m| res << "#{cname}#{m.type=='class'?'::':'#'}#{m.name}" }
    end

    return res

    @op.putListOfMethodsMatchingName(mname) do
      @op.putMethodList(res)
    end
  end
  
  
  ##
  # return a list of Method objects that match the given class, type. and method
  # name

  def methods_matching(cname, type, mname)
    cl = findClass(cname)

    case cl
    when Array
      matchMethodsInClasses(cl, type, mname)
      
    when ClassModule
      cl.findMethods(mname, type == "::")
    end

  end

  ##
  #
  # Describe a method in a known class
  #
  
  def describeMethod(cname, type, mname)
    
    # If the class name part is ambiguous, then we have a join to
    # do
    
    method_list = methods_matching(cname, type, mname)

    case method_list.size
        
    when 0
      @op.error("Cannot find method `#{cname}#{type}#{mname}'")
      throw :exit, 3
        
    when 1
      meth = method_list[0]
      @op.putMethodDescription do
        @op.putMethodHeader(meth.class_name, meth.typeAsSeparator, meth.name, meth.callseq)
        printFragments(meth) unless @synopsis
      end
      
    else

      @op.putListOfMethodsMatchingName(mname) do
        @op.putMethodList(method_list.collect { |m| 
                            "#{m.class_name}#{m.typeAsSeparator}#{m.name}" 
                          })
      end
    end
  end
  
  ##
  # Produce a class description
  #
  
  def describeClass(name)
    cl = findClass(name)
    
    case cl
      
    when Array
      @op.putListOfClassesMatchingName(name) do
        @op.putMethodList(cl)
      end

    when ClassModule
      @op.putClassDescription do 
        @op.putClassHeader(cl.type, cl.name, cl.super, cl.subclasses) unless @synopsis
        printFragments(cl) unless @synopsis
        @op.putClassMethods(cl.methods.collect{|m| m.name})
      end
    end
  end
  
  ##
  # Find a method given its name, and then describe it
  #
  
  def findAndDescribe(name)
    methods = MethodIndex.findMethods(name)
    
    if methods.size.zero?
      @op.error("Don't know anything about a method called `#{name}'.")
      throw :exit, 4
    end
    
    if methods.size == 1
      methods[0] =~ /^(#{CN_PATTERN})(\.|\#|::)(.+)/
      describeMethod($1, $2, $3)
    else
      @op.putListOfMethodsMatchingName(name) do
        @op.putMethodList(methods)
      end
    end
  end


  # With no parameters, list known classes and modules. If the 
  # parameter is a (partial) class name, either describe it
  # or list the classes that match. 
  # If the parameter is a method name qualified by a class name,
  # look it up. Otherwise we have to try to be clever and see if
  # we have a unique method name for some class


  def handle(args)

    usage if args.size.zero?

    catch (:exit) do
      args.each do |name|
        
        case name
          
        when /^#{CN_PATTERN}$/o
          describeClass(name)
          
        when /^(#{CN_PATTERN})(\.|\#|::)(.+)/o
          describeMethod($1, $2, $3)
          
        else
          findAndDescribe(name)
        end
      end
      0                  # normal exit
    end
  end

  # Is a class, module, or method defined. Return the type of
  # thing, or nil if not known

  def defined?(name)
    catch (:exit) do

      case name
      when /^#{CN_PATTERN}$/o
        return "ClassModule" if findExactClassMatch(name)
        
      when /^(#{CN_PATTERN})(\.|\#|::)(.+)/o   #/
        cname, type, mname = $1, $2, $3

        return nil unless findExactClassMatch(cname)
 
        cl = findClass(cname)

        if ClassModule === cl
          return "Method" if cl.findExactMethod(mname, type == "::")
        end
      end
    end
    
    nil
  end

  # Return 'true' if the 'handle' method would have successfully
  # produced a description

  def can_handle?(name)
    case name
      
    when /^#{CN_PATTERN}$/o
      return findClassesThatMatch(name).size > 0
      
    when /^(#{CN_PATTERN})(\.|\#|::)(.+)/o
      cname, type, mname = $1, $2, $3
      return findClassesThatMatch(cname).size > 0 && 
             methods_matching(cname, type, mname).size > 0
      
    else
      return MethodIndex.findMethods(name).size > 0
    end
  end

end


###################################################################

# Local Variables:
# mode: ruby
# End:
