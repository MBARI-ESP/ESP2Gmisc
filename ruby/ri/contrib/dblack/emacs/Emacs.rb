#  Emacs.rb -- output format file for Dave Thomas's
#              ri (Ruby Index) utility

#  $Id$
#  $Author$
#  Version 0.1.0

#  David Alan Black (dblack@candle.superlink.net)
#  $Date$
#  Copyright (c) David Alan Black, 2001

#  This software is distributed on the same terms as Ruby itself.

require 'ri/outputstream'

class Emacs < OutputStream

  def initialize(*args)
    super(*args)
  end
		      
  OFFSET = "   "
   
  def Emacs::desc
    "Output to be fed to ri.el"
  end

  def puts(str)
    super stripFormatting(str)
  end

  def wrap(ind,str,len)
    super(ind,stripFormatting(str),len)
  end

  def error(*msg)
    puts "ri error: " + msg.to_s
  end

  def prepindent(level=1,offset=OFFSET)
    text = yield
    indent = offset * level
    [text,indent]
  end

  def indented(level=1, offset=OFFSET, &block)
    text,indent = prepindent(level, offset, &block)
    wrap(indent,text.to_s,@line_len - indent.size)
  end

  def vindented(level=1, offset=OFFSET, &block)
    text,indent = prepindent(level, offset, &block)
    text.to_a.map {|line| indent + line} .join
  end

  def putHRBlock(text)
    putHrule
    putBlock(text)
  end

  def putBlock(text)
    puts text
    puts ""
  end
    
  def putHrule
    putBlock "_" * @line_len
  end

  def putVerbatim(text)
    putBlock vindented(3) { stripFormatting(text) }
  end

  def putParagraph(text)
    putBlock indented(2) { stripFormatting(text) }
  end

  def putMessage(text)
    puts indented(1) { text }
  end

  def putSectionTitle(text)
    putHRBlock indented(1) { text }
  end

  def putMethodHeader(cname, type, mname, callseq)
    name = cname + type + mname
    putSectionTitle "Method:"
    putBlock indented(2) { name }
    putSectionTitle "Call sequence:"
    putBlock indented(2) { callseq }
  end

  def putClassHeader(type, name, superclass, subclasses)
    putSectionTitle(if type == "module" then "Module:" else "Class:" end)
    res = name
    res << "  < #{superclass}" unless superclass.empty?
    putBlock indented(2) { res }
    if subclasses
      putSectionTitle "Subclassed by:"
      putMethodList(subclasses)
    end
  end

  def putMethodList(names)
    putBlock vindented(2) { columnize(names.sort,1,@line_len) }
  end

  def putClassMethods(names)
    putSectionTitle "Methods:"
    putMethodList(names)
  end

# Wrapper methods 

  def putClassDescription
    yield
  end

  def putMethodDescription
    yield
  end

  def putFragmentBlock
    putSectionTitle "Description:"
    yield
  end

  def putListOfClassesMatchingName(name,&block)
    putMultipleResultMessage("class or module",name,&block)
  end

  def putListOfMethodsMatchingName(name,&block)
    putListOfMethodsMatching(name,&block)
  end

  def putListOfMethodsMatching(name,&block)
    putMultipleResultMessage("method",name,&block)
  end

  def putMultipleResultMessage(type,name,&block)
    message = <<-EOM.split("\n").join(" ")
More than one #{type} matches your term "#{name}".  You
may tab through this list and select the term you want
EOM

    putHRBlock indented(1) { message }
    yield
  end
    
  def columnize(lines,gap,width)
    res = ""
    widest = lines.sort { |a,b| a.size <=> b.size } [-1] .size
    colno = ((width - widest) / (widest + gap)) + 1
    rowno, extra = lines.size.divmod(colno)
    rowno += 1 if extra > 0

    rows = []
    n = 0
    lines.each_with_index do |l,i|
      n += 1 if i % colno == 0 and i > 0
      rows[n] = rows[n].to_a << l
    end

    res = ""
    rows.each do |row|
      row.each_with_index do |item,i|
	item = item.ljust(widest + gap) unless i + 1 == colno
	res << item
      end
      res << "\n"
    end
    res
  end

end
