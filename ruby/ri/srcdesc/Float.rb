# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Float", "Numeric", "class")
aClass.addFragment(Paragraph.new("<code>Float</code> objects represent real numbers using the native architecture's double-precision floating point representation.\n"))
m0002 = MethodDesc.new("Arithmeticoperations", "Float", "instance", "<p></p>")
m0002.addFragment(Paragraph.new("Performs various arithmetic operations on <i>flt</i>.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("<=>", "Float", "instance", "<i>flt</i> <=> <i>aNumeric</i> -> -1, 0, +1")
m0003.addFragment(Paragraph.new("Returns -1, 0, or +1 depending on whether <i>flt</i> is less than, equal to, or greater than <i>aNumeric</i>. This is the basis for the tests in <code>Comparable</code>.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("ceil", "Float", "instance", "<i>flt</i>.ceil -> <i>anInteger</i>")
m0004.addFragment(Paragraph.new("Returns the smallest <code>Integer</code> greater than or equal to <i>flt</i>.\n"))
m0004.addFragment(Verbatim.new("1.2.ceil      \#=> 2\n2.0.ceil      \#=> 2\n(-1.2).ceil   \#=> -1\n(-2.0).ceil   \#=> -2\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("finite?", "Float", "instance", "<i>flt</i>.finite? -> <code>true</code> or <code>false</code>")
m0005.addFragment(Paragraph.new("Returns <code>true</code> if <i>flt</i> is a valid IEEE floating point number (it is not infinite, and <code>nan?</code> is <code>false</code>).\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("floor", "Float", "instance", "<i>flt</i>.floor -> <i>anInteger</i>")
m0006.addFragment(Paragraph.new("Returns the largest integer less than or equal to <i>flt</i>.\n"))
m0006.addFragment(Verbatim.new("1.2.floor      \#=> 1\n2.0.floor      \#=> 2\n(-1.2).floor   \#=> -2\n(-2.0).floor   \#=> -2\n"))
aClass.addMethod(m0006)
m0007 = MethodDesc.new("infinite?", "Float", "instance", "<i>flt</i>.infinite? -> <code>nil</code>, -1, +1")
m0007.addFragment(Paragraph.new("Returns <code>nil</code>, -1, or +1 depending on whether <i>flt</i> is finite, -infinity, or +infinity.\n"))
m0007.addFragment(Verbatim.new("(0.0).infinite?        \#=> nil\n(-1.0/0.0).infinite?   \#=> -1\n(+1.0/0.0).infinite?   \#=> 1\n"))
aClass.addMethod(m0007)
m0008 = MethodDesc.new("nan?", "Float", "instance", "<i>flt</i>.nan? -> <code>true</code> or <code>false</code>")
m0008.addFragment(Paragraph.new("Returns <code>true</code> if <i>flt</i> is an invalid IEEE floating point number.\n"))
m0008.addFragment(Verbatim.new("a = -1.0          \#=> -1.0\na.nan?            \#=> false\na = Math.log(a)   \#=> NaN\na.nan?            \#=> true\n"))
aClass.addMethod(m0008)
m0009 = MethodDesc.new("round", "Float", "instance", "<i>flt</i>.round -> <i>anInteger</i>")
m0009.addFragment(Paragraph.new("Rounds <i>flt</i> to the nearest integer. Equivalent to:\n"))
m0009.addFragment(Verbatim.new("def round\n  return floor(self+0.5) if self > 0.0\n  return ceil(self-0.5)  if self < 0.0\n  return 0.0\nend"))
m0009.addFragment(Verbatim.new("1.5.round      \#=> 2\n(-1.5).round   \#=> -2\n"))
aClass.addMethod(m0009)
m0010 = MethodDesc.new("to_f", "Float", "instance", "<i>flt</i>.to_f -> <i>flt</i>")
m0010.addFragment(Paragraph.new("Returns <i>flt</i>.\n"))
aClass.addMethod(m0010)
m0011 = MethodDesc.new("to_i", "Float", "instance", "<i>flt</i>.to_i -> <i>anInteger</i>")
m0011.addFragment(Paragraph.new("Returns <i>flt</i> truncated to an <code>Integer</code>.\n"))
aClass.addMethod(m0011)
m0012 = MethodDesc.new("to_s", "Float", "instance", "<i>flt</i>.to_s -> <i>aString</i>")
m0012.addFragment(Paragraph.new("Returns a string containing a representation of self. As well as a fixed or exponential form of the number, the call may return ``<code>NaN</code>'', ``<code>Infinity</code>'', and ``<code>-Infinity</code>''.\n"))
aClass.addMethod(m0012)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
