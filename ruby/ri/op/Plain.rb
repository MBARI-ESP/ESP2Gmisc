#
# This is the output class for 'plain' output: normally sent to a
# terminal
#

require 'ri/outputstream'

class Plain < OutputStream

  def Plain::desc
    "Default plain output"
  end

  STD_INDENT  = "     "
  VERB_INDENT = "        "

  def error(*msg)
    puts(*msg)
  end

  def putMethodList(names)
    puts wrap(STD_INDENT, names.sort.join(", "))
  end

  def putVerbatim(txt)
    puts VERB_INDENT + txt.split("\n").join("\n" + VERB_INDENT)
  end

  def putParagraph(txt)
    puts wrap(STD_INDENT, stripFormatting(txt))
  end

  def putMessage(txt)
    puts wrap("", stripFormatting(txt))
  end

  def newline
    puts "\n"
  end
  
  def putMethodHeader(cname, type, mname, callseq)
    wrapInLines(cname, type, mname) do 
      puts wrap(STD_INDENT, stripFormatting(callseq))
    end
    puts
  end

  def putClassHeader(type, name, superClass, subclasses)
    wrapInLines do 
      if type == "module"
        puts  STD_INDENT + "module: #{name}"
      else
        res =  STD_INDENT + "class: #{name}"
        if superClass and superClass != "Object"
          res << "  < #{superClass}"
        end
        puts res
      end
      puts
    end
    puts wrap(STD_INDENT, "Subclassed by: #{subclasses.join(', ')}\n\n") if subclasses
  end

  def putClassMethods(names)
    wrapInLines do
      putMethodList(names)
    end
  end

  # These are methods that wrap other calls

  def putFragmentBlock
    yield
    newline
  end

  def putMethodDescription
    yield
  end

  def putClassDescription
    yield
  end

  def putListOfClassesMatchingName(name)
    putMessage("These classes and modules match `#{name}':")
    yield
  end

  def putListOfMethodsMatchingName(name)
    putMessage("The method named `#{name}' is not unique among Ruby's classes and modules:")
    yield
  end


  private

  def wrapInLines(*args)
    if args.size > 0
      suffix = " " + args.join('')
      puts "-" * (@line_len - suffix.length) + suffix
    else
      puts "-" * @line_len
    end

    yield
    puts "-" * @line_len
  end

end
