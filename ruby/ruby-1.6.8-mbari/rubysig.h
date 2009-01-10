/**********************************************************************

  rubysig.h -

  $Author$
  $Date$
  created at: Wed Aug 16 01:15:38 JST 1995

  Copyright (C) 1993-2000 Yukihiro Matsumoto

**********************************************************************/

#ifndef SIG_H
#define SIG_H

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

#define THREAD_INTERRUPTABLE  (!(rb_prohibit_interrupt | rb_thread_critical))

EXTERN VALUE *rb_gc_stack_end;
#define __stack_zero_up(end,sp)  while (end >= ++sp) *sp=0
#define __stack_past_up(end)  ((end) < (VALUE *)alloca(0))
#define __stack_grow_up(top,depth) ((top)+(depth))
#define __stack_zero_down(end,sp)  while (end <= --sp) *sp=0
#define __stack_past_down(end)  ((end) > (VALUE *)alloca(0))
#define __stack_grow_down(top,depth) ((top)-(depth))

#define STACK_GROW_DIRECTION STACK_DIRECTION
#if STACK_GROW_DIRECTION > 0
#define __stack_zero(end,sp)  __stack_zero_up(end,sp)
#define __stack_past(end)  __stack_past_up(end)
#define __stack_grow(top,depth)  __stack_grow_up(top,depth)
#elif STACK_GROW_DIRECTION < 0
#define __stack_zero(end,sp)  __stack_zero_down(end,sp)
#define __stack_past(end)  __stack_past_down(end)
#define __stack_grow(top,depth)  __stack_grow_down(top,depth)
#else
#error STACK_GROW_DIRECTION must be predetermined.  Set it to -1 or 1
#endif

#ifdef __GNUC__   /* get the stack pointer most efficiently */
# ifdef __i386__  /* this improves runtimes by 1 to 2 % (really!) */
#  define _set_sp(ptr)  VALUE *ptr; asm("movl %%esp, %0": "=r"(ptr))
# elif __ppc__
#  define _set_sp(ptr)  VALUE *ptr; asm("addi %0, r1, 0": "=r"(ptr))
# elif __arm__
#  define _set_sp(ptr)  VALUE *ptr; asm("mov %0, sp": "=r"(ptr))
# else  /* slower, but should work everywhere gcc does */
#  define _set_sp(ptr)  VALUE *ptr = _get_tos();
 __attribute__ ((noinline)) 
static VALUE *_get_tos(void) {return __builtin_frame_address(0);}
# endif
#else  /* slowest, but should work everwhere */
#  define _set_sp(ptr)  VALUE *ptr = _get_tos();
static VALUE *_get_tos(void) {VALUE tos; return &tos;}
#endif

/*
  Zero the memory that was (recently) part of the stack, but is no longer.
  Invoke when stack is deep to mark its extent and when it's shallow to wipe it.
*/
#define rb_gc_wipe_stack() {     \
  VALUE *end = rb_gc_stack_end;  \
  _set_sp(sp);                   \
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

#if defined(HAVE_SETITIMER) && !defined(__BOW__)
EXTERN int rb_thread_pending;
# define CHECK_INTS \
    CHECK_INTS_wipe_stack(); \
    if THREAD_INTERRUPTABLE {\
    if (rb_thread_pending) rb_thread_schedule();\
    if (rb_trap_pending) rb_trap_exec();\
}
#else
/* pseudo preemptive thread switching */
EXTERN int rb_thread_tick;
# define THREAD_TICK 500
# define CHECK_INTS \
  CHECK_INTS_wipe_stack(); \
  if THREAD_INTERRUPTABLE {\
    if (rb_thread_tick-- <= 0) {\
	rb_thread_tick = THREAD_TICK;\
	rb_thread_schedule();\
    }\
    if (rb_trap_pending) rb_trap_exec();\
}
#endif

#endif
