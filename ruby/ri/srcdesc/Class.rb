# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Class", "Module", "class")
aClass.addFragment(Paragraph.new("Classes in Ruby are first-class objects---each is an instance of class <code>Class</code>.\n"))
aClass.addFragment(Paragraph.new("When a new class is created (typically using <code>class Name ... end</code>), an object of type <code>Class</code> is created and assigned to a global constant (<code>Name</code> in this case). When <code>Name.new</code> is called to create a new object, the <code>new</code> method in <code>Class</code> is run by default. This can be demonstrated by overriding <code>new</code> in <code>Class</code>:\n"))
aClass.addFragment(Verbatim.new("class Class\n   alias oldNew  new\n   def new(*args)\n     print \"Creating a new \", self.name, \"\\n\"\n     oldNew(*args)\n   end\n end\n\n\n class Name\n end\n\n\n n = Name.new"))
aClass.addFragment(Paragraph.new("<em>produces:</em>\n"))
aClass.addFragment(Verbatim.new("Creating a new Name"))
m0002 = MethodDesc.new("inherited", "Class", "class", "<i>aClass</i>.inherited( <i>aSubClass</i> )")
m0002.addFragment(Paragraph.new("This is a singleton method (per class) invoked by Ruby when a subclass of <i>aClass</i> is created. The new subclass is passed as a parameter.\n"))
m0002.addFragment(Verbatim.new("class Top\n  def Top.inherited(sub)\n    print \"New subclass: \", sub, \"\\n\"\n  end\nend\n\n\nclass Middle < Top\nend\n\n\nclass Bottom < Middle\nend"))
m0002.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0002.addFragment(Verbatim.new("New subclass: Middle\nNew subclass: Bottom"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("new", "Class", "class", "Class.new( <i>aSuperClass</i>=<code>Object</code> ) -> <i>aClass</i>")
m0003.addFragment(Paragraph.new("Creates a new anonymous (unnamed) class with the given superclass (or <code>Object</code> if no parameter is given).\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("new", "Class", "instance", "<i>aClass</i>.new( <i>[</i><i>args</i><i>]*</i> ) -> <i>anObject</i>")
m0004.addFragment(Paragraph.new("Creates a new object of <i>aClass</i>'s class, then invokes that object's <code>initialize</code> method, passing it <i>args</i>.\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("superclass", "Class", "instance", "<i>aClass</i>.superclass -> <i>aSuperClass</i> or <code>nil</code>")
m0005.addFragment(Paragraph.new("Returns the superclass of <i>aClass</i>, or <code>nil</code>.\n"))
m0005.addFragment(Verbatim.new("Class.superclass    \#=> Module\nObject.superclass   \#=> nil\n"))
aClass.addMethod(m0005)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
