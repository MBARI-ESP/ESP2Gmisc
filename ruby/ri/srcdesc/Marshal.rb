# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Marshal", "", "module")
aClass.addFragment(Paragraph.new("The marshaling library converts collections of Ruby objects into a byte stream, allowing them to be stored outside the currently active script. This data may subsequently be read and the original objects reconstituted. Marshaling is described starting on page 272.\n"))
aClass.addFragment(Paragraph.new("Some objects cannot be dumped: if the objects to be dumped include bindings, procedure objects, instances of class <code>IO</code>, or singleton objects, a <code>TypeError</code> will be raised.\n"))
aClass.addFragment(Paragraph.new("If your class has special serialization needs (for example, if you want to serialize in some specific format), or if it contains objects that would otherwise not be serializable, you can implement your own serialization strategy by defining two methods, <code>_dump</code> and <code>_load</code>:\n"))
aClass.addFragment(Paragraph.new("The instance method <code>_dump</code> should return a <code>String</code> object containing all the information necessary to reconstitute objects of this class and all referenced objects up to a maximum depth of <em>aDepth</em> (a value of -1 should disable depth checking). The class method <code>_load</code> should take a <code>String</code> and return an object of this class.\n"))
m0002 = MethodDesc.new("dump", "Marshal", "class", "dump( <i>anObject</i> <i>[</i>, <i>anIO</i><i>]</i> , <i>limit</i>=--1 ) -> <i>anIO</i>")
m0002.addFragment(Paragraph.new("Serializes <i>anObject</i> and all descendent objects. If <i>anIO</i> is specified, the serialized data will be written to it, otherwise the data will be returned as a <code>String</code>. If <i>limit</i> is specified, the traversal of subobjects will be limited to that depth. If <i>limit</i> is negative, no checking of depth will be performed.\n"))
m0002.addFragment(Verbatim.new("class Klass\n  def initialize(str)\n    @str = str\n  end\n  def sayHello\n    @str\n  end\nend"))
m0002.addFragment(Verbatim.new("o = Klass.new(\"hello\\n\")\ndata = Marshal.dump(o)\nobj = Marshal.load(data)\nobj.sayHello   \#=> \"hello\\n\"\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("load", "Marshal", "class", "load( <i>from</i> <i>[</i>, <i>aProc</i><i>]</i> ) -> <i>anObject</i>")
m0003.addFragment(Paragraph.new("Returns the result of converting the serialized data in <i>from</i> into a Ruby object (possibly with associated subordinate objects). <i>from</i> may be either an instance of <code>IO</code> or an object that responds to <code>to_str</code>. If <i>proc</i> is specified, it will be passed each object as it is deserialized.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("restore", "Marshal", "class", "restore( <i>from</i> <i>[</i>, <i>aProc</i><i>]</i> ) -> <i>anObject</i>")
m0004.addFragment(Paragraph.new("A synonym for <code>Marshal::load</code>.\n"))
aClass.addMethod(m0004)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
