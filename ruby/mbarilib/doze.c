/**********************************************************************

  mbari.c -

  $Author$
  $Date$
  created at: Tue Aug 10 14:30:50 JST 1993

  Copyright (C) 1993-2000 Yukihiro Matsumoto
  Copyright (C) 2000  Network Applied Communication Laboratory, Inc.
  Copyright (C) 2000  Information-technology Promotion Agency, Japan
  
  Revised:  9/1/04 brent@mbari.org
    this just adds the kernel.doze method that clears thread.critical
    atomically just before sleeping

**********************************************************************/

#include "ruby.h"
#include "rubysig.h"
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif
#ifndef NT
#ifdef HAVE_SYS_TIME_H
# include <sys/time.h>
#else
struct timeval {
        long    tv_sec;         /* seconds */
        long    tv_usec;        /* and microseconds */
};
#endif
#endif /* NT */
#include <ctype.h>

struct timeval rb_time_interval _((VALUE));

#ifdef HAVE_SYS_WAIT_H
# include <sys/wait.h>
#endif
#ifdef HAVE_GETPRIORITY
# include <sys/resource.h>
#endif
#include "st.h"

#ifdef __EMX__
#undef HAVE_GETPGRP
#endif


extern int rb_thread_critical;  /* Thread.critical from eval.c */

static VALUE
rb_doze(argc, argv)
    int argc;
    VALUE *argv;
{
    int beg, end;

    beg = time(0);
    rb_thread_critical = 0;  /* like Thread.stop, exit critical section */
    if (argc == 0) {
	rb_thread_sleep_forever();
    }
    else if (argc == 1) {
	rb_thread_wait_for(rb_time_interval(argv[0]));
    }
    else {
	rb_raise(rb_eArgError, "wrong # of arguments");
    }

    end = time(0) - beg;

    return INT2FIX(end);
}

void
Init_mbarilib()
{
    rb_define_global_function("doze", rb_doze, -1);
}

