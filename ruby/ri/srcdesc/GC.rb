# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("GC", "", "module")
aClass.addFragment(Paragraph.new("The <code>GC</code> module provides an interface to Ruby's mark and sweep garbage collection mechanism. Some of the underlying methods are also available via the <code>ObjectSpace</code> module, described beginning on page 434.\n"))
m0002 = MethodDesc.new("disable", "GC", "class", "GC.disable -> <code>true</code> or <code>false</code>")
m0002.addFragment(Paragraph.new("Disables garbage collection, returning <code>true</code> if garbage collection was already disabled.\n"))
m0002.addFragment(Verbatim.new("GC.disable   \#=> false\nGC.disable   \#=> true\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("enable", "GC", "class", "GC.enable -> <code>true</code> or <code>false</code>")
m0003.addFragment(Paragraph.new("Enables garbage collection, returning <code>true</code> if garbage collection was disabled.\n"))
m0003.addFragment(Verbatim.new("GC.disable   \#=> false\nGC.enable    \#=> true\nGC.enable    \#=> false\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("start", "GC", "class", "GC.start -> <code>nil</code>")
m0004.addFragment(Paragraph.new("Initiates garbage collection, unless manually disabled.\n"))
m0004.addFragment(Verbatim.new("GC.start   \#=> nil\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("garbage_collect", "GC", "instance", "garbage_collect -> <code>nil</code>")
m0005.addFragment(Paragraph.new("Equivalent to <code>GC::start</code>.\n"))
m0005.addFragment(Verbatim.new("include GC\ngarbage_collect   \#=> nil\n"))
aClass.addMethod(m0005)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
