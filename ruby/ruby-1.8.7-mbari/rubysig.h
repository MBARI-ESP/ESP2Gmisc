/**********************************************************************

  rubysig.h -

  $Author$
  $Date$
  created at: Wed Aug 16 01:15:38 JST 1995

  Copyright (C) 1993-2003 Yukihiro Matsumoto

**********************************************************************/

#ifndef SIG_H
#define SIG_H

#include <errno.h>

/* STACK_WIPE_SITES determines where attempts are made to exorcise
   "ghost object refereces" from the stack.
   
   0x001  -->  wipe stack just after every thread_switch
   0x002  -->  wipe stack just after every EXEC_TAG()
   0x004  -->  wipe stack in CHECK_INTS
   0x010  -->  wipe stack in while & until loops
   0x020  -->  wipe stack before yield() in iterators and outside eval.c
   0x040  -->  wipe stack on catch and thread save context
   0x100  -->  update stack extent on each object allocation
   0x200  -->  update stack extent on each object reallocation
   0x400  -->  update stack extent during GC marking passes
   0x800  -->  update stack extent on each throw (use with 0x040)
   
   for most effective gc use 0x0707
   for fastest micro-benchmarking use 0x0000
   0x370 prevents most memory leaks caused by ghost references
   other good trade offs are 0x0703, 0x0303 or even 0x003
   
   Note that it is redundant to wipe_stack in looping constructs if 
   also doing so in CHECK_INTS.  It is also redundant to wipe_stack on
   each thread_switch if wiping after every thread save context.
*/
#ifndef STACK_WIPE_SITES
#define STACK_WIPE_SITES  0x370
#endif

#if (STACK_WIPE_SITES & 0x14) == 0x14
#warning  wiping stack in CHECK_INTS makes wiping in loops redundant
#endif
#if (STACK_WIPE_SITES & 0x41) == 0x41
#warning  wiping stack after thread save makes wiping on thread_switch redundant
#endif


#ifdef _WIN32
typedef LONG rb_atomic_t;

# define ATOMIC_TEST(var) InterlockedExchange(&(var), 0)
# define ATOMIC_SET(var, val) InterlockedExchange(&(var), (val))
# define ATOMIC_INC(var) InterlockedIncrement(&(var))
# define ATOMIC_DEC(var) InterlockedDecrement(&(var))

/* Windows doesn't allow interrupt while system calls */
# define TRAP_BEG do {\
    int saved_errno = 0;\
    rb_atomic_t trap_immediate = ATOMIC_SET(rb_trap_immediate, 1)
# define TRAP_END\
    ATOMIC_SET(rb_trap_immediate, trap_immediate);\
    saved_errno = errno;\
    CHECK_INTS;\
    errno = saved_errno;\
} while (0)
# define RUBY_CRITICAL(statements) do {\
    rb_w32_enter_critical();\
    statements;\
    rb_w32_leave_critical();\
} while (0)
#else
typedef int rb_atomic_t;

# define ATOMIC_TEST(var) ((var) ? ((var) = 0, 1) : 0)
# define ATOMIC_SET(var, val) ((var) = (val))
# define ATOMIC_INC(var) (++(var))
# define ATOMIC_DEC(var) (--(var))

# define TRAP_BEG do {\
    int saved_errno = 0;\
    int trap_immediate = rb_trap_immediate;\
    rb_trap_immediate = 1
# define TRAP_END rb_trap_immediate = trap_immediate;\
    saved_errno = errno;\
    CHECK_INTS;\
    errno = saved_errno;\
} while (0)

# define RUBY_CRITICAL(statements) do {\
    int trap_immediate = rb_trap_immediate;\
    rb_trap_immediate = 0;\
    statements;\
    rb_trap_immediate = trap_immediate;\
} while (0)
#endif
RUBY_EXTERN rb_atomic_t rb_trap_immediate;

RUBY_EXTERN int rb_prohibit_interrupt;
#define DEFER_INTS (rb_prohibit_interrupt++)
#define ALLOW_INTS do {\
    rb_prohibit_interrupt--;\
    CHECK_INTS;\
} while (0)
#define ENABLE_INTS (rb_prohibit_interrupt--)

VALUE rb_with_disable_interrupt _((VALUE(*)(ANYARGS),VALUE));

RUBY_EXTERN rb_atomic_t rb_trap_pending;
void rb_trap_restore_mask _((void));

RUBY_EXTERN int rb_thread_critical;
void rb_thread_schedule _((void));

RUBY_EXTERN VALUE *rb_gc_stack_end;
RUBY_EXTERN int rb_gc_stack_grow_direction;  /* -1 for down or 1 for up */
#define __stack_zero_up(end,sp)  while (end >= ++sp) *sp=0
#define __stack_past_up(end)  ((end) < (VALUE *)alloca(0))
#define __stack_grow_up(top,depth) ((top)+(depth))
#define __stack_zero_down(end,sp)  while (end <= --sp) *sp=0
#define __stack_past_down(end)  ((end) > (VALUE *)alloca(0))
#define __stack_grow_down(top,depth) ((top)-(depth))

#if STACK_GROW_DIRECTION > 0
#define __stack_zero(end,sp)  __stack_zero_up(end,sp)
#define __stack_past(end)  __stack_past_up(end)
#define __stack_grow(top,depth)  __stack_grow_up(top,depth)
#elif STACK_GROW_DIRECTION < 0
#define __stack_zero(end,sp)  __stack_zero_down(end,sp)
#define __stack_past(end)  __stack_past_down(end)
#define __stack_grow(top,depth)  __stack_grow_down(top,depth)
#else  /* limp along if stack direction can't be determined at compile time */
#define __stack_zero(end,sp) if (rb_gc_stack_grow_direction<0) \
        __stack_zero_down(end,sp); else __stack_zero_up(end,sp);
#define __stack_past(end)  (rb_gc_stack_grow_direction<0 ? \
                            __stack_past_down(end) : __stack_past_up(end))
#define __stack_grow(top,depth) (rb_gc_stack_grow_direction<0 ? \
                       __stack_grow_down(top,depth) : __stack_grow_up(top,depth)
#endif
 
/*
  Zero the memory that was (recently) part of the stack, but is no longer.
  Invoke when stack is deep to mark its extent and when it's shallow to wipe it.
*/
#define rb_gc_wipe_stack() {     \
  VALUE *end = rb_gc_stack_end;  \
  VALUE *sp = alloca(0);         \
  rb_gc_stack_end = sp;          \
  __stack_zero(end, sp);   \
}


/*
  Update our record of maximum stack extent without zeroing unused stack
*/
#define rb_gc_update_stack_extent() \
    if __stack_past(rb_gc_stack_end) rb_gc_stack_end = alloca(0);


#if STACK_WIPE_SITES & 4
# define CHECK_INTS_wipe_stack()  rb_gc_wipe_stack()
#else
# define CHECK_INTS_wipe_stack()  (void)0
#endif

#if defined(HAVE_SETITIMER) || defined(_THREAD_SAFE)
RUBY_EXTERN int rb_thread_pending;
# define CHECK_INTS do {\
    CHECK_INTS_wipe_stack(); \
    if (!(rb_prohibit_interrupt || rb_thread_critical)) {\
        if (rb_thread_pending) rb_thread_schedule();\
	if (rb_trap_pending) rb_trap_exec();\
    }\
} while (0)
#else
/* pseudo preemptive thread switching */
RUBY_EXTERN int rb_thread_tick;
#define THREAD_TICK 500
#define CHECK_INTS do {\
    CHECK_INTS_wipe_stack(); \
    if (!(rb_prohibit_interrupt || rb_thread_critical)) {\
	if (rb_thread_tick-- <= 0) {\
	    rb_thread_tick = THREAD_TICK;\
            rb_thread_schedule();\
	}\
        if (rb_trap_pending) rb_trap_exec();\
    }\
} while (0)
#endif

#endif
