##
# This is a list of classes that hold the descriptions of methods, classes
# and modules. We are built from the book's XML, and then serialized out
# to allow rapid access at runtime. In fact, we actually serialize
# twice, once in source code form, and once in binary. The source
# code form allows us to ship this information to machines with differing
# versions of Ruby without generating lots of Marshaling errors.
#

COLUMN_SEP = 200.chr

##
# We're a hash indexed by method name. Each entry points to an array
# of Strings containing the fully qualifed method names (String#split)
# for each class in which that method occurs

class MethodIndex
  def initialize(from = Hash.new)
    @index = from
  end
  
  # Given a class, update the index. Don't duplicate this
  # class's entries if they're already in there
  def updateWith(cl)
    cl.eachMethod do |m|
      mname = m.name
      fname = fqn(cl, m)
      if @index[mname].nil?
        @index[mname] = [fname]
      else
        @index[mname] << fname unless @index[mname].include?(fname)
      end
    end
  end

  def [](name)
    @index[name]
  end

  def names
    @index.keys
  end

  def to_src(name)
    "#{name} = MethodIndex.new(#{@index.inspect})"
  end
end

##
# A Fragment is a chunk of text, subclassed as a paragraph or verbatim
# text

class Fragment
  def initialize(txt)
    @txt = txt
  end

  def to_src
    %{#{self.class.name}.new(#{@txt.dump})}
  end

  def to_s
    @txt
  end
end

##
# A paragraph is a fragment which gets wrapped to fit 
#
class Paragraph < Fragment
  def initialize(txt)
    @txt = txt.tr_s("\n ", "  ").strip + "\n"
  end
end

##
# A listentry is a fragment containing a label and a paragraph
# The paragraph is indented by a given amount

class ListEntry < Paragraph
  attr_reader :indent, :label

  def initialize(label, indent, txt)
    super(txt)
    @label = label
    @indent = indent
  end
  def to_src
    %{#{self.class.name}.new(#{@label.dump}, #{@indent}, #{@txt.dump})}
  end
end

##
# Verbatim code contains lines that don't get wrapped.
# This is complicated because we have to handle code tables
class Verbatim < Fragment
  def initialize(txt)
    res = txt.strip

    if res[COLUMN_SEP]
      lines = res.split("\n")
      # split each line into two pieces if it contains a separator
      parts = []
      lines.each { |line| parts << line.split(COLUMN_SEP)}
      
      # find the longest first column
      max = 0
      parts.each do |part|
        max = part[0].size if part.size > 1 and part[0].size > max
      end

      # and rebuild the output
      res = ""
      parts.each do |part|
        if part.size < 2
          res << (part[0] || "")
        else
          res << part[0].ljust(max) << "   #=> " << part[1]
        end
        res << "\n"
      end
    end
    @txt = res
  end
end

##
# A description of a method. name, type (instance, class, private), call sequence
# and description
#
class MethodDesc
  attr_reader :name, :class_name, :type, :callseq
  
  def initialize(name, class_name, type, callseq)
    @name, @class_name, @type, @callseq = name, class_name, type, callseq
    @fragments = []
  end

  def addFragment(txt)
    @fragments << txt
  end

  def eachFragment(&blk)
    @fragments.each(&blk)
  end

  def typeAsSeparator
    @type == 'class' ? '::' : '#'
  end

  def <=>(other)
    name <=> other.name
  end

  def to_src(name)
    res = "#{name} = MethodDesc.new(#{@name.dump}, #{@class_name.dump}, " +
      "#{@type.dump}, #{@callseq.dump})\n"
    eachFragment do |f| 
      res << "#{name}.addFragment(#{f.to_src})\n"
    end
    res
    end
end

class ClassModule
  attr_reader :name, :super, :type, :methods, :subclasses

  def initialize(myName, mySuper, myType)
    @name, @super, @type = myName, mySuper, myType
    @subclasses = nil
    @fragments = []
    @methods = []
  end

  def addSubclasses(list)
    @subclasses = list
  end

  def addFragment(txt)
    @fragments << txt
  end

  def eachFragment(&blk)
    @fragments.each(&blk)
  end

  def addMethod(m)
    @methods << m
  end

  def findMethods(meth, classMethod)
    res = []
    match = Regexp.new("^" + Regexp.quote(meth))
    @methods.each do |m|
      if m.name == meth
        return [m] if classMethod and m.type == "class"
        return [m] if !classMethod and m.type != "class"
      end

      if m.name =~ match
        res << m if classMethod and m.type == "class"
        res << m if !classMethod and m.type != "class"
      end
    end

    # If they said Array.new, look for the class method
    if res.size.zero? && !classMethod
      res = findMethods(meth, true)
    end

    res
  end

  def findExactMethod(meth, classMethod)
    @methods.each do |m|
      if m.name == meth
        return m if classMethod and m.type == "class"
        return m if !classMethod and m.type != "class"
      end
    end
    nil
  end

  def eachMethod
    @methods.each {|m| yield m }
  end

  def to_src(name)
    count = "m0001"

    res = "\n# -----------------------------------------\n"
    res << "#{name} = ClassModule.new(#{@name.dump}, #{@super.dump}, #{@type.dump})\n"

    if (@subclasses) 
      res << "#{name}.addSubclasses(%w{#{@subclasses.join(' ')}})\n"
    end

    eachFragment do |f| 
      res << "#{name}.addFragment(#{f.to_src})\n"
    end

    eachMethod do |m|
      count = count.succ
      res << m.to_src(count)
      res << "#{name}.addMethod(#{count})\n"
    end

    res + "\n"
  end
end
