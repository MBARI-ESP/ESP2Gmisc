# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("FalseClass", "Object", "class")
aClass.addFragment(Paragraph.new("The global value <code>false</code> is the only instance of class <code>FalseClass</code> and represents a logically false value in boolean expressions. The class provides operators allowing <code>false</code> to participate correctly in logical expressions.\n"))
m0002 = MethodDesc.new("&", "FalseClass", "instance", "<code>false</code> & <i>anObject</i> -> <code>false</code>")
m0002.addFragment(Paragraph.new("And---Returns <code>false</code>. <i>anObject</i> is always evaluated as it is the argument to a method call---there is no short-circuit evaluation in this case.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("^", "FalseClass", "instance", "<code>false</code> ^ <i>anObject</i> -> <code>true</code> or <code>false</code>")
m0003.addFragment(Paragraph.new("Exclusive Or---If <i>anObject</i> is <code>nil</code> or <code>false</code>, returns <code>false</code>; otherwise, returns <code>true</code>.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("|", "FalseClass", "instance", "<code>false</code> | <i>anObject</i> -> <code>true</code> or <code>false</code>")
m0004.addFragment(Paragraph.new("Or---Returns <code>false</code> if <i>anObject</i> is <code>nil</code> or <code>false</code>; <code>true</code> otherwise.\n"))
aClass.addMethod(m0004)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
