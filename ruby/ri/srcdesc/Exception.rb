# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Exception", "Object", "class")
aClass.addFragment(Paragraph.new("Descendents of class <code>Exception</code> are used to communicate between <code>raise</code> methods and <code>rescue</code> statements in <code>begin/end</code> blocks. <code>Exception</code> objects carry information about the exception---its type (the exception's class name), an optional descriptive string, and optional traceback information.\n"))
m0002 = MethodDesc.new("exception", "Exception", "class", "Exception.exception( <i>[</i><i>aString</i><i>]</i> ) -> <i>anException</i>")
m0002.addFragment(Paragraph.new("Creates and returns a new exception object, optionally setting the message to <i>aString</i>.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("backtrace", "Exception", "instance", "<i>exc</i>.backtrace -> <i>anArray</i>")
m0003.addFragment(Paragraph.new("Returns any backtrace associated with the exception. The backtrace is an array of strings, each containing either ``filename:lineNo: in `method''' or ``filename:lineNo.''\n"))
m0003.addFragment(Verbatim.new("def a\n  raise \"boom\"\nend\n\n\ndef b\n  a()\nend\n\n\nbegin\n  b()\nrescue => detail\n  print detail.backtrace.join(\"\\n\")\nend"))
m0003.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0003.addFragment(Verbatim.new("prog.rb:2:in `a'\nprog.rb:6:in `b'\nprog.rb:10"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("exception", "Exception", "instance", "<i>exc</i>.exception( <i>[</i><i>aString</i><i>]</i> ) -> <i>anException</i> or <i>exc</i>")
m0004.addFragment(Paragraph.new("With no argument, returns the receiver. Otherwise, creates a new exception object of the same class as the receiver, but with a different message.\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("message", "Exception", "instance", "<i>exc</i>.message -> <i>aString</i>")
m0005.addFragment(Paragraph.new("Returns the message associated with this exception.\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("set_backtrace", "Exception", "instance", "<i>exc</i>.set_backtrace( <i>anArray</i> ) -> <i>anArray</i>")
m0006.addFragment(Paragraph.new("Sets the backtrace information associated with <i>exc</i>. The argument must be an array of <code>String</code> objects in the format described in <code>Exception\#backtrace</code>.\n"))
aClass.addMethod(m0006)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
