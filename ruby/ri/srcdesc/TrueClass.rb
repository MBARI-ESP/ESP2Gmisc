# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("TrueClass", "Object", "class")
aClass.addFragment(Paragraph.new("The global value <code>true</code> is the only instance of class <code>TrueClass</code> and represents a logically true value in boolean expressions. The class provides operators allowing <code>true</code> to be used in logical expressions.\n"))
m0002 = MethodDesc.new("&", "TrueClass", "instance", "<code>true</code> & <i>anObject</i> -> <i>anObject</i>")
m0002.addFragment(Paragraph.new("And---Returns <code>false</code> if <i>anObject</i> is <code>nil</code> or <code>false</code>, <code>true</code> otherwise.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("^", "TrueClass", "instance", "<code>true</code> ^ <i>anObject</i> -> !<i>anObject</i>")
m0003.addFragment(Paragraph.new("Exclusive Or---Returns <code>true</code> if <i>anObject</i> is <code>nil</code> or <code>false</code>, <code>false</code> otherwise.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("|", "TrueClass", "instance", "<code>true</code> | <i>anObject</i> -> <code>true</code>")
m0004.addFragment(Paragraph.new("Or---Returns <code>true</code>. As <i>anObject</i> is an argument to a method call, it is always evaluated; there is no short-circuit evaluation in this case.\n"))
m0004.addFragment(Verbatim.new("true |  puts(\"or\")\ntrue || puts(\"logical or\")"))
m0004.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0004.addFragment(Verbatim.new("or"))
aClass.addMethod(m0004)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
