# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Binding", "Object", "class")
aClass.addFragment(Paragraph.new("Objects of class <code>Binding</code> encapsulate the execution context at some particular place in the code and retain this context for future use. The variables, methods, value of <code>self</code>, and possibly an iterator block that can be accessed in this context are all retained. Binding objects can be created using <code>Kernel\#binding</code>, and are made available to the callback of <code>Kernel\#set_trace_func</code>.\n"))
aClass.addFragment(Paragraph.new("These binding objects can be passed as the second argument of the <code>Kernel\#eval</code> method, establishing an environment for the evaluation.\n"))
aClass.addFragment(Verbatim.new("class Demo\n  def initialize(n)\n    @secret = n\n  end\n  def getBinding\n    return binding()\n  end\nend\n\nk1 = Demo.new(99)\nb1 = k1.getBinding\nk2 = Demo.new(-3)\nb2 = k2.getBinding\n\neval(\"@secret\", b1)   \#=> 99\neval(\"@secret\", b2)   \#=> -3\neval(\"@secret\")       \#=> nil\n"))
aClass.addFragment(Paragraph.new("Binding objects have no class-specific methods.\n"))

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
