# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Struct::Tms", "Struct", "class")
aClass.addFragment(Paragraph.new("This structure is returned by <code>Time::times</code>. It holds information on process times on those platforms that support it. Not all values are valid on all platforms.\n"))
aClass.addFragment(Paragraph.new("This structure contains the following instance variables and the corresponding accessors:\n"))
aClass.addFragment(Paragraph.new("See also <code>Struct</code> on page 385 and <code>Time::times</code> on page 398.\n"))
aClass.addFragment(Verbatim.new("t = Time.times\n[ t.utime, t.stime]      \#=> [0.01, 0.0]\n[ t.cutime, t.cstime ]   \#=> [0.0, 0.0]\n"))

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
