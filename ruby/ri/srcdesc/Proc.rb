# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Proc", "Object", "class")
aClass.addFragment(Paragraph.new("<code>Proc</code> objects are blocks of code that have been bound to a set of local variables. Once bound, the code may be called in different contexts and still access those variables.\n"))
aClass.addFragment(Verbatim.new("def genTimes(factor)\n  return Proc.new {|n| n*factor }\nend\n\ntimes3 = genTimes(3)\ntimes5 = genTimes(5)\n\ntimes3.call(12)               \#=> 36\ntimes5.call(5)                \#=> 25\ntimes3.call(times5.call(4))   \#=> 60\n"))
m0002 = MethodDesc.new("new", "Proc", "class", "Proc.new <i>[</i>{| | block } <i>]</i> -> <i>aProc</i>")
m0002.addFragment(Paragraph.new("Creates a new <code>Proc</code> object, bound to the current context. It may be called without a block only within a method with an attached block, in which case that block is converted to the <code>Proc</code> object.\n"))
m0002.addFragment(Verbatim.new("def procFrom\n  Proc.new\nend\naProc = procFrom { \"hello\" }\naProc.call   \#=> \"hello\"\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("[]", "Proc", "instance", "<i>prc</i>[ <i>[</i><i>params</i><i>]*</i> ] -> <i>anObject</i>")
m0003.addFragment(Paragraph.new("Synonym for <code>Proc.call</code>.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("arity", "Proc", "instance", "<i>prc</i>.arity -> <i>anInteger</i>")
m0004.addFragment(Paragraph.new("Returns the number of arguments required by the block. If the block takes no arguments, returns -1. If it takes one argument, returns -2. Otherwise, returns a positive argument count unless the last argument is prefixed with *, in which case the argument count is negated. The number of required arguments is <i>anInteger</i> for positive values, and <code>(</code><i>anInteger</i><code>+1).abs</code> otherwise.\n"))
m0004.addFragment(Verbatim.new("Proc.new {||}.arity        \#=> 0\nProc.new {|a|}.arity       \#=> -1\nProc.new {|a,b|}.arity     \#=> 2\nProc.new {|a,b,c|}.arity   \#=> 3\nProc.new {|*a|}.arity      \#=> -1\nProc.new {|a,*b|}.arity    \#=> -2\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("call", "Proc", "instance", "<i>prc</i>.call( <i>[</i><i>params</i><i>]*</i> ) -> <i>anObject</i>")
m0005.addFragment(Paragraph.new("Invokes the block, setting the block's parameters to the values in <i>params</i> using the same rules as used by parallel assignment. Returns the value of the last expression evaluated in the block.\n"))
m0005.addFragment(Verbatim.new("aProc = Proc.new {|a, *b| b.collect {|i| i*a }}\naProc.call(9, 1, 2, 3)   \#=> [9, 18, 27]\naProc[9, 1, 2, 3]        \#=> [9, 18, 27]\n"))
aClass.addMethod(m0005)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
