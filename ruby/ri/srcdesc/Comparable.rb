# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Comparable", "", "module")
aClass.addFragment(Paragraph.new("The <code>Comparable</code> mixin is used by classes whose objects may be ordered. The class must define the <code><=></code> operator, which compares the receiver against another object, returning -1, 0, or +1 depending on whether the receiver is less than, equal to, or greater than the other object. <code>Comparable</code> uses <code><=></code> to implement the conventional comparison operators (<code><</code>, <code><=</code>, <code>==</code>, <code>>=</code>, and <code>></code>) and the method <code>between?</code>.\n"))
aClass.addFragment(Verbatim.new("class SizeMatters\n  include Comparable\n  attr :str\n  def <=>(anOther)\n    str.size <=> anOther.str.size\n  end\n  def initialize(str)\n    @str = str\n  end\n  def inspect\n    @str\n  end\nend\n\ns1 = SizeMatters.new(\"Z\")\ns2 = SizeMatters.new(\"YY\")\ns3 = SizeMatters.new(\"XXX\")\ns4 = SizeMatters.new(\"WWWW\")\ns5 = SizeMatters.new(\"VVVVV\")\n\ns1 < s2                       \#=> true\ns4.between?(s1, s3)           \#=> false\ns4.between?(s3, s5)           \#=> true\n[ s3, s2, s5, s4, s1 ].sort   \#=> [Z, YY, XXX, WWWW, VVVVV]\n"))
m0002 = MethodDesc.new("Comparisons", "Comparable", "instance", "<i>anObject</i> < <i>otherObject</i> -> <code>true</code> or <code>false</code><br></br><i>anObject</i> <= <i>otherObject</i> -> <code>true</code> or <code>false</code><br></br><i>anObject</i> == <i>otherObject</i> -> <code>true</code> or <code>false</code><br></br><i>anObject</i> >= <i>otherObject</i> -> <code>true</code> or <code>false</code><br></br><i>anObject</i> > <i>otherObject</i> -> <code>true</code> or <code>false</code><br></br>")
m0002.addFragment(Paragraph.new("Compares two objects based on the receiver's <code><=></code> method.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("between?", "Comparable", "instance", "<i>anObject</i>.between?( <i>min</i>, <i>max</i> ) -> <code>true</code> or <code>false</code>")
m0003.addFragment(Paragraph.new("Returns <code>false</code> if <i>anObject</i> <code><=></code> <i>min</i> is less than zero or if <i>anObject</i> <code><=></code> <i>max</i> is greater than zero, <code>true</code> otherwise.\n"))
m0003.addFragment(Verbatim.new("3.between?(1, 5)               \#=> true\n6.between?(1, 5)               \#=> false\n'cat'.between?('ant', 'dog')   \#=> true\n'gnu'.between?('ant', 'dog')   \#=> false\n"))
aClass.addMethod(m0003)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
