# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("ThreadGroup", "Object", "class")
aClass.addFragment(Paragraph.new("<code>ThreadGroup</code> provides a means of keeping track of a number of threads as a group. A <code>Thread</code> can belong to only one <code>ThreadGroup</code> at a time; adding a thread to a new group will remove it from any previous group.\n"))
aClass.addFragment(Paragraph.new("Newly created threads belong to the same group as the thread from which they were created.\n"))
m0002 = MethodDesc.new("new", "ThreadGroup", "class", "ThreadGroup.new -> <i>thgrp</i>")
m0002.addFragment(Paragraph.new("Returns a newly created <code>ThreadGroup</code>. The group is initially empty.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("add", "ThreadGroup", "instance", "<i>thgrp</i>.add( <i>aThread</i> ) -> <i>thgrp</i>")
m0003.addFragment(Paragraph.new("Adds the given thread to this group, removing it from any other group to which it may have previously belonged.\n"))
m0003.addFragment(Verbatim.new("puts \"Initial group is \#{ThreadGroup::Default.list}\"\ntg = ThreadGroup.new\nt1 = Thread.new { sleep 10 }\nt2 = Thread.new { sleep 10 }\nputs \"t1 is \#{t1}\"\nputs \"t2 is \#{t2}\"\ntg.add( t1 )\nputs \"Initial group now \#{ThreadGroup::Default.list}\"\nputs \"tg group now \#{tg.list}\""))
m0003.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0003.addFragment(Verbatim.new("Initial group is \#<Thread:0x40196528>\nt1 is \#<Thread:0x4018d400>\nt2 is \#<Thread:0x4018d3c4>\nInitial group now \#<Thread:0x4018d3c4>\#<Thread:0x40196528>\ntg group now \#<Thread:0x4018d400>"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("list", "ThreadGroup", "instance", "<i>thgrp</i>.list -> <i>anArray</i>")
m0004.addFragment(Paragraph.new("Returns an array of all existing <code>Thread</code> objects that belong to this group.\n"))
m0004.addFragment(Verbatim.new("ThreadGroup::Default.list   \#=> [\#<Thread:0x40196528 run>]\n"))
aClass.addMethod(m0004)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
