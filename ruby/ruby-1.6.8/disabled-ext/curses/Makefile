SHELL = /bin/sh

#### Start of system configuration section. ####

srcdir = /home/brent/ruby/ruby-1.6.8/ext/curses

topdir = /home/brent/ruby/ruby-1.6.8
hdrdir = /home/brent/ruby/ruby-1.6.8

CC = arm-linux-gcc

CFLAGS   = -fPIC -O2 
CPPFLAGS = -I$(topdir) -I$(hdrdir) -DHAVE_NCURSES_H -DHAVE_ISENDWIN -DHAVE_UNGETCH -DHAVE_BEEP -DHAVE_DOUPDATE -DHAVE_FLASH -DHAVE_DELETELN -DHAVE_WDELETELN 
DLDFLAGS =  -L/home/brent/ruby/ruby-1.6.8 -L${prefix}/lib 
LDSHARED = arm-linux-gcc -shared 

RUBY_INSTALL_NAME = ruby
RUBY_SO_NAME = 

prefix = /usr/local
exec_prefix = ${prefix}
libdir = ${exec_prefix}/lib
#pkglibdir = $(libdir)/$(RUBY_INSTALL_NAME)/1.6
pkglibdir = $(libdir)/ruby/1.6
archdir = $(pkglibdir)/arm-linux
target_prefix = 


#### End of system configuration section. ####

LOCAL_LIBS =  
LIBS = $(LIBRUBY_A) -lncurses -lc
OBJS = curses.o
TARGET = curses
DLLIB = $(TARGET).so

RUBY = ruby -I/home/brent/ruby/ruby-1.6.8 -rfake -I$(topdir) -I$(hdrdir)/lib
RM = $(RUBY) -rftools -e "File::rm_f(*ARGV.map do|x|Dir[x]end.flatten.uniq)"

EXEEXT = 

all:		$(DLLIB)

clean:;		@$(RM) *.o *.so *.sl *.a $(DLLIB)
		@$(RM) *.ilk *.exp *.pdb *.bak $(CLEANFILES)

distclean:	clean
		@$(RM) Makefile extconf.h conftest.*
		@$(RM) core ruby$(EXEEXT) *~ $(DISTCLEANFILES)

realclean:	distclean

install:
	@$(RUBY) -r ftools -e 'File::makedirs(*ARGV)' $(DESTDIR)$(libdir) $(DESTDIR)$(pkglibdir) $(DESTDIR)$(archdir)$(target_prefix)

	@$(RUBY) -r ftools -e 'File::install(ARGV[0], ARGV[1], 0555, true)' $(DLLIB) $(DESTDIR)$(archdir)$(target_prefix)/$(DLLIB)


.cc.o:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $<
.cpp.o:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $<
.cxx.o:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $<
.C.o:
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $<

.c.o:
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $<
$(DLLIB): $(OBJS)
	$(LDSHARED) $(DLDFLAGS) -o $(DLLIB) $(OBJS) $(LIBS) $(LOCAL_LIBS)
###
curses.o: curses.c $(hdrdir)/ruby.h $(topdir)/config.h $(hdrdir)/defines.h
