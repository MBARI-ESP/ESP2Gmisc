# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Regexp", "Object", "class")
aClass.addFragment(Paragraph.new("A <code>Regexp</code> holds a regular expression, used to match a pattern against strings. Regexps are created using the <code>/.../</code> and <code>%r{...}</code> literals, and by the <code>Regexp::new</code> constructor.\n"))
m0002 = MethodDesc.new("compile", "Regexp", "class", "Regexp.compile( <i>pattern</i> <i>[</i>, <i>options</i> <i>[</i><i>lang</i><i>]</i><i>]</i> ) -> <i>aRegexp</i>")
m0002.addFragment(Paragraph.new("Synonym for <code>Regexp.new</code>.\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("escape", "Regexp", "class", "Regexp.escape( <i>aString</i> ) -> <i>aNewString</i>")
m0003.addFragment(Paragraph.new("Escapes any characters that would have special meaning in a regular expression. For any string, <code>Regexp.escape(<i>str</i>)=~<i>str</i></code> will be true.\n"))
m0003.addFragment(Verbatim.new("Regexp.escape('\\\\*?{}.')   \#=> \\\\\\\\\\*\\?\\{\\}\\.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("last_match", "Regexp", "class", "Regexp.last_match -> <i>aMatchData</i>")
m0004.addFragment(Paragraph.new("Returns the <code>MatchData</code> object generated by the last successful pattern match. Equivalent to reading the global variable <code>$~</code>. <code>MatchData</code> is described on page 340.\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("new", "Regexp", "class", "Regexp.new( <i>pattern</i> <i>[</i>, <i>options</i> <i>[</i><i>lang</i><i>]</i><i>]</i> ) -> <i>aRegexp</i>")
m0005.addFragment(Paragraph.new("Constructs a new regular expression from <i>pattern</i>, which can be either a <code>String</code> or a <code>Regexp</code> (in which case that regexp's options are not propagated). If <i>options</i> is a <code>Fixnum</code>, it should be one or more of the constants <code>Regexp::EXTENDED</code>, <code>Regexp::IGNORECASE</code>, and <code>Regexp::POSIXLINE</code>, <em>or</em>-ed together. Otherwise, if <i>options</i> is not <code>nil</code>, the regexp will be case insensitive. The <i>lang</i> parameter enables multibyte support for the regexp: `n', `N' = none, `e', `E' = EUC, `s', `S' = SJIS, `u', `U' = UTF-8.\n"))
m0005.addFragment(Verbatim.new("r1 = Regexp.new('^a-z+:\\\\s+\\w+')        \#=> /^a-z+:\\s+\\w+/\nr2 = Regexp.new(r1, true)               \#=> /^a-z+:\\s+\\w+/i\nr3 = Regexp.new(r2, Regexp::EXTENDED)   \#=> /^a-z+:\\s+\\w+/x\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("quote", "Regexp", "class", "Regexp.quote( <i>aString</i> ) -> <i>aNewString</i>")
m0006.addFragment(Paragraph.new("Synonym for <code>Regexp.escape</code>.\n"))
aClass.addMethod(m0006)
m0007 = MethodDesc.new("==", "Regexp", "instance", "<i>rxp</i> == <i>aRegexp</i> -> <code>true</code> or <code>false</code>")
m0007.addFragment(Paragraph.new("Equality---Two regexps are equal if their patterns are identical, they have the same character set code, and their <code>casefold?</code> values are the same.\n"))
m0007.addFragment(Verbatim.new("/abc/  == /abc/x   \#=> true\n/abc/  == /abc/i   \#=> false\n/abc/u == /abc/n   \#=> false\n"))
aClass.addMethod(m0007)
m0008 = MethodDesc.new("===", "Regexp", "instance", "<i>rxp</i> === <i>aString</i> -> <code>true</code> or <code>false</code>")
m0008.addFragment(Paragraph.new("Case Equality---Synonym for <code>Regexp\#=~</code> used in case statements.\n"))
m0008.addFragment(Verbatim.new("a = \"HELLO\"\ncase a\nwhen /^a-z*$/; print \"Lower case\\n\"\nwhen /^A-Z*$/; print \"Upper case\\n\"\nelse;            print \"Mixed case\\n\"\nend"))
m0008.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0008.addFragment(Verbatim.new("Upper case"))
aClass.addMethod(m0008)
m0009 = MethodDesc.new("=~", "Regexp", "instance", "<i>rxp</i> =~ <i>aString</i> -> <i>anInteger</i> or <code>nil</code>")
m0009.addFragment(Paragraph.new("Match---Matches <i>rxp</i> against <i>aString</i>, returning the offset of the start of the match or <code>nil</code> if the match failed.\n"))
m0009.addFragment(Verbatim.new("/SIT/  =~ \"insensitive\"   \#=> nil\n/SIT/i =~ \"insensitive\"   \#=> 5\n"))
aClass.addMethod(m0009)
m0010 = MethodDesc.new("~", "Regexp", "instance", "~ <i>rxp</i> -> <i>anInteger</i> or <code>nil</code>")
m0010.addFragment(Paragraph.new("Match---Matches <i>rxp</i> against the contents of <code>$_</code>. Equivalent to <code><i>rxp</i> =~ $_</code>.\n"))
m0010.addFragment(Verbatim.new("$_ = \"input data\"\n~ /at/   \#=> 7\n"))
aClass.addMethod(m0010)
m0011 = MethodDesc.new("casefold?", "Regexp", "instance", "<i>rxp</i>.casefold? -> <code>true</code> or <code>false</code>")
m0011.addFragment(Paragraph.new("Returns the value of the case-insensitive flag.\n"))
aClass.addMethod(m0011)
m0012 = MethodDesc.new("kcode", "Regexp", "instance", "<i>rxp</i>.kcode -> <i>aString</i>")
m0012.addFragment(Paragraph.new("Returns the character set code for the regexp.\n"))
aClass.addMethod(m0012)
m0013 = MethodDesc.new("match", "Regexp", "instance", "<i>rxp</i>.match(<i>aString</i>) -> <i>aMatchData</i> or <code>nil</code>")
m0013.addFragment(Paragraph.new("Returns a <code>MatchData</code> object (see page 340) describing the match, or <code>nil</code> if there was no match. This is equivalent to retrieving the value of the special variable <code>$~</code> following a normal match.\n"))
m0013.addFragment(Verbatim.new("/(.)(.)(.)/.match(\"abc\")[2]   \#=> \"b\"\n"))
aClass.addMethod(m0013)
m0014 = MethodDesc.new("source", "Regexp", "instance", "<i>rxp</i>.source -> <i>aString</i>")
m0014.addFragment(Paragraph.new("Returns the original string of the pattern.\n"))
m0014.addFragment(Verbatim.new("/ab+c/ix.source   \#=> \"ab+c\"\n"))
aClass.addMethod(m0014)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
