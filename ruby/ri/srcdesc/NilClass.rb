# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("NilClass", "Object", "class")
aClass.addFragment(Paragraph.new("The class of the singleton object <code>nil</code>.\n"))
m0002 = MethodDesc.new("&", "NilClass", "instance", "<code>nil</code>& <i>anObject</i> -> <code>false</code>")
m0002.addFragment(Paragraph.new("And---Returns <code>false</code>. As <i>anObject</i> is an argument to a method call, it is always evaluated; there is no short-circuit evaluation in this case.\n"))
m0002.addFragment(Verbatim.new("nil && puts(\"logical and\")\nnil &  puts(\"and\")"))
m0002.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0002.addFragment(Verbatim.new("and"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("^", "NilClass", "instance", "<code>nil</code>^ <i>anObject</i> -> <code>true</code> or <code>false</code>")
m0003.addFragment(Paragraph.new("Exclusive Or---Returns <code>false</code> if <i>anObject</i> is <code>nil</code> or <code>false</code>, <code>true</code> otherwise.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("|", "NilClass", "instance", "<code>nil</code>| <i>anObject</i> -> <code>true</code> or <code>false</code>")
m0004.addFragment(Paragraph.new("Or---Returns <code>false</code> if <i>anObject</i> is <code>nil</code> or <code>false</code>, <code>true</code> otherwise.\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("nil?", "NilClass", "instance", "<code>nil</code>.nil? -> <code>true</code>")
m0005.addFragment(Paragraph.new("Always returns <code>true</code>.\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("to_a", "NilClass", "instance", "<code>nil</code>.to_a -> []")
m0006.addFragment(Paragraph.new("Always returns an empty array.\n"))
aClass.addMethod(m0006)
m0007 = MethodDesc.new("to_i", "NilClass", "instance", "<code>nil</code>.to_i -> 0")
m0007.addFragment(Paragraph.new("Always returns zero.\n"))
aClass.addMethod(m0007)
m0008 = MethodDesc.new("to_s", "NilClass", "instance", "<code>nil</code>.to_s -> \"\"")
m0008.addFragment(Paragraph.new("Always returns the empty string.\n"))
aClass.addMethod(m0008)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
