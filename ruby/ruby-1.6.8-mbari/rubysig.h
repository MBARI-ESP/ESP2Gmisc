/**********************************************************************

  rubysig.h -

  $Author$
  $Date$
  created at: Wed Aug 16 01:15:38 JST 1995

  Copyright (C) 1993-2000 Yukihiro Matsumoto

**********************************************************************/

#ifndef SIG_H
#define SIG_H

#ifdef NT
typedef LONG rb_atomic_t;

# define ATOMIC_TEST(var) InterlockedExchange(&(var), 0)
# define ATOMIC_SET(var, val) InterlockedExchange(&(var), (val))
# define ATOMIC_INC(var) InterlockedIncrement(&(var))
# define ATOMIC_DEC(var) InterlockedDecrement(&(var))

/* Windows doesn't allow interrupt while system calls */
# define TRAP_BEG win32_enter_syscall()
# define TRAP_END win32_leave_syscall()
# define RUBY_CRITICAL(statements) do {\
    win32_disable_interrupt();\
    statements;\
    win32_enable_interrupt();\
} while (0)
#else
typedef int rb_atomic_t;

# define ATOMIC_TEST(var) ((var) ? ((var) = 0, 1) : 0)
# define ATOMIC_SET(var, val) ((var) = (val))
# define ATOMIC_INC(var) (++(var))
# define ATOMIC_DEC(var) (--(var))

# define TRAP_BEG do {\
    int trap_immediate = rb_trap_immediate;\
    rb_trap_immediate = 1;
# define TRAP_END rb_trap_immediate = trap_immediate;\
} while (0)

# define RUBY_CRITICAL(statements) do {\
    int trap_immediate = rb_trap_immediate;\
    rb_trap_immediate = 0;\
    statements;\
    rb_trap_immediate = trap_immediate;\
} while (0)
#endif
EXTERN rb_atomic_t rb_trap_immediate;

EXTERN int rb_prohibit_interrupt;
#define DEFER_INTS {rb_prohibit_interrupt++;}
#define ALLOW_INTS {rb_prohibit_interrupt--; CHECK_INTS;}
#define ENABLE_INTS {rb_prohibit_interrupt--;}

VALUE rb_with_disable_interrupt _((VALUE(*)(ANYARGS),VALUE));

EXTERN rb_atomic_t rb_trap_pending;
void rb_trap_restore_mask _((void));

EXTERN int rb_thread_critical;
void rb_thread_schedule _((void));

#if defined(HAVE_SETITIMER) && !defined(__BOW__)
EXTERN int rb_thread_pending;
#define THREAD_INTERRUPTABLE  (!(rb_prohibit_interrupt | rb_thread_critical))


EXTERN size_t rb_gc_malloc_increase;
EXTERN size_t rb_gc_malloc_limit;
EXTERN VALUE *rb_gc_stack_end;
/*
  zero the memory that was (recently) part of the stack
  but is no longer.  Invoke when stack is deep to mark its extent
  and when it is shallow to wipe it
*/
#define rb_gc_wipe_stack() {    \
  VALUE *sp = alloca(0);         \
  VALUE *end = rb_gc_stack_end;  \
  rb_gc_stack_end = sp;          \
  __stack_while(end, sp) *sp=0;   \
}

/*
  Update our record of maximum stack extent without zeroing unused stack
*/
#define rb_gc_update_stack_extent() \
    if __stack_grown rb_gc_stack_end = alloca(0);


#if STACK_DIRECTION > 0
#define __stack_while(end,sp)  while (end >= ++sp)
#define __stack_grown  (rb_gc_stack_end > (VALUE *)alloca(0))
#else
#define __stack_while(end,sp)  while (end <= --sp)
#define __stack_grown  (rb_gc_stack_end < (VALUE *)alloca(0))
#endif

# define CHECK_INTS if THREAD_INTERRUPTABLE {\
    rb_gc_wipe_stack(); \
    if (rb_gc_malloc_increase > rb_gc_malloc_limit) rb_gc(); \
    if (rb_thread_pending) rb_thread_schedule();\
    if (rb_trap_pending) rb_trap_exec();\
}
#else
/* pseudo preemptive thread switching */
EXTERN int rb_thread_tick;
#define THREAD_TICK 500
#define CHECK_INTS if THREAD_INTERRUPTABLE {\
    rb_gc_wipe_stack(); \
    if (rb_gc_malloc_increase > rb_gc_malloc_limit) rb_gc(); \
    if (rb_thread_tick-- <= 0) {\
	rb_thread_tick = THREAD_TICK;\
	rb_thread_schedule();\
    }\
    if (rb_trap_pending) rb_trap_exec();\
}
#endif

#endif
