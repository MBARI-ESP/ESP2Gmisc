# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("ObjectSpace", "", "module")
aClass.addFragment(Paragraph.new("The <code>ObjectSpace</code> module contains a number of routines that interact with the garbage collection facility and allow you to traverse all living objects with an iterator.\n"))
aClass.addFragment(Paragraph.new("<code>ObjectSpace</code> also provides support for object finalizers, procs that will be called when a specific object is about to be destroyed by garbage collection.\n"))
aClass.addFragment(Verbatim.new("include ObjectSpace\n\n\na = \"A\"\nb = \"B\"\nc = \"C\"\n\n\ndefine_finalizer(a, proc {|id| puts \"Finalizer one on \#{id}\" })\ndefine_finalizer(a, proc {|id| puts \"Finalizer two on \#{id}\" })\ndefine_finalizer(b, proc {|id| puts \"Finalizer three on \#{id}\" })"))
aClass.addFragment(Paragraph.new("<em>produces:</em>\n"))
aClass.addFragment(Verbatim.new("0x4018d4f0\nn finals=>1\nFinalizer three on 537684600\n0x4018d504\nn finals=>0\nFinalizer one on 537684610\nn finals=>0\nFinalizer two on 537684610"))
m0002 = MethodDesc.new("_id2ref", "ObjectSpace", "class", "ObjectSpace._id2ref( <i>anId</i> ) -> <i>anObject</i>")
m0002.addFragment(Paragraph.new("Converts an object id to a reference to the object. May not be called on an object id passed as a parameter to a finalizer.\n"))
m0002.addFragment(Verbatim.new("s = \"I am a string\"             \#=> \"I am a string\"\nr = ObjectSpace._id2ref(s.id)   \#=> \"I am a string\"\nr == s                          \#=> true\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("define_finalizer", "ObjectSpace", "class", "ObjectSpace.define_finalizer( <i>anObject</i>, <i>aProc</i>=proc() )")
m0003.addFragment(Paragraph.new("Adds <i>aProc</i> as a finalizer, to be called when <i>anObject</i> is about to be destroyed.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("each_object", "ObjectSpace", "class", "ObjectSpace.each_object( <i>[</i> <i>aClassOrMod</i><i>]</i> ) {| anObj | block } -> <i>aFixnum</i>")
m0004.addFragment(Paragraph.new("Calls the block once for each living, nonimmediate object in this Ruby process. If <i>aClassOrMod</i> is specified, calls the block for only those classes or modules that match (or are a subclass of) <i>aClassOrMod</i>. Returns the number of objects found.\n"))
m0004.addFragment(Verbatim.new("a = 102.7\nb = 95\nObjectSpace.each_object(Numeric) {|x| p x }\nprint \"Total count: \", ObjectSpace.each_object {} ,\"\\n\""))
m0004.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0004.addFragment(Verbatim.new("102.7\n2.718281828\n3.141592654\nTotal count: 376"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("garbage_collect", "ObjectSpace", "class", "ObjectSpace.garbage_collect -> <code>nil</code>")
m0005.addFragment(Paragraph.new("Initiates garbage collection (see module <code>GC</code> on page 414).\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("undefine_finalizer", "ObjectSpace", "class", "ObjectSpace.undefine_finalizer( <i>anObject</i> )")
m0006.addFragment(Paragraph.new("Removes all finalizers for <i>anObject</i>.\n"))
aClass.addMethod(m0006)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
