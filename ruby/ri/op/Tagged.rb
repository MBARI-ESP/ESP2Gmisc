#
# This is the output class for tagged output: often interpreted
# by programs
#

require 'ri/outputstream'

class Tagged < OutputStream
  
  def Tagged::desc
    "Simple tagged output"
  end

  def tag(code)
    puts "<#{code}>"
    puts yield
    puts "</#{code}>"
  end
 
  def puts_tag(code)
    puts "<#{code}>"
    yield
    puts "</#{code}>"
  end
 
  def error(*msg)
    tag("error") { msg.join("\n") }
  end

  def putMethodList(names)
    tag("methods") { names.sort.join(",") }
  end

  def putVerbatim(txt)
    tag("verbatim") { txt }
  end

  def putParagraph(txt)
    tag("paragraph") { stripFormatting(txt) }
  end

  def putMessage(txt)
    tag("message") { stripFormatting(txt) }
  end

  def newline
  end

  def putMethodHeader(cname, type, mname, callseq)
    tag("method") do
      "#{cname}|#{type}|#{mname}"
    end
    tag("callseq") { stripFormatting(callseq) }
  end

  def putClassHeader(type, name, superClass, subclasses)
    tag("class") do
      sub = ""
      sub = subclasses.join(',') if subclasses
      "#{type}|#{name}|#{superClass}|#{sub}|"
    end
  end

  def putClassMethods(names)
    putMethodList(names)
  end

  # These are methods that wrap other calls

  def putFragmentBlock
    puts_tag("fragments") { yield }
  end

  def putMethodDescription
    puts_tag("method_description") { yield }
  end

  def putClassDescription
    puts_tag("class_description") { yield }
  end

  def putListOfClassesMatchingName(name)
    puts_tag("classes_matching_name") { yield }
  end

  def putListOfMethodsMatchingName(name)
    puts_tag("methods_matching_name") { yield }
  end


end
