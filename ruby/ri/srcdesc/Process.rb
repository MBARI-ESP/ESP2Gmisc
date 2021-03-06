# Automatically generated....
raise 'Must be invoked by installation process' unless $opfile

# -----------------------------------------
aClass = ClassModule.new("Process", "", "module")
aClass.addFragment(Paragraph.new("The <code>Process</code> module is a collection of methods used to manipulate processes.\n"))
m0002 = MethodDesc.new("egid", "Process", "class", "Process.egid -> <i>aFixnum</i>")
m0002.addFragment(Paragraph.new("Returns the effective group id for this process.\n"))
m0002.addFragment(Verbatim.new("Process.egid   \#=> 500\n"))
aClass.addMethod(m0002)
m0003 = MethodDesc.new("egid=", "Process", "class", "Process.egid= <i>aFixnum</i> -> <i>aFixnum</i>")
m0003.addFragment(Paragraph.new("Sets the effective group id for this process.\n"))
aClass.addMethod(m0003)
m0004 = MethodDesc.new("euid", "Process", "class", "Process.euid -> <i>aFixnum</i>")
m0004.addFragment(Paragraph.new("Returns the effective user id for this process.\n"))
m0004.addFragment(Verbatim.new("Process.euid   \#=> 501\n"))
aClass.addMethod(m0004)
m0005 = MethodDesc.new("euid=", "Process", "class", "Process.euid= <i>aFixnum</i>")
m0005.addFragment(Paragraph.new("Sets the effective user id for this process. Not available on all platforms.\n"))
aClass.addMethod(m0005)
m0006 = MethodDesc.new("exit!", "Process", "class", "Process.exit!( <i>aFixnum</i>=-1 )")
m0006.addFragment(Paragraph.new("Exits the process immediately. No exit handlers are run. <i>aFixnum</i> is returned to the underlying system as the exit status.\n"))
m0006.addFragment(Verbatim.new("Process.exit!(0)"))
aClass.addMethod(m0006)
m0007 = MethodDesc.new("fork", "Process", "class", "Process.fork <i>[</i>{ block } <i>]</i> -> <i>aFixnum</i> or <code>nil</code>")
m0007.addFragment(Paragraph.new("See <code>Kernel::fork</code> on page 420.\n"))
aClass.addMethod(m0007)
m0008 = MethodDesc.new("getpgid", "Process", "class", "Process.getpgid( <i>anInteger</i> ) -> <i>anInteger</i>")
m0008.addFragment(Paragraph.new("Returns the process group id for the given process id. Not available on all platforms.\n"))
m0008.addFragment(Verbatim.new("Process.getpgid(Process.ppid())   \#=> 13790\n"))
aClass.addMethod(m0008)
m0009 = MethodDesc.new("getpgrp", "Process", "class", "Process.getpgrp -> <i>anInteger</i>")
m0009.addFragment(Paragraph.new("Returns the process group id for this process. Not available on all platforms.\n"))
m0009.addFragment(Verbatim.new("Process.getpgid(0)   \#=> 13790\nProcess.getpgrp      \#=> 13790\n"))
aClass.addMethod(m0009)
m0010 = MethodDesc.new("getpriority", "Process", "class", "Process.getpriority( <i>aKind</i>, <i>anInteger</i> ) -> <i>aFixnum</i>")
m0010.addFragment(Paragraph.new("Gets the scheduling priority for specified process, process group, or user. <i>aKind</i> indicates the kind of entity to find: one of <code>Process::PRIO_PGRP</code>, <code>Process::PRIO_USER</code>, or <code>Process::PRIO_PROCESS</code>. <i>anInteger</i> is an id indicating the particular process, process group, or user (an id of 0 means <em>current</em>). Lower priorities are more favorable for scheduling. Not available on all platforms.\n"))
m0010.addFragment(Verbatim.new("Process.getpriority(Process::PRIO_USER, 0)      \#=> 0\nProcess.getpriority(Process::PRIO_PROCESS, 0)   \#=> 19\n"))
aClass.addMethod(m0010)
m0011 = MethodDesc.new("gid", "Process", "class", "Process.gid -> <i>aFixnum</i>")
m0011.addFragment(Paragraph.new("Returns the group id for this process.\n"))
m0011.addFragment(Verbatim.new("Process.gid   \#=> 500\n"))
aClass.addMethod(m0011)
m0012 = MethodDesc.new("gid=", "Process", "class", "Process.gid= <i>aFixnum</i> -> <i>aFixnum</i>")
m0012.addFragment(Paragraph.new("Sets the group id for this process.\n"))
aClass.addMethod(m0012)
m0013 = MethodDesc.new("kill", "Process", "class", "Process.kill( <i>aSignal</i>, <i>[</i><i>aPid</i><i>]+></i> ) -> <i>aFixnum</i>")
m0013.addFragment(Paragraph.new("Sends the given signal to the specified process id(s), or to the current process if <i>aPid</i> is zero. <i>aSignal</i> may be an integer signal number or a POSIX signal name (either with or without a <code>SIG</code> prefix). If <i>aSignal</i> is negative (or starts with a ``<code>-</code>'' sign), kills process groups instead of processes. Not all signals are available on all platforms.\n"))
m0013.addFragment(Verbatim.new("trap(\"SIGHUP\") { close_then_exit }\nProcess.kill(\"SIGHUP\", 0)"))
aClass.addMethod(m0013)
m0014 = MethodDesc.new("pid", "Process", "class", "Process.pid -> <i>aFixnum</i>")
m0014.addFragment(Paragraph.new("Returns the process id of this process. Not available on all platforms.\n"))
m0014.addFragment(Verbatim.new("Process.pid   \#=> 16488\n"))
aClass.addMethod(m0014)
m0015 = MethodDesc.new("ppid", "Process", "class", "Process.ppid -> <i>aFixnum</i>")
m0015.addFragment(Paragraph.new("Returns the process id of the parent of this process. Always returns 0 on NT. Not available on all platforms.\n"))
m0015.addFragment(Verbatim.new("print \"I am \", Process.pid, \"\\n\"\nProcess.fork { print \"Dad is \", Process.ppid, \"\\n\" }"))
m0015.addFragment(Paragraph.new("<em>produces:</em>\n"))
m0015.addFragment(Verbatim.new("I am 16490\nDad is 16490"))
aClass.addMethod(m0015)
m0016 = MethodDesc.new("setpgid", "Process", "class", "Process.setpgid( <i>aPid</i>, <i>anInteger</i> ) -> 0")
m0016.addFragment(Paragraph.new("Sets the process group id of <i>aPid</i> (0 indicates this process) to <i>anInteger</i>. Not available on all platforms.\n"))
aClass.addMethod(m0016)
m0017 = MethodDesc.new("setpgrp", "Process", "class", "Process.setpgrp -> 0")
m0017.addFragment(Paragraph.new("Equivalent to <code>setpgid(0,0)</code>. Not available on all platforms.\n"))
aClass.addMethod(m0017)
m0018 = MethodDesc.new("setpriority", "Process", "class", "Process.setpriority( <i>kind</i>, <i>anInteger</i>, <i>anIntPriority</i> ) -> 0")
m0018.addFragment(Paragraph.new("See <code>Process\#getpriority</code>.\n"))
m0018.addFragment(Verbatim.new("Process.setpriority(Process::PRIO_USER, 0, 19)      \#=> 0\nProcess.setpriority(Process::PRIO_PROCESS, 0, 19)   \#=> 0\nProcess.getpriority(Process::PRIO_USER, 0)          \#=> 19\nProcess.getpriority(Process::PRIO_PROCESS, 0)       \#=> 19\n"))
aClass.addMethod(m0018)
m0019 = MethodDesc.new("setsid", "Process", "class", "Process.setsid -> <i>aFixnum</i>")
m0019.addFragment(Paragraph.new("Establishes this process as a new session and process group leader, with no controlling tty. Returns the session id. Not available on all platforms.\n"))
m0019.addFragment(Verbatim.new("Process.setsid   \#=> 16495\n"))
aClass.addMethod(m0019)
m0020 = MethodDesc.new("uid", "Process", "class", "Process.uid -> <i>aFixnum</i>")
m0020.addFragment(Paragraph.new("Returns the user id of this process.\n"))
m0020.addFragment(Verbatim.new("Process.uid   \#=> 501\n"))
aClass.addMethod(m0020)
m0021 = MethodDesc.new("uid=", "Process", "class", "Process.uid= <i>anInteger</i> -> <i>aNumeric</i>")
m0021.addFragment(Paragraph.new("Sets the (integer) user id for this process. Not available on all platforms.\n"))
aClass.addMethod(m0021)
m0022 = MethodDesc.new("wait", "Process", "class", "Process.wait -> <i>aFixnum</i>")
m0022.addFragment(Paragraph.new("Waits for any child process to exit and returns the process id of that child. Raises a <code>SystemError</code> if there are no child processes. Not available on all platforms.\n"))
m0022.addFragment(Verbatim.new("Process.fork { exit 1; }   \#=> 16500\nProcess.wait               \#=> 16500\n"))
aClass.addMethod(m0022)
m0023 = MethodDesc.new("wait2", "Process", "class", "Process.wait2 -> <i>anArray</i>")
m0023.addFragment(Paragraph.new("Waits for any child process to exit and returns an array containing the process id and the exit status of that child. Raises a <code>SystemError</code> if there are no child processes.\n"))
m0023.addFragment(Verbatim.new("Process.fork { exit 1 }   \#=> 16503\nProcess.wait2             \#=> [16503, 256]\n"))
aClass.addMethod(m0023)
m0024 = MethodDesc.new("waitpid", "Process", "class", "Process.waitpid( <i>aPid</i>, <i>anInteger</i>=0 ) -> <i>aPid</i>")
m0024.addFragment(Paragraph.new("Waits for the given child process to exit. <i>anInteger</i> may be a logical or of the flag value <code>Process::WNOHANG</code> (do not block if no child available) or <code>Process::WUNTRACED</code> (return stopped children that haven't been reported). Not all flags are available on all platforms, but a flag value of zero will work on all platforms.\n"))
m0024.addFragment(Verbatim.new("include Process\npid = fork { sleep 3 }           \#=> 16506\nTime.now                         \#=> Sun Mar 04 23:31:14 CST 2001\nwaitpid(pid, Process::WNOHANG)   \#=> nil\nTime.now                         \#=> Sun Mar 04 23:31:14 CST 2001\nwaitpid(pid, 0)                  \#=> 16506\nTime.now                         \#=> Sun Mar 04 23:31:17 CST 2001\n"))
aClass.addMethod(m0024)
m0025 = MethodDesc.new("waitpid2", "Process", "class", "Process.waitpid2( <i>aPid</i>, <i>anInteger</i>=0 ) -> <i>anArray</i>")
m0025.addFragment(Paragraph.new("Waits for the given child process to exit, returning that child's process id and exit status. <i>anInteger</i> may be a logical or of the flag value <code>Process::WNOHANG</code> (do not block if no child available) or <code>Process::WUNTRACED</code> (return stopped children that haven't been reported). Not all flags are available on all platforms, but a flag value of zero will work on all platforms.\n"))
aClass.addMethod(m0025)

File.open($opfile, "w") {|f| Marshal.dump(aClass, f) }
