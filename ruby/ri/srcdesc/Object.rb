# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Object", "", "class")
aClass.addSubclasses(%w{Array Binding Continuation Data Dir Exception FalseClass File::Stat Hash IO MatchingData Method Module NilClass Numeric Proc Range Regexp String Struct Symbol Thread Time TrueClass})
aClass.addFragment(Paragraph.new("<code>Object</code> is the parent class of all classes in Ruby. Its methods are therefore available to all objects unless explicitly overridden.\n"))
aClass.addFragment(Paragraph.new("<code>Object</code> mixes in the <code>Kernel</code> module, making the built-in kernel functions globally accessible. Although the instance methods of <code>Object</code> are defined by the <code>Kernel</code> module, we have chosen to document them here for clarity.\n"))
aClass.addFragment(Paragraph.new("In the descriptions that follow, the parameter <i>aSymbol</i> refers to a symbol, which is either a quoted string or a <code>Symbol</code> (such as <code>:name</code>).\n"))
m0002 = MethodDesc.new("==", "Object", "instance", "<i>obj</i> == <i>anObject</i> -> <code>true</code> or <code>false</code>")
m0002.addFragment(Paragraph.new("Equality---At the <code>Object</code> level, <code>==</code> returns <code>true</code> only if <i>obj</i> and <i>anObject</i> are the same object. Typically, this method is overridden in descendent classes to provide class-specific meaning.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("===", "Object", "instance", "<i>obj</i> === <i>anObject</i> -> <code>true</code> or <code>false</code>")
m0003.addFragment(Paragraph.new("Case Equality---A synonym for <code>Object\#==</code>, but typically overridden by descendents to provide meaningful semantics in <code>case</code> statements.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("=~", "Object", "instance", "<i>obj</i> =~ <i>anObject</i> -> <code>false</code>")
m0004.addFragment(Paragraph.new("Pattern Match---Overridden by descendents (notably <code>Regexp</code> and <code>String</code>) to provide meaningful pattern-match semantics.\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("__id__", "Object", "instance", "<i>obj</i>.__id__ -> <i>aFixnum</i>")
m0005.addFragment(Paragraph.new("Synonym for <code>Object\#id</code>.\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("__send__", "Object", "instance", "<i>obj</i>.__send__( <i>aSymbol</i> <i>[</i>, <i>args</i><i>]+></i> ) -> <i>anObject</i>")
m0006.addFragment(Paragraph.new("Synonym for <code>Object\#send</code>.\n"))
aClass.addMethod(m0006)
m0007 = MethodDesc.new("class", "Object", "instance", "<i>obj</i>.class -> <i>aClass</i>")
m0007.addFragment(Paragraph.new("Returns the class of <i>obj</i> (synonym for <code>Object\#type</code>).\n"))
aClass.addMethod(m0007)
m0008 = MethodDesc.new("clone", "Object", "instance", "<i>obj</i>.clone -> <i>anObject</i>")
m0008.addFragment(Paragraph.new("Produces a shallow copy of <i>obj</i>---the instance variables of <i>obj</i> are copied, but not the objects they reference. Copies the frozen and tainted state of <i>obj</i>. See also the discussion under <code>Object\#dup</code>.\n"))
m0008.addFragment(Verbatim.new("class Klass\n   attr_accessor :str\nend\ns1 = Klass.new      \#=> \#<Klass:0x4018d234>\ns1.str = \"Hello\"    \#=> \"Hello\"\ns2 = s1.clone       \#=> \#<Klass:0x4018d194  @str=\"Hello\">\ns2.str[1,4] = \"i\"   \#=> \"i\"\ns1.inspect          \#=> \"\#<Klass:0x4018d234  @str=\\\"Hi\\\">\"\ns2.inspect          \#=> \"\#<Klass:0x4018d194  @str=\\\"Hi\\\">\"\n"))
aClass.addMethod(m0008)
m0009 = MethodDesc.new("display", "Object", "instance", "<i>obj</i>.display( <i>port</i>=<code>$></code> ) -> <code>nil</code>")
m0009.addFragment(Paragraph.new("Prints <i>obj</i> on the given port (default <code>$></code>). Equivalent to:\n"))
m0009.addFragment(Verbatim.new("def display(port=$>)\n  port.write self\nend"))
aClass.addMethod(m0009)
m0010 = MethodDesc.new("dup", "Object", "instance", "<i>obj</i>.dup -> <i>anObject</i>")
m0010.addFragment(Paragraph.new("Produces a shallow copy of <i>obj</i>---the instance variables of <i>obj</i> are copied, but not the objects they reference. <code>dup</code> copies the tainted state of <i>obj</i>. See also the discussion under <code>Object\#clone</code>. In general, <code>clone</code> and <code>dup</code> may have different semantics in descendent classes. While <code>clone</code> is used to duplicate an object, including its internal state, <code>dup</code> typically uses the class of the descendent object to create the new instance.\n"))
aClass.addMethod(m0010)
m0011 = MethodDesc.new("eql?", "Object", "instance", "<i>obj</i>.eql?( <i>anObject</i> ) -> <code>true</code> or <code>false</code>")
m0011.addFragment(Paragraph.new("Returns <code>true</code> if <i>obj</i> and <i>anObject</i> have the same value. Used by <code>Hash</code> to test members for equality. For objects of class <code>Object</code>, <code>eql?</code> is synonymous with <code>==</code>. Subclasses normally continue this tradition, but there are exceptions. <code>Numeric</code> types, for example, perform type conversion across <code>==</code>, but not across <code>eql?</code>, so:\n"))
m0011.addFragment(Verbatim.new("1 == 1.0     \#=> true\n1.eql? 1.0   \#=> false\n"))
aClass.addMethod(m0011)
m0012 = MethodDesc.new("equal?", "Object", "instance", "<i>obj</i>.equal?( <i>anObject</i> ) -> <code>true</code> or <code>false</code>")
m0012.addFragment(Paragraph.new("Returns <code>true</code> if <i>obj</i> and <i>anObject</i> have the same object ID. This method should not be overridden by subclasses.\n"))
m0012.addFragment(Verbatim.new("a = [ 'cat', 'dog' ]\nb = [ 'cat', 'dog' ]\na == b         \#=> true\na.id == b.id   \#=> false\na.eql?(b)      \#=> true\na.equal?(b)    \#=> false\n"))
aClass.addMethod(m0012)
m0013 = MethodDesc.new("extend", "Object", "instance", "<i>obj</i>.extend( <i>[</i><i>aModule</i><i>]+></i> ) -> <i>obj</i>")
m0013.addFragment(Paragraph.new("Adds to <i>obj</i> the instance methods from each module given as a parameter.\n"))
m0013.addFragment(Verbatim.new("module Mod\n  def hello\n    \"Hello from Mod.\\n\"\n  end\nend\n\nclass Klass\n  def hello\n    \"Hello from Klass.\\n\"\n  end\nend\n\nk = Klass.new\nk.hello         \#=> \"Hello from Klass.\\n\"\nk.extend(Mod)   \#=> \#<Klass:0x4018d414>\nk.hello         \#=> \"Hello from Mod.\\n\"\n"))
aClass.addMethod(m0013)
m0014 = MethodDesc.new("freeze", "Object", "instance", "<i>obj</i>.freeze -> <i>obj</i>")
m0014.addFragment(Paragraph.new("Prevents further modifications to <i>obj</i>. A <code>TypeError</code> will be raised if modification is attempted. There is no way to unfreeze a frozen object. See also <code>Object\#frozen?</code>.\n"))
m0014.addFragment(Verbatim.new("a = [ \"a\", \"b\", \"c\" ]\na.freeze\na << \"z\""))
m0014.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0014.addFragment(Verbatim.new("prog.rb:3:in `<<': can't modify frozen array (TypeError)\n\tfrom prog.rb:3"))
aClass.addMethod(m0014)
m0015 = MethodDesc.new("frozen?", "Object", "instance", "<i>obj</i>.frozen? -> <code>true</code> or <code>false</code>")
m0015.addFragment(Paragraph.new("Returns the freeze status of <i>obj</i>.\n"))
m0015.addFragment(Verbatim.new("a = [ \"a\", \"b\", \"c\" ]\na.freeze    \#=> [\"a\", \"b\", \"c\"]\na.frozen?   \#=> true\n"))
aClass.addMethod(m0015)
m0016 = MethodDesc.new("hash", "Object", "instance", "<i>obj</i>.hash -> <i>aFixnum</i>")
m0016.addFragment(Paragraph.new("Generates a <code>Fixnum</code> hash value for this object. This function must have the property that <code>a.eql?(b)</code> implies <code>a.hash == b.hash</code>. The hash value is used by class <code>Hash</code>. Any hash value that exceeds the capacity of a <code>Fixnum</code> will be truncated before being used.\n"))
aClass.addMethod(m0016)
m0017 = MethodDesc.new("id", "Object", "instance", "<i>obj</i>.id -> <i>aFixnum</i>")
m0017.addFragment(Paragraph.new("Returns an integer identifier for <i>obj</i>. The same number will be returned on all calls to <code>id</code> for a given object, and no two active objects will share an id. <code>Object\#id</code> is a different concept from the <code>:name</code> notation, which returns the symbol id of <code>name</code>.\n"))
aClass.addMethod(m0017)
m0018 = MethodDesc.new("inspect", "Object", "instance", "<i>obj</i>.inspect -> <i>aString</i>")
m0018.addFragment(Paragraph.new("Returns a string containing a human-readable representation of <i>obj</i>. If not overridden, uses the <code>to_s</code> method to generate the string.\n"))
m0018.addFragment(Verbatim.new("[ 1, 2, 3..4, 'five' ].inspect   \#=> \"[1, 2, 3..4, \\\"five\\\"]\"\nTime.new.inspect                 \#=> \"Sun Mar 04 23:29:19 CST 2001\"\n"))
aClass.addMethod(m0018)
m0019 = MethodDesc.new("instance_eval", "Object", "instance", "<i>obj</i>.instance_eval(<i>aString</i> <i>[</i>, <i>file</i> <i>[</i><i>line</i><i>]</i><i>]</i> ) -> <i>anObject</i><br></br><i>obj</i>.instance_eval {| | block } -> <i>anObject</i>")
m0019.addFragment(Paragraph.new("Evaluates a string containing Ruby source code, or the given block, within the context of the receiver (<i>obj</i>). In order to set the context, the variable <code>self</code> is set to <i>obj</i> while the code is executing, giving the code access to <i>obj</i>'s instance variables. In the version of <code>instance_eval</code> that takes a <code>String</code>, the optional second and third parameters supply a filename and starting line number that are used when reporting compilation errors.\n"))
m0019.addFragment(Verbatim.new("class Klass\n  def initialize\n    @secret = 99\n  end\nend\nk = Klass.new\nk.instance_eval { @secret }   \#=> 99\n"))
aClass.addMethod(m0019)
m0020 = MethodDesc.new("instance_of?", "Object", "instance", "<i>obj</i>.instance_of?( <i>aClass</i> ) -> <code>true</code> or <code>false</code>")
m0020.addFragment(Paragraph.new("Returns <code>true</code> if <i>obj</i> is an instance of the given class. See also <code>Object\#kind_of?</code>.\n"))
aClass.addMethod(m0020)
m0021 = MethodDesc.new("instance_variables", "Object", "instance", "<i>obj</i>.instance_variables -> <i>anArray</i>")
m0021.addFragment(Paragraph.new("Returns an array of instance variable names for the receiver.\n"))
aClass.addMethod(m0021)
m0022 = MethodDesc.new("is_a?", "Object", "instance", "<i>obj</i>.is_a?( <i>aClass</i> ) -> <code>true</code> or <code>false</code>")
m0022.addFragment(Paragraph.new("Synonym for <code>Object\#kind_of?</code>.\n"))
aClass.addMethod(m0022)
m0023 = MethodDesc.new("kind_of?", "Object", "instance", "<i>obj</i>.kind_of?( <i>aClass</i> ) -> <code>true</code> or <code>false</code>")
m0023.addFragment(Paragraph.new("Returns <code>true</code> if <i>aClass</i> is the class of <i>obj</i>, or if <i>aClass</i> is one of the superclasses of <i>obj</i> or modules included in <i>obj</i>.\n"))
m0023.addFragment(Verbatim.new("a = Integer.new\na.instance_of? Numeric      \#=> false\na.instance_of? Integer      \#=> true\na.instance_of? Fixnum       \#=> false\na.instance_of? Comparable   \#=> false\na.kind_of? Numeric          \#=> true\na.kind_of? Integer          \#=> true\na.kind_of? Fixnum           \#=> false\na.kind_of? Comparable       \#=> true\n"))
aClass.addMethod(m0023)
m0024 = MethodDesc.new("method", "Object", "instance", "<i>obj</i>.method( <i>aSymbol</i> ) -> <i>aMethod</i>")
m0024.addFragment(Paragraph.new("Looks up the named method as a receiver in <i>obj</i>, returning a <code>Method</code> object (or raising <code>NameError</code>). The <code>Method</code> object acts as a closure in <i>obj</i>'s object instance, so instance variables and the value of <code>self</code> remain available.\n"))
m0024.addFragment(Verbatim.new("class Demo\n  def initialize(n)\n    @iv = n\n  end\n  def hello()\n    \"Hello, @iv = \#{@iv}\"\n  end\nend\n\nk = Demo.new(99)\nm = k.method(:hello)\nm.call   \#=> \"Hello, @iv = 99\"\n\nl = Demo.new('Fred')\nm = l.method(\"hello\")\nm.call   \#=> \"Hello, @iv = Fred\"\n"))
aClass.addMethod(m0024)
m0025 = MethodDesc.new("method_missing", "Object", "instance", "<i>obj</i>.method_missing( <i>aSymbol</i> <i>[</i>, <i>*args</i><i>]</i> ) -> <i>anObject</i>")
m0025.addFragment(Paragraph.new("Invoked by Ruby when <i>obj</i> is sent a message it cannot handle. <i>aSymbol</i> is the symbol for the method called, and <i>args</i> are any arguments that were passed to it. The example below creates a class <code>Roman</code>, which responds to methods with names consisting of roman numerals, returning the corresponding integer values.\n"))
m0025.addFragment(Verbatim.new("class Roman\n  def romanToInt(str)\n    \# ...\n  end\n  def method_missing(methId)\n    str = methId.id2name\n    romanToInt(str)\n  end\nend"))
m0025.addFragment(Verbatim.new("r = Roman.new\nr.iv      \#=> 4\nr.xxiii   \#=> 23\nr.mm      \#=> 2000\n"))
aClass.addMethod(m0025)
m0026 = MethodDesc.new("methods", "Object", "instance", "<i>obj</i>.methods -> <i>anArray</i>")
m0026.addFragment(Paragraph.new("Returns a list of the names of methods publicly accessible in <i>obj</i>. This will include all the methods accessible in <i>obj</i>'s ancestors.\n"))
m0026.addFragment(Verbatim.new("class Klass\n  def kMethod()\n  end\nend\nk = Klass.new\nk.methods[0..9]    \#=> [\"kMethod\", \"instance_of?\", \"protected_methods\", \"inspect\", \"freeze\", \"dup\", \"__id__\", \"equal?\", \"send\", \"==\"]\nk.methods.length   \#=> 38\n"))
aClass.addMethod(m0026)
m0027 = MethodDesc.new("nil?", "Object", "instance", "<i>obj</i>.nil? -> <code>true</code> or <code>false</code>")
m0027.addFragment(Paragraph.new("All objects except <code>nil</code> return <code>false</code>.\n"))
aClass.addMethod(m0027)
m0028 = MethodDesc.new("private_methods", "Object", "instance", "<i>obj</i>.private_methods -> <i>anArray</i>")
m0028.addFragment(Paragraph.new("Returns a list of private methods accessible within <i>obj</i>. This will include the private methods in <i>obj</i>'s ancestors, along with any mixed-in module functions.\n"))
aClass.addMethod(m0028)
m0029 = MethodDesc.new("protected_methods", "Object", "instance", "<i>obj</i>.protected_methods -> <i>anArray</i>")
m0029.addFragment(Paragraph.new("Returns the list of protected methods accessible to <i>obj</i>.\n"))
aClass.addMethod(m0029)
m0030 = MethodDesc.new("public_methods", "Object", "instance", "<i>obj</i>.public_methods -> <i>anArray</i>")
m0030.addFragment(Paragraph.new("Synonym for <code>Object\#methods</code>.\n"))
aClass.addMethod(m0030)
m0031 = MethodDesc.new("respond_to?", "Object", "instance", "<i>obj</i>.respond_to?( <i>aSymbol</i>, <i>includePriv</i>=<code>false</code> ) -> <code>true</code> or <code>false</code>")
m0031.addFragment(Paragraph.new("Returns <code>true</code> if <i>obj</i> responds to the given method. Private methods are included in the search only if the optional second parameter evaluates to <code>true</code>.\n"))
aClass.addMethod(m0031)
m0032 = MethodDesc.new("send", "Object", "instance", "<i>obj</i>.send( <i>aSymbol</i> <i>[</i>, <i>args</i><i>]*</i> ) -> <i>anObject</i>")
m0032.addFragment(Paragraph.new("Invokes the method identified by <i>aSymbol</i>, passing it any arguments specified. You can use <code>__send__</code> if the name <code>send</code> clashes with an existing method in <i>obj</i>.\n"))
m0032.addFragment(Verbatim.new("class Klass\n  def hello(*args)\n    \"Hello \" + args.join(' ')\n  end\nend\nk = Klass.new\nk.send :hello, \"gentle\", \"readers\"   \#=> \"Hello gentle readers\"\n"))
aClass.addMethod(m0032)
m0033 = MethodDesc.new("singleton_methods", "Object", "instance", "<i>obj</i>.singleton_methods -> <i>anArray</i>")
m0033.addFragment(Paragraph.new("Returns an array of the names of singleton methods for <i>obj</i>.\n"))
m0033.addFragment(Verbatim.new("class Klass\n  def Klass.classMethod\n  end\nend\nk = Klass.new\ndef k.sm()\nend\nKlass.singleton_methods   \#=> [\"classMethod\"]\nk.singleton_methods       \#=> [\"sm\"]\n"))
aClass.addMethod(m0033)
m0034 = MethodDesc.new("taint", "Object", "instance", "<i>obj</i>.taint -> <i>obj</i>")
m0034.addFragment(Paragraph.new("Marks <i>obj</i> as tainted (see Chapter 20, which begins on page 257).\n"))
aClass.addMethod(m0034)
m0035 = MethodDesc.new("tainted?", "Object", "instance", "<i>obj</i>.tainted? -> <code>true</code> or <code>false</code>")
m0035.addFragment(Paragraph.new("Returns <code>true</code> if the object is tainted.\n"))
aClass.addMethod(m0035)
m0036 = MethodDesc.new("to_a", "Object", "instance", "<i>obj</i>.to_a -> <i>anArray</i>")
m0036.addFragment(Paragraph.new("Returns an array representation of <i>obj</i>. For objects of class <code>Object</code> and others that don't explicitly override the method, the return value is an array containing <code>self</code>.\n"))
m0036.addFragment(Verbatim.new("self.to_a       \#=> [main]\n\"hello\".to_a    \#=> [\"hello\"]\nTime.new.to_a   \#=> [19, 29, 23, 4, 3, 2001, 0, 63, false, \"CST\"]\n"))
aClass.addMethod(m0036)
m0037 = MethodDesc.new("to_s", "Object", "instance", "<i>obj</i>.to_s -> <i>aString</i>")
m0037.addFragment(Paragraph.new("Returns a string representing <i>obj</i>. The default <code>to_s</code> prints the object's class and an encoding of the object id. As a special case, the top-level object that is the initial execution context of Ruby programs returns ``main.''\n"))
aClass.addMethod(m0037)
m0038 = MethodDesc.new("type", "Object", "instance", "<i>obj</i>.type -> <i>aClass</i>")
m0038.addFragment(Paragraph.new("Returns the class of <i>obj</i>.\n"))
aClass.addMethod(m0038)
m0039 = MethodDesc.new("untaint", "Object", "instance", "<i>obj</i>.untaint -> <i>obj</i>")
m0039.addFragment(Paragraph.new("Removes the taint from <i>obj</i>.\n"))
aClass.addMethod(m0039)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }