# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Symbol", "Object", "class")
aClass.addFragment(Paragraph.new("A <code>Symbol</code> object represents a Ruby name and is generated automatically using the <code>:name</code> literal syntax. The same <code>Symbol</code> object will be created for a given name string for the duration of a program's execution, regardless of the context or meaning of that name. Thus if <code>Fred</code> is a constant in one context, a method in another, and a class in a third, the <code>Symbol</code> <code>:Fred</code> will be the same object in all three contexts.\n"))
aClass.addFragment(Verbatim.new("module One\n  class Fred\n  end\n  $f1 = :Fred\nend\nmodule Two\n  Fred = 1\n  $f2 = :Fred\nend\ndef Fred()\nend\n$f3 = :Fred\n$f1.id   \#=> 2299150\n$f2.id   \#=> 2299150\n$f3.id   \#=> 2299150\n"))
m0002 = MethodDesc.new("id2name", "Symbol", "instance", "<i>sym</i>.id2name -> <i>aString</i>")
m0002.addFragment(Paragraph.new("Returns the name corresponding to <i>sym</i>.\n"))
m0002.addFragment(Verbatim.new(":fred.id2name   \#=> \"fred\"\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("inspect", "Symbol", "instance", "<i>sym</i>.inspect -> <i>aString</i>")
m0003.addFragment(Paragraph.new("Returns the representation of <i>sym</i> as a symbol literal.\n"))
m0003.addFragment(Verbatim.new(":fred.inspect   \#=> \":fred\"\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("to_i", "Symbol", "instance", "<i>sym</i>.to_i -> <i>aFixnum</i>")
m0004.addFragment(Paragraph.new("Returns an integer that is unique for each symbol within a particular execution of a program.\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("to_s", "Symbol", "instance", "<i>sym</i>.to_s -> <i>aString</i>")
m0005.addFragment(Paragraph.new("Synonym for <code>Symbol\#id2name</code>.\n"))
aClass.addMethod(m0005)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
