# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Errno", "", "module")
aClass.addFragment(Paragraph.new("Ruby exception objects are subclasses of <code>Exception</code>. However, operating systems typically report errors using plain integers. Module <code>Errno</code> is created dynamically to map these operating system errors to Ruby classes, with each error number generating its own subclass of <code>SystemCallError</code>. As the subclass is created in module <code>Errno</code>, its name will start <code>Errno::</code>.\n"))
aClass.addFragment(Paragraph.new("The names of the <code>Errno</code><code>::</code> classes depend on the environment in which Ruby runs. On a typical Unix or Windows platform, there are <code>Errno</code> classes such as <code>Errno::EACCES</code>, <code>Errno::EAGAIN</code>, <code>Errno::EINTR</code>, and so on.\n"))
aClass.addFragment(Paragraph.new("The integer operating system error number corresponding to a particular error is available as the class constant <code>Errno::</code><em>error</em><code>::Errno</code>.\n"))
aClass.addFragment(Verbatim.new("Errno::EACCES::Errno   \#=> 13\nErrno::EAGAIN::Errno   \#=> 11\nErrno::EINTR::Errno    \#=> 4\n"))
aClass.addFragment(Paragraph.new("The full list of operating system errors on your particular platform are available as the constants of <code>Errno</code>.\n"))
aClass.addFragment(Verbatim.new("Errno.constants   \#=> E2BIG, EACCES, EADDRINUSE, EADDRNOTAVAIL, EADV, EAFNOSUPPORT, EAGAIN, ...\n"))

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
