# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Method", "Object", "class")
aClass.addFragment(Paragraph.new("Method objects are created by <code>Object\#method</code>, and are associated with a particular object (not just with a class). They may be used to invoke the method within the object, and as a block associated with an iterator.\n"))
aClass.addFragment(Verbatim.new("class Thing\n  def square(n)\n    n*n\n  end\nend\naThing  = Thing.new\naMethod = aThing.method(\"square\")\n\naMethod.call(9)                 \#=> 81\n[ 1, 2, 3 ].collect(&aMethod)   \#=> [1, 4, 9]\n"))
m0002 = MethodDesc.new("[]", "Method", "instance", "<i>meth</i>[ <i>[</i><i>args</i><i>]*</i> ] -> <i>anObject</i>")
m0002.addFragment(Paragraph.new("Synonym for <code>Method.call</code>.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("arity", "Method", "instance", "<i>meth</i>.arity -> <i>aFixnum</i>")
m0003.addFragment(Paragraph.new("Returns an indication of the number of arguments accepted by a method. Returns a nonnegative integer for methods that take a fixed number of arguments. For Ruby methods that take a variable number of arguments, returns -n-1, where n is the number of required arguments. For methods written in C, returns -1 if the call takes a variable number of arguments.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("call", "Method", "instance", "<i>meth</i>.call( <i>[</i><i>args</i><i>]*</i> ) -> <i>anObject</i>")
m0004.addFragment(Paragraph.new("Invokes the <i>meth</i> with the specified arguments, returning the method's return value.\n"))
m0004.addFragment(Verbatim.new("m = 12.method(\"+\")\nm.call(3)    \#=> 15\nm.call(20)   \#=> 32\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("to_proc", "Method", "instance", "<i>meth</i>.to_proc -> <i>aProc</i>")
m0005.addFragment(Paragraph.new("Returns a <code>Proc</code> object corresponding to this method.\n"))
aClass.addMethod(m0005)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
