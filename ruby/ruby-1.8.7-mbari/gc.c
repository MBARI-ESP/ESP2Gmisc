/**********************************************************************

  gc.c -

  $Author$
  $Date$
  created at: Tue Oct  5 09:44:46 JST 1993

  Copyright (C) 1993-2003 Yukihiro Matsumoto
  Copyright (C) 2000  Network Applied Communication Laboratory, Inc.
  Copyright (C) 2000  Information-technology Promotion Agency, Japan

**********************************************************************/

#include "ruby.h"
#include "rubysig.h"
#include "st.h"
#include "node.h"
#include "env.h"
#include "re.h"
#include <stdio.h>
#include <setjmp.h>
#include <sys/types.h>

#ifdef HAVE_SYS_RESOURCE_H
#include <sys/resource.h>
#endif

#if defined _WIN32 || defined __CYGWIN__
#include <windows.h>
#endif

void re_free_registers _((struct re_registers*));
void rb_io_fptr_finalize _((struct rb_io_t*));

#define rb_setjmp(env) RUBY_SETJMP(env)
#define rb_jmp_buf rb_jmpbuf_t
#ifdef __CYGWIN__
int _setjmp(), _longjmp();
#endif

#ifndef GC_MALLOC_LIMIT
#if defined(MSDOS) || defined(__human68k__)
#define GC_MALLOC_LIMIT 200000
#else
#define GC_MALLOC_LIMIT 8000000
#endif
#endif

#ifndef GC_LEVEL_MAX  /*maximum # of VALUEs on 'C' stack during GC*/
#define GC_LEVEL_MAX  8000
#endif
#ifndef GC_STACK_PAD
#define GC_STACK_PAD  200  /* extra padding VALUEs for GC stack */
#endif
#define GC_STACK_MAX  (GC_LEVEL_MAX+GC_STACK_PAD)

static VALUE *stack_limit, *gc_stack_limit;

static size_t malloc_increase = 0;
static size_t malloc_limit = GC_MALLOC_LIMIT;

/*
 *  call-seq:
 *     GC.limit    => increase limit in bytes
 *
 *  Get the # of bytes that may be allocated before triggering
 *  a mark and sweep by the garbarge collector to reclaim unused storage.
 *
 */
static VALUE gc_getlimit(VALUE mod)
{
  return ULONG2NUM(malloc_limit);
}

/*
 *  call-seq:
 *     GC.limit=   => updated increase limit in bytes
 *
 *  Set the # of bytes that may be allocated before triggering
 *  a mark and sweep by the garbarge collector to reclaim unused storage.
 *  Attempts to set the GC.limit= less than 0 will be ignored.
 *
 *     GC.limit=5000000   #=> 5000000
 *     GC.limit           #=> 5000000
 *     GC.limit=-50       #=> 5000000
 *     GC.limit=0         #=> 0
 *
 */
static VALUE gc_setlimit(VALUE mod, VALUE newLimit)
{
  long limit = NUM2LONG(newLimit);
  if (limit < 0) return gc_getlimit(mod);
  malloc_limit = limit;
  return newLimit;
}


/*
 *  call-seq:
 *     GC.increase
 *
 *  Get # of bytes that have been allocated since the last mark & sweep
 *
 */
static VALUE gc_increase(VALUE mod)
{
  return ULONG2NUM(malloc_increase);
}


/*
 *  call-seq:
 *     GC.exorcise
 *
 *  Purge ghost references from recently freed stack space
 *
 */
static VALUE gc_exorcise(VALUE mod)
{
  rb_gc_wipe_stack();
  return Qnil;
}


static void run_final();
static VALUE nomem_error;
static void garbage_collect();


NORETURN(void rb_exc_jump _((VALUE)));

void
rb_memerror()
{
    rb_thread_t th = rb_curr_thread;

    if (!nomem_error ||
	(rb_thread_raised_p(th, RAISED_NOMEMORY) && rb_safe_level() < 4)) {
	fprintf(stderr, "[FATAL] failed to allocate memory\n");
	exit(1);
    }
    if (rb_thread_raised_p(th, RAISED_NOMEMORY)) {
	rb_exc_jump(nomem_error);
    }
    rb_thread_raised_set(th, RAISED_NOMEMORY);
    rb_exc_raise(nomem_error);
}


void *
ruby_xmalloc(size)
    long size;
{
    void *mem;

    if (size < 0) {
	rb_raise(rb_eNoMemError, "negative allocation size (or too big)");
    }
    if (size == 0) size = 1;

    if ((malloc_increase+=size) > malloc_limit) {
	garbage_collect();
        malloc_increase = size;
    }
    RUBY_CRITICAL(mem = malloc(size));
    if (!mem) {
	garbage_collect();
	RUBY_CRITICAL(mem = malloc(size));
	if (!mem) {
	    rb_memerror();
	}
    }
#if STACK_WIPE_SITES & 0x100
    rb_gc_update_stack_extent();
#endif
    return mem;
}

void *
ruby_xcalloc(n, size)
    long n, size;
{
    void *mem;

    mem = xmalloc(n * size);
    memset(mem, 0, n * size);

    return mem;
}

void *
ruby_xrealloc(ptr, size)
    void *ptr;
    long size;
{
    void *mem;

    if (size < 0) {
	rb_raise(rb_eArgError, "negative re-allocation size");
    }
    if (!ptr) return xmalloc(size);
    if (size == 0) size = 1;
    if ((malloc_increase+=size) > malloc_limit) {
	garbage_collect();
        malloc_increase = size;
    }
    RUBY_CRITICAL(mem = realloc(ptr, size));
    if (!mem) {
	garbage_collect();
	RUBY_CRITICAL(mem = realloc(ptr, size));
	if (!mem) {
	    rb_memerror();
        }
    }
#if STACK_WIPE_SITES & 0x200
    rb_gc_update_stack_extent();
#endif
    return mem;
}

void
ruby_xfree(x)
    void *x;
{
    if (x)
	RUBY_CRITICAL(free(x));
}

extern int ruby_in_compile;
static int dont_gc;
static int during_gc;
static int need_call_final = 0;
static st_table *finalizer_table = 0;


/*
 *  call-seq:
 *     GC.enable    => true or false
 *
 *  Enables garbage collection, returning <code>true</code> if garbage
 *  collection was previously disabled.
 *
 *     GC.disable   #=> false
 *     GC.enable    #=> true
 *     GC.enable    #=> false
 *
 */

VALUE
rb_gc_enable()
{
    int old = dont_gc;

    dont_gc = Qfalse;
    return old;
}

/*
 *  call-seq:
 *     GC.disable    => true or false
 *
 *  Disables garbage collection, returning <code>true</code> if garbage
 *  collection was already disabled.
 *
 *     GC.disable   #=> false
 *     GC.disable   #=> true
 *
 */

VALUE
rb_gc_disable()
{
    int old = dont_gc;

    dont_gc = Qtrue;
    return old;
}

VALUE rb_mGC;

static struct gc_list {
    VALUE *varptr;
    struct gc_list *next;
} *global_List = 0;

void
rb_gc_register_address(addr)
    VALUE *addr;
{
    struct gc_list *tmp;

    tmp = ALLOC(struct gc_list);
    tmp->next = global_List;
    tmp->varptr = addr;
    global_List = tmp;
}

void
rb_gc_unregister_address(addr)
    VALUE *addr;
{
    struct gc_list *tmp = global_List;

    if (tmp->varptr == addr) {
	global_List = tmp->next;
	RUBY_CRITICAL(free(tmp));
	return;
    }
    while (tmp->next) {
	if (tmp->next->varptr == addr) {
	    struct gc_list *t = tmp->next;

	    tmp->next = tmp->next->next;
	    RUBY_CRITICAL(free(t));
	    break;
	}
	tmp = tmp->next;
    }
}

#undef GC_DEBUG

void
rb_global_variable(var)
    VALUE *var;
{
    rb_gc_register_address(var);
}

#if defined(_MSC_VER) || defined(__BORLANDC__) || defined(__CYGWIN__)
#pragma pack(push, 1) /* magic for reducing sizeof(RVALUE): 24 -> 20 */
#endif

typedef struct RVALUE {
    union {
	struct {
	    unsigned long flags;	/* always 0 for freed obj */
	    struct RVALUE *next;
	} free;
	struct RBasic  basic;
	struct RObject object;
	struct RClass  klass;
	struct RFloat  flonum;
	struct RString string;
	struct RArray  array;
	struct RRegexp regexp;
	struct RHash   hash;
	struct RData   data;
	struct RStruct rstruct;
	struct RBignum bignum;
	struct RFile   file;
	struct RNode   node;
	struct RMatch  match;
	struct RVarmap varmap;
	struct SCOPE   scope;
    } as;
#ifdef GC_DEBUG
    char *file;
    int   line;
#endif
} RVALUE;

#if defined(_MSC_VER) || defined(__BORLANDC__) || defined(__CYGWIN__)
#pragma pack(pop)
#endif

static RVALUE *freelist = 0;
static RVALUE *deferred_final_list = 0;

#define HEAPS_INCREMENT 10
static struct heaps_slot {
    void *membase;
    RVALUE *slot;
    int limit;
} *heaps;
static int heaps_length = 0;
static int heaps_used   = 0;

#define HEAP_MIN_SLOTS 10000
static int heap_slots = HEAP_MIN_SLOTS;

#define FREE_MIN  4096

static RVALUE *himem, *lomem;

static void
add_heap()
{
    RVALUE *p, *pend;

    if (heaps_used == heaps_length) {
	/* Realloc heaps */
	struct heaps_slot *p;
	int length;

	heaps_length += HEAPS_INCREMENT;
	length = heaps_length*sizeof(struct heaps_slot);
	RUBY_CRITICAL(
	    if (heaps_used > 0) {
		p = (struct heaps_slot *)realloc(heaps, length);
		if (p) heaps = p;
	    }
	    else {
		p = heaps = (struct heaps_slot *)malloc(length);
	    });
	if (p == 0) rb_memerror();
    }

    for (;;) {
	RUBY_CRITICAL(p = (RVALUE*)malloc(sizeof(RVALUE)*(heap_slots+1)));
	if (p == 0) {
	    if (heap_slots == HEAP_MIN_SLOTS) {
		rb_memerror();
	    }
	    heap_slots = HEAP_MIN_SLOTS;
	    continue;
	}
        heaps[heaps_used].membase = p;
        if ((VALUE)p % sizeof(RVALUE) == 0)
            heap_slots += 1;
        else
            p = (RVALUE*)((VALUE)p + sizeof(RVALUE) - ((VALUE)p % sizeof(RVALUE)));
        heaps[heaps_used].slot = p;
        heaps[heaps_used].limit = heap_slots;
	break;
    }
    pend = p + heap_slots;
    if (lomem == 0 || lomem > p) lomem = p;
    if (himem < pend) himem = pend;
    heaps_used++;
    heap_slots *= 1.8;
    if (heap_slots <= 0) heap_slots = HEAP_MIN_SLOTS;

    while (p < pend) {
	p->as.free.flags = 0;
	p->as.free.next = freelist;
	freelist = p;
	p++;
    }
}
#define RANY(o) ((RVALUE*)(o))

int 
rb_during_gc()
{
    return during_gc;
}

VALUE
rb_newobj()
{
    VALUE obj;

    if (during_gc)
	rb_bug("object allocation during garbage collection phase");

    if (!malloc_limit || !freelist) garbage_collect();

    obj = (VALUE)freelist;
    freelist = freelist->as.free.next;
    MEMZERO((void*)obj, RVALUE, 1);
#ifdef GC_DEBUG
    RANY(obj)->file = ruby_sourcefile;
    RANY(obj)->line = ruby_sourceline;
#endif
    return obj;
}

VALUE
rb_data_object_alloc(klass, datap, dmark, dfree)
    VALUE klass;
    void *datap;
    RUBY_DATA_FUNC dmark;
    RUBY_DATA_FUNC dfree;
{
    NEWOBJ(data, struct RData);
    if (klass) Check_Type(klass, T_CLASS);
    OBJSETUP(data, klass, T_DATA);
    data->data = datap;
    data->dfree = dfree;
    data->dmark = dmark;

    return (VALUE)data;
}

extern st_table *rb_class_tbl;
VALUE *rb_gc_stack_start = 0;
#ifdef __ia64
VALUE *rb_gc_register_stack_start = 0;
#endif

VALUE *rb_gc_stack_end = (VALUE *)STACK_GROW_DIRECTION;


#ifdef DJGPP
/* set stack size (http://www.delorie.com/djgpp/v2faq/faq15_9.html) */
unsigned int _stklen = 0x180000; /* 1.5 kB */
#endif

#if defined(DJGPP) || defined(_WIN32_WCE)
static unsigned int STACK_LEVEL_MAX = 65535;
#elif defined(__human68k__)
unsigned int _stacksize = 262144;
# define STACK_LEVEL_MAX (_stacksize - 4096)
# undef HAVE_GETRLIMIT
#elif defined(HAVE_GETRLIMIT) || defined(_WIN32)
static unsigned int STACK_LEVEL_MAX = 655300;
#else
# define STACK_LEVEL_MAX 655300
#endif

#ifndef nativeAllocA
  /* portable way to return an approximate stack pointer */
VALUE *__sp(void) {
  VALUE tos;
  return &tos;
}
# define SET_STACK_END VALUE stack_end
# define STACK_END (&stack_end)
#else
# define SET_STACK_END ((void)0)
# define STACK_END __sp()
#endif

#if STACK_GROW_DIRECTION < 0
# define STACK_LENGTH(start)  ((start) - STACK_END)
#elif STACK_GROW_DIRECTION > 0
# define STACK_LENGTH(start)  (STACK_END - (start) + 1)
#else
# define STACK_LENGTH(start)  ((STACK_END < (start)) ? \
                                 (start) - STACK_END : STACK_END - (start) + 1)
#endif

#if STACK_GROW_DIRECTION > 0
# define STACK_UPPER(a, b) a
#elif STACK_GROW_DIRECTION < 0
# define STACK_UPPER(a, b) b
#else
int rb_gc_stack_grow_direction;
static int
stack_grow_direction(addr)
    VALUE *addr;
{
    SET_STACK_END;
    return rb_gc_stack_grow_direction = STACK_END > addr ? 1 : -1;
}
# define STACK_UPPER(a, b) (rb_gc_stack_grow_direction > 0 ? a : b)
#endif

int
ruby_stack_length(start, base)
    VALUE *start, **base;
{
    SET_STACK_END;
    if (base) *base = STACK_UPPER(start, STACK_END);
    return STACK_LENGTH(start);
}

int
ruby_stack_check()
{
    SET_STACK_END;
    return __stack_past(stack_limit, STACK_END);
}

/*
  Zero memory that was (recently) part of the stack, but is no longer.
  Invoke when stack is deep to mark its extent and when it's shallow to wipe it.
*/
#if STACK_WIPE_METHOD != 4
#if STACK_WIPE_METHOD
void rb_gc_wipe_stack(void)
{
  VALUE *stack_end = rb_gc_stack_end;
  VALUE *sp = __sp();
  rb_gc_stack_end = sp;
#if STACK_WIPE_METHOD == 1
#warning clearing of "ghost references" from the call stack has been disabled
#elif STACK_WIPE_METHOD == 2  /* alloca ghost stack before clearing it */
  if (__stack_past(sp, stack_end)) {
    size_t bytes = __stack_depth((char *)stack_end, (char *)sp);
    STACK_UPPER(sp = nativeAllocA(bytes), stack_end = nativeAllocA(bytes));
    __stack_zero(stack_end, sp);
  }
#elif STACK_WIPE_METHOD == 3    /* clear unallocated area past stack pointer */
  __stack_zero(stack_end, sp);  /* will crash if compiler pushes a temp. here */
#else
#error unsupported method of clearing ghost references from the stack
#endif
}
#else
#warning clearing of "ghost references" from the call stack completely disabled
#endif
#endif

#define MARK_STACK_MAX 1024
static VALUE mark_stack[MARK_STACK_MAX];
static VALUE *mark_stack_ptr;
static int mark_stack_overflow;

static void
init_mark_stack()
{
    mark_stack_overflow = 0;
    mark_stack_ptr = mark_stack;
}

#define MARK_STACK_EMPTY (mark_stack_ptr == mark_stack)

static inline void
push_mark_stack(VALUE ptr)
{
    if (!mark_stack_overflow) {
	if (mark_stack_ptr - mark_stack < MARK_STACK_MAX)
	    *mark_stack_ptr++ = ptr;
	else
	    mark_stack_overflow = 1;
    }
}
    
static st_table *source_filenames;

char *
rb_source_filename(f)
    const char *f;
{
    st_data_t name;

    if (!st_lookup(source_filenames, (st_data_t)f, &name)) {
	long len = strlen(f) + 1;
	char *ptr = ALLOC_N(char, len + 1);
	name = (st_data_t)ptr;
	*ptr++ = 0;
	MEMCPY(ptr, f, char, len);
	st_add_direct(source_filenames, (st_data_t)ptr, name);
	return ptr;
    }
    return (char *)name + 1;
}

static void
mark_source_filename(f)
    char *f;
{
    if (f) {
	f[-1] = 1;
    }
}

static int
sweep_source_filename(key, value)
    char *key, *value;
{
    if (*value) {
	*value = 0;
	return ST_CONTINUE;
    }
    else {
	free(value);
	return ST_DELETE;
    }
}

#define gc_mark(ptr) rb_gc_mark(ptr)
static void gc_mark_children _((VALUE ptr));

static void
gc_mark_all()
{
    RVALUE *p, *pend;
    struct heaps_slot *heap = heaps+heaps_used;

    init_mark_stack();
    while (--heap >= heaps) {
	p = heap->slot; pend = p + heap->limit;
	while (p < pend) {
	    if ((p->as.basic.flags & FL_MARK) &&
		(p->as.basic.flags != FL_MARK)) {
		gc_mark_children((VALUE)p);
	    }
	    p++;
	}
    }
}

static void
gc_mark_rest()
{
    size_t stackLen = mark_stack_ptr - mark_stack;
#ifdef nativeAllocA
    VALUE *tmp_arry = nativeAllocA(stackLen*sizeof(VALUE));
#else
    VALUE tmp_arry[MARK_STACK_MAX];
#endif
    VALUE *p = tmp_arry + stackLen;
    
    MEMCPY(tmp_arry, mark_stack, VALUE, stackLen);

    init_mark_stack();
    while(--p >= tmp_arry) gc_mark_children(*p);
}

static inline int
is_pointer_to_heap(ptr)
    void *ptr;
{
    RVALUE *p = RANY(ptr);
    struct heaps_slot *heap;

    if (p < lomem || p > himem || (VALUE)p % sizeof(RVALUE)) return Qfalse;

    /* check if p looks like a pointer */
    heap = heaps+heaps_used;
    while (--heap >= heaps) 
      if (p >= heap->slot && p < heap->slot + heap->limit)
        return Qtrue;
    return Qfalse;
}

static void
mark_locations_array(x, n)
    VALUE *x;
    size_t n;
{
    VALUE v;
    while (n--) {
        v = *x;
	if (is_pointer_to_heap((void *)v)) {
	    gc_mark(v);
	}
	x++;
    }
}

void inline
rb_gc_mark_locations(start, end)
    VALUE *start, *end;
{
    mark_locations_array(start,end - start);
}

static int
mark_entry(key, value)
    ID key;
    VALUE value;
{
    gc_mark(value);
    return ST_CONTINUE;
}

void
rb_mark_tbl(tbl)
    st_table *tbl;
{
    if (!tbl) return;
    st_foreach(tbl, mark_entry, 0);
}
#define mark_tbl(tbl)  rb_mark_tbl(tbl)

static int
mark_keyvalue(key, value)
    VALUE key;
    VALUE value;
{
    gc_mark(key);
    gc_mark(value);
    return ST_CONTINUE;
}

void
rb_mark_hash(tbl)
    st_table *tbl;
{
    if (!tbl) return;
    st_foreach(tbl, mark_keyvalue, 0);
}
#define mark_hash(tbl)  rb_mark_hash(tbl)

void
rb_gc_mark_maybe(obj)
    VALUE obj;
{
    if (is_pointer_to_heap((void *)obj)) {
	gc_mark(obj);
    }
}

void
rb_gc_mark(ptr)
    VALUE ptr;
{
    RVALUE *obj = RANY(ptr);
    SET_STACK_END;
    
    if (rb_special_const_p(ptr)) return; /* special const not marked */
    if (obj->as.basic.flags == 0) return;       /* free cell */
    if (obj->as.basic.flags & FL_MARK) return;  /* already marked */
    obj->as.basic.flags |= FL_MARK;

    if (__stack_past(gc_stack_limit, STACK_END))
      push_mark_stack(ptr);
    else{
      gc_mark_children(ptr);
    }
}

static void
gc_mark_children(ptr)
    VALUE ptr;
{
    RVALUE *obj = RANY(ptr);

    goto marking;		/* skip */

  again:
    obj = RANY(ptr);
    if (rb_special_const_p(ptr)) return; /* special const not marked */
    if (obj->as.basic.flags == 0) return;       /* free cell */
    if (obj->as.basic.flags & FL_MARK) return;  /* already marked */
    obj->as.basic.flags |= FL_MARK;

  marking:
    if (FL_TEST(obj, FL_EXIVAR)) {
	rb_mark_generic_ivar(ptr);
    }

    switch (obj->as.basic.flags & T_MASK) {
      case T_NIL:
      case T_FIXNUM:
	rb_bug("rb_gc_mark() called for broken object");
	break;

      case T_NODE:
	mark_source_filename(obj->as.node.nd_file);
	switch (nd_type(obj)) {
	  case NODE_IF:		/* 1,2,3 */
	  case NODE_FOR:
	  case NODE_ITER:
	  case NODE_CREF:
	  case NODE_WHEN:
	  case NODE_MASGN:
	  case NODE_RESCUE:
	  case NODE_RESBODY:
	  case NODE_CLASS:
	    gc_mark((VALUE)obj->as.node.u2.node);
	    /* fall through */
	  case NODE_BLOCK:	/* 1,3 */
	  case NODE_ARRAY:
	  case NODE_DSTR:
	  case NODE_DXSTR:
	  case NODE_DREGX:
	  case NODE_DREGX_ONCE:
	  case NODE_FBODY:
	  case NODE_ENSURE:
	  case NODE_CALL:
	  case NODE_DEFS:
	  case NODE_OP_ASGN1:
	    gc_mark((VALUE)obj->as.node.u1.node);
	    /* fall through */
	  case NODE_SUPER:	/* 3 */
	  case NODE_FCALL:
	  case NODE_DEFN:
	  case NODE_NEWLINE:
	    ptr = (VALUE)obj->as.node.u3.node;
	    goto again;

	  case NODE_WHILE:	/* 1,2 */
	  case NODE_UNTIL:
	  case NODE_AND:
	  case NODE_OR:
	  case NODE_CASE:
	  case NODE_SCLASS:
	  case NODE_DOT2:
	  case NODE_DOT3:
	  case NODE_FLIP2:
	  case NODE_FLIP3:
	  case NODE_MATCH2:
	  case NODE_MATCH3:
	  case NODE_OP_ASGN_OR:
	  case NODE_OP_ASGN_AND:
	  case NODE_MODULE:
	  case NODE_ALIAS:
	  case NODE_VALIAS:
	  case NODE_ARGS:
	    gc_mark((VALUE)obj->as.node.u1.node);
	    /* fall through */
	  case NODE_METHOD:	/* 2 */
	  case NODE_NOT:
	  case NODE_GASGN:
	  case NODE_LASGN:
	  case NODE_DASGN:
	  case NODE_DASGN_CURR:
	  case NODE_IASGN:
	  case NODE_CVDECL:
	  case NODE_CVASGN:
	  case NODE_COLON3:
	  case NODE_OPT_N:
	  case NODE_EVSTR:
	  case NODE_UNDEF:
	    ptr = (VALUE)obj->as.node.u2.node;
	    goto again;

	  case NODE_HASH:	/* 1 */
	  case NODE_LIT:
	  case NODE_STR:
	  case NODE_XSTR:
	  case NODE_DEFINED:
	  case NODE_MATCH:
	  case NODE_RETURN:
	  case NODE_BREAK:
	  case NODE_NEXT:
	  case NODE_YIELD:
	  case NODE_COLON2:
	  case NODE_SPLAT:
	  case NODE_TO_ARY:
	  case NODE_SVALUE:
	    ptr = (VALUE)obj->as.node.u1.node;
	    goto again;

	  case NODE_SCOPE:	/* 2,3 */
	  case NODE_BLOCK_PASS:
	  case NODE_CDECL:
	    gc_mark((VALUE)obj->as.node.u3.node);
	    ptr = (VALUE)obj->as.node.u2.node;
	    goto again;

	  case NODE_ZARRAY:	/* - */
	  case NODE_ZSUPER:
	  case NODE_CFUNC:
	  case NODE_VCALL:
	  case NODE_GVAR:
	  case NODE_LVAR:
	  case NODE_DVAR:
	  case NODE_IVAR:
	  case NODE_CVAR:
	  case NODE_NTH_REF:
	  case NODE_BACK_REF:
	  case NODE_REDO:
	  case NODE_RETRY:
	  case NODE_SELF:
	  case NODE_NIL:
	  case NODE_TRUE:
	  case NODE_FALSE:
	  case NODE_ATTRSET:
	  case NODE_BLOCK_ARG:
	  case NODE_POSTEXE:
	    break;
	  case NODE_ALLOCA:
	    mark_locations_array((VALUE*)obj->as.node.u1.value,
				 obj->as.node.u3.cnt);
	    ptr = (VALUE)obj->as.node.u2.node;
	    goto again;

	  default:		/* unlisted NODE */
	    if (is_pointer_to_heap(obj->as.node.u1.node)) {
		gc_mark((VALUE)obj->as.node.u1.node);
	    }
	    if (is_pointer_to_heap(obj->as.node.u2.node)) {
		gc_mark((VALUE)obj->as.node.u2.node);
	    }
	    if (is_pointer_to_heap(obj->as.node.u3.node)) {
                ptr = (VALUE)obj->as.node.u3.node;
                goto again;
	    }
	}
        return;	/* no need to mark class. */
    }

    gc_mark(obj->as.basic.klass);
    switch (obj->as.basic.flags & T_MASK) {
      case T_ICLASS:
      case T_CLASS:
      case T_MODULE:
	mark_tbl(obj->as.klass.m_tbl);
	mark_tbl(obj->as.klass.iv_tbl);
	ptr = obj->as.klass.super;
	goto again;

      case T_ARRAY:
	if (FL_TEST(obj, ELTS_SHARED)) {
	    ptr = obj->as.array.aux.shared;
	    goto again;
	}
	else {
	    VALUE *ptr = obj->as.array.ptr;
            VALUE *pend = ptr + obj->as.array.len;
	    while (ptr < pend) {
		gc_mark(*ptr++);
	    }
	}
	break;

      case T_HASH:
	mark_hash(obj->as.hash.tbl);
	ptr = obj->as.hash.ifnone;
	goto again;

      case T_STRING:
#define STR_ASSOC FL_USER3   /* copied from string.c */
	if (FL_TEST(obj, ELTS_SHARED|STR_ASSOC)) {
	    ptr = obj->as.string.aux.shared;
	    goto again;
	}
	break;

      case T_DATA:
	if (obj->as.data.dmark) (*obj->as.data.dmark)(DATA_PTR(obj));
	break;

      case T_OBJECT:
	mark_tbl(obj->as.object.iv_tbl);
	break;

      case T_FILE:
      case T_REGEXP:
      case T_FLOAT:
      case T_BIGNUM:
      case T_BLKTAG:
	break;

      case T_MATCH:
	if (obj->as.match.str) {
	    ptr = obj->as.match.str;
	    goto again;
	}
	break;

      case T_VARMAP:
	gc_mark(obj->as.varmap.val);
	ptr = (VALUE)obj->as.varmap.next;
	goto again;

      case T_SCOPE:
	if (obj->as.scope.local_vars && (obj->as.scope.flags & SCOPE_MALLOC)) {
	    int n = obj->as.scope.local_tbl[0]+1;
	    VALUE *vars = &obj->as.scope.local_vars[-1];

	    while (n--) {
		gc_mark(*vars++);
	    }
	}
	break;

      case T_STRUCT:
	{
	    VALUE *ptr = obj->as.rstruct.ptr;
            VALUE *pend = ptr + obj->as.rstruct.len;
            while (ptr < pend)
	       gc_mark(*ptr++);
	}
	break;

      default:
	rb_bug("rb_gc_mark(): unknown data type 0x%lx(0x%lx) %s",
	       obj->as.basic.flags & T_MASK, obj,
	       is_pointer_to_heap(obj) ? "corrupted object" : "non object");
    }
}

static void obj_free _((VALUE));

static void
finalize_list(p)
    RVALUE *p;
{
    while (p) {
	RVALUE *tmp = p->as.free.next;
	run_final((VALUE)p);
	if (!FL_TEST(p, FL_SINGLETON)) { /* not freeing page */
	    p->as.free.flags = 0;
	    p->as.free.next = freelist;
	    freelist = p;
	}
	p = tmp;
    }
}

static void
free_unused_heaps()
{
    int i, j;

    for (i = j = 1; j < heaps_used; i++) {
	if (heaps[i].limit == 0) {
	    free(heaps[i].membase);
	    heaps_used--;
	}
	else {
	    if (i != j) {
		heaps[j] = heaps[i];
	    }
	    j++;
	}
    }
}

void rb_gc_abort_threads(void);

static void
gc_sweep()
{
    RVALUE *p, *pend, *final_list;
    int freed = 0;
    int i;
    unsigned long free_min = 0;

    for (i = 0; i < heaps_used; i++) {
        free_min += heaps[i].limit;
    }
    free_min /= 5;
    if (free_min < FREE_MIN)
        free_min = FREE_MIN;

    if (ruby_in_compile && ruby_parser_stack_on_heap()) {
	/* should not reclaim nodes during compilation
           if yacc's semantic stack is not allocated on machine stack */
	for (i = 0; i < heaps_used; i++) {
	    p = heaps[i].slot; pend = p + heaps[i].limit;
	    while (p < pend) {
		if (!(p->as.basic.flags&FL_MARK) && BUILTIN_TYPE(p) == T_NODE)
		    gc_mark((VALUE)p);
		p++;
	    }
	}
    }

    mark_source_filename(ruby_sourcefile);
    if (source_filenames) {
        st_foreach(source_filenames, sweep_source_filename, 0);
    }

    freelist = 0;
    final_list = deferred_final_list;
    deferred_final_list = 0;
    for (i = 0; i < heaps_used; i++) {
	int n = 0;
	RVALUE *free = freelist;
	RVALUE *final = final_list;

	p = heaps[i].slot; pend = p + heaps[i].limit;
	while (p < pend) {
	    if (!(p->as.basic.flags & FL_MARK)) {
		if (p->as.basic.flags) {
		    obj_free((VALUE)p);
		}
		if (need_call_final && FL_TEST(p, FL_FINALIZE)) {
		    p->as.free.flags = FL_MARK; /* remain marked */
		    p->as.free.next = final_list;
		    final_list = p;
		}
		else {
		    p->as.free.flags = 0;
		    p->as.free.next = freelist;
		    freelist = p;
		}
		n++;
	    }
	    else if (RBASIC(p)->flags == FL_MARK) {
		/* objects to be finalized */
		/* do nothing remain marked */
	    }
	    else {
		RBASIC(p)->flags &= ~FL_MARK;
	    }
	    p++;
	}
	if (n == heaps[i].limit && freed > free_min) {
	    RVALUE *pp;

	    heaps[i].limit = 0;
	    for (pp = final_list; pp != final; pp = pp->as.free.next) {
		pp->as.free.flags |= FL_SINGLETON; /* freeing page mark */
	    }
	    freelist = free;	/* cancel this page from freelist */
	}
	else {
	    freed += n;
	}
    }
    malloc_increase = 0;
    if (freed < free_min) {
	add_heap();
    }
    during_gc = 0;

    /* clear finalization list */
    if (final_list) {
	deferred_final_list = final_list;
	return;
    }
    free_unused_heaps();
}

void
rb_gc_force_recycle(p)
    VALUE p;
{
    RANY(p)->as.free.flags = 0;
    RANY(p)->as.free.next = freelist;
    freelist = RANY(p);
}

static void
obj_free(obj)
    VALUE obj;
{
    switch (RANY(obj)->as.basic.flags & T_MASK) {
      case T_NIL:
      case T_FIXNUM:
      case T_TRUE:
      case T_FALSE:
	rb_bug("obj_free() called for broken object");
	break;
    }

    if (FL_TEST(obj, FL_EXIVAR)) {
	rb_free_generic_ivar((VALUE)obj);
    }

    switch (RANY(obj)->as.basic.flags & T_MASK) {
      case T_OBJECT:
	if (RANY(obj)->as.object.iv_tbl) {
	    st_free_table(RANY(obj)->as.object.iv_tbl);
	}
	break;
      case T_MODULE:
      case T_CLASS:
	rb_clear_cache_by_class((VALUE)obj);
	st_free_table(RANY(obj)->as.klass.m_tbl);
	if (RANY(obj)->as.object.iv_tbl) {
	    st_free_table(RANY(obj)->as.object.iv_tbl);
	}
	break;
      case T_STRING:
	if (RANY(obj)->as.string.ptr && !FL_TEST(obj, ELTS_SHARED)) {
	    RUBY_CRITICAL(free(RANY(obj)->as.string.ptr));
	}
	break;
      case T_ARRAY:
	if (RANY(obj)->as.array.ptr && !FL_TEST(obj, ELTS_SHARED)) {
	    RUBY_CRITICAL(free(RANY(obj)->as.array.ptr));
	}
	break;
      case T_HASH:
	if (RANY(obj)->as.hash.tbl) {
	    st_free_table(RANY(obj)->as.hash.tbl);
	}
	break;
      case T_REGEXP:
	if (RANY(obj)->as.regexp.ptr) {
	    re_free_pattern(RANY(obj)->as.regexp.ptr);
	}
	if (RANY(obj)->as.regexp.str) {
	    RUBY_CRITICAL(free(RANY(obj)->as.regexp.str));
	}
	break;
      case T_DATA:
	if (DATA_PTR(obj)) {
	    if ((long)RANY(obj)->as.data.dfree == -1) {
		RUBY_CRITICAL(free(DATA_PTR(obj)));
	    }
	    else if (RANY(obj)->as.data.dfree) {
		(*RANY(obj)->as.data.dfree)(DATA_PTR(obj));
	    }
	}
	break;
      case T_MATCH:
	if (RANY(obj)->as.match.regs) {
	    re_free_registers(RANY(obj)->as.match.regs);
	    RUBY_CRITICAL(free(RANY(obj)->as.match.regs));
	}
	break;
      case T_FILE:
	if (RANY(obj)->as.file.fptr) {
	    rb_io_fptr_finalize(RANY(obj)->as.file.fptr);
	    RUBY_CRITICAL(free(RANY(obj)->as.file.fptr));
	}
	break;
      case T_ICLASS:
	/* iClass shares table with the module */
	break;

      case T_FLOAT:
      case T_VARMAP:
      case T_BLKTAG:
	break;

      case T_BIGNUM:
	if (RANY(obj)->as.bignum.digits) {
	    RUBY_CRITICAL(free(RANY(obj)->as.bignum.digits));
	}
	break;
      case T_NODE:
	switch (nd_type(obj)) {
	  case NODE_SCOPE:
	    if (RANY(obj)->as.node.u1.tbl) {
		RUBY_CRITICAL(free(RANY(obj)->as.node.u1.tbl));
	    }
	    break;
	  case NODE_ALLOCA:
	    RUBY_CRITICAL(free(RANY(obj)->as.node.u1.node));
	    break;
	}
	return;			/* no need to free iv_tbl */

      case T_SCOPE:
	if (RANY(obj)->as.scope.local_vars &&
            RANY(obj)->as.scope.flags != SCOPE_ALLOCA) {
	    VALUE *vars = RANY(obj)->as.scope.local_vars-1;
	    if (!(RANY(obj)->as.scope.flags & SCOPE_CLONE) && vars[0] == 0)
		RUBY_CRITICAL(free(RANY(obj)->as.scope.local_tbl));
	    if (RANY(obj)->as.scope.flags & SCOPE_MALLOC)
		RUBY_CRITICAL(free(vars));
	}
	break;

      case T_STRUCT:
	if (RANY(obj)->as.rstruct.ptr) {
	    RUBY_CRITICAL(free(RANY(obj)->as.rstruct.ptr));
	}
	break;

      default:
	rb_bug("gc_sweep(): unknown data type 0x%lx(0x%lx)",
	       RANY(obj)->as.basic.flags & T_MASK, obj);
    }
}

void
rb_gc_mark_frame(frame)
    struct FRAME *frame;
{
    gc_mark((VALUE)frame->node);
}

#ifdef __GNUC__
#if defined(__human68k__) || defined(DJGPP)
#undef rb_setjmp
#undef rb_jmp_buf
#if defined(__human68k__)
typedef unsigned long rb_jmp_buf[8];
__asm__ (".even\n\
_rb_setjmp:\n\
	move.l	4(sp),a0\n\
	movem.l	d3-d7/a3-a5,(a0)\n\
	moveq.l	#0,d0\n\
	rts");
#else
#if defined(DJGPP)
typedef unsigned long rb_jmp_buf[6];
__asm__ (".align 4\n\
_rb_setjmp:\n\
	pushl	%ebp\n\
	movl	%esp,%ebp\n\
	movl	8(%ebp),%ebp\n\
	movl	%eax,(%ebp)\n\
	movl	%ebx,4(%ebp)\n\
	movl	%ecx,8(%ebp)\n\
	movl	%edx,12(%ebp)\n\
	movl	%esi,16(%ebp)\n\
	movl	%edi,20(%ebp)\n\
	popl	%ebp\n\
	xorl	%eax,%eax\n\
	ret");
#endif
#endif
int rb_setjmp (rb_jmp_buf);
#endif /* __human68k__ or DJGPP */
#endif /* __GNUC__ */



static void
garbage_collect_0(VALUE *top_frame)
{
    struct gc_list *list;
    struct FRAME * frame;
    jmp_buf save_regs_gc_mark;
    SET_STACK_END;

#ifdef HAVE_NATIVETHREAD
    if (!is_ruby_native_thread()) {
	rb_bug("cross-thread violation on rb_gc()");
    }
#endif
    if (dont_gc || during_gc) {
	if (!freelist) {
	    add_heap();
	}
	return;
    }
    if (during_gc) return;
    during_gc++;

    gc_stack_limit = __stack_grow(STACK_END, GC_LEVEL_MAX);
    init_mark_stack();

    gc_mark((VALUE)ruby_current_node);

    /* mark frame stack */
    for (frame = ruby_frame; frame; frame = frame->prev) {
	rb_gc_mark_frame(frame);
	if (frame->tmp) {
	    struct FRAME *tmp = frame->tmp;
	    while (tmp) {
		rb_gc_mark_frame(tmp);
		tmp = tmp->prev;
	    }
	}
    }
    gc_mark((VALUE)ruby_scope);
    gc_mark((VALUE)ruby_dyna_vars);
    if (finalizer_table) {
	mark_tbl(finalizer_table);
    }

    FLUSH_REGISTER_WINDOWS;
    /* This assumes that all registers are saved into the jmp_buf (and stack) */
    rb_setjmp(save_regs_gc_mark);
    mark_locations_array((VALUE*)save_regs_gc_mark, sizeof(save_regs_gc_mark) / sizeof(VALUE *));
#if STACK_GROW_DIRECTION < 0
    rb_gc_mark_locations(top_frame, rb_curr_thread->stk_start);
#elif STACK_GROW_DIRECTION > 0
    rb_gc_mark_locations(rb_curr_thread->stk_start, top_frame + 1);
#else
    if (rb_gc_stack_grow_direction < 0)
	rb_gc_mark_locations(top_frame, rb_curr_thread->stk_start);
    else
	rb_gc_mark_locations(rb_curr_thread->stk_start, top_frame + 1);
#endif
#ifdef __ia64
    /* mark backing store (flushed register window on the stack) */
    /* the basic idea from guile GC code                         */
    rb_gc_mark_locations(rb_gc_register_stack_start, (VALUE*)rb_ia64_bsp());
#endif
#if defined(__human68k__) || defined(__mc68000__)
    rb_gc_mark_locations((VALUE*)((char*)STACK_END + 2),
			 (VALUE*)((char*)rb_curr_thread->stk_start + 2));
#endif
    rb_gc_mark_threads();

    /* mark protected global variables */
    for (list = global_List; list; list = list->next) {
	rb_gc_mark_maybe(*list->varptr);
    }
    rb_mark_end_proc();
    rb_gc_mark_global_tbl();

    rb_mark_tbl(rb_class_tbl);
    rb_gc_mark_trap_list();

    /* mark generic instance variables for special constants */
    rb_mark_generic_ivar_tbl();

    rb_gc_mark_parser();

    /* gc_mark objects whose marking are not completed*/
    do {
	while (!MARK_STACK_EMPTY) {
	    if (mark_stack_overflow){
		gc_mark_all();
	    }
	    else {
		gc_mark_rest();
	    }
	}
	rb_gc_abort_threads();
    } while (!MARK_STACK_EMPTY);
    gc_sweep();
}

static void
garbage_collect()
{
  VALUE *top = __sp();
#if STACK_WIPE_SITES & 0x400
# ifdef nativeAllocA
  if (__stack_past (top, stack_limit)) {
  /* allocate a large frame to ensure app stack cannot grow into GC stack */
    volatile char *spacer = 
                    nativeAllocA(__stack_depth((void*)stack_limit,(void*)top));
  }  
  garbage_collect_0(top);
# else /* no native alloca() available */
  garbage_collect_0(top);
  {
    VALUE *paddedLimit = __stack_grow(gc_stack_limit, GC_STACK_PAD);
    if (__stack_past(rb_gc_stack_end, paddedLimit))
      rb_gc_stack_end = paddedLimit;
  }
  rb_gc_wipe_stack();  /* wipe the whole stack area reserved for this gc */  
# endif
#else
  garbage_collect_0(top);
#endif
}

void
rb_gc()
{
    garbage_collect();
    rb_gc_finalize_deferred();
}

/*
 *  call-seq:
 *     GC.start                     => nil
 *     gc.garbage_collect           => nil
 *     ObjectSpace.garbage_collect  => nil
 *
 *  Initiates garbage collection, unless manually disabled.
 *
 */

VALUE
rb_gc_start()
{
    rb_gc();
    return Qnil;
}


void
ruby_set_stack_size(size)
    size_t size;
{
#ifndef STACK_LEVEL_MAX
    STACK_LEVEL_MAX = size / sizeof(VALUE);
#endif
    stack_limit = __stack_grow(rb_gc_stack_start, STACK_LEVEL_MAX-GC_STACK_MAX);
}

static void
set_stack_size(void)
{
#ifdef HAVE_GETRLIMIT
  struct rlimit rlim;
  if (getrlimit(RLIMIT_STACK, &rlim) == 0) {
    if (rlim.rlim_cur > 0 && rlim.rlim_cur != RLIM_INFINITY) {
      size_t maxStackBytes = rlim.rlim_cur;
      if (rlim.rlim_cur != maxStackBytes)
        maxStackBytes = -1;
      {
        size_t space = maxStackBytes/5;
        if (space > 1024*1024) space = 1024*1024;
        ruby_set_stack_size(maxStackBytes - space);
        return;
      }
    }
  }
#endif
  ruby_set_stack_size(STACK_LEVEL_MAX*sizeof(VALUE));
}

void
Init_stack(addr)
    VALUE *addr;
{
#ifdef __ia64
    if (rb_gc_register_stack_start == 0) {
# if defined(__FreeBSD__)
        /*
         * FreeBSD/ia64 currently does not have a way for a process to get the
         * base address for the RSE backing store, so hardcode it.
         */
        rb_gc_register_stack_start = (4ULL<<61);
# elif defined(HAVE___LIBC_IA64_REGISTER_BACKING_STORE_BASE)
#  pragma weak __libc_ia64_register_backing_store_base
        extern unsigned long __libc_ia64_register_backing_store_base;
        rb_gc_register_stack_start = (VALUE*)__libc_ia64_register_backing_store_base;
# endif
    }
    {
        VALUE *bsp = (VALUE*)rb_ia64_bsp();
        if (rb_gc_register_stack_start == 0 ||
            bsp < rb_gc_register_stack_start) {
            rb_gc_register_stack_start = bsp;
        }
    }
#endif
#if defined(_WIN32) || defined(__CYGWIN__)
    MEMORY_BASIC_INFORMATION m;
    memset(&m, 0, sizeof(m));
    VirtualQuery(&m, &m, sizeof(m));
    rb_gc_stack_start =
	STACK_UPPER((VALUE *)m.BaseAddress,
		    (VALUE *)((char *)m.BaseAddress + m.RegionSize) - 1);
#elif defined(STACK_END_ADDRESS)
    {
        extern void *STACK_END_ADDRESS;
        rb_gc_stack_start = STACK_END_ADDRESS;
    }
#else
    if (!addr) addr = (void *)&addr;
    STACK_UPPER(addr, ++addr);
    if (rb_gc_stack_start) {
	if (STACK_UPPER(rb_gc_stack_start > addr,
			rb_gc_stack_start < addr))
	    rb_gc_stack_start = addr;
	return;
    }
    rb_gc_stack_start = addr;
#endif
    set_stack_size();
}

void ruby_init_stack(VALUE *addr
#ifdef __ia64
    , void *bsp
#endif
    )
{
    if (!rb_gc_stack_start ||
        STACK_UPPER(rb_gc_stack_start > addr,
                    rb_gc_stack_start < addr)) {
        rb_gc_stack_start = addr;
    }
#ifdef __ia64
    if (!rb_gc_register_stack_start ||
        (VALUE*)bsp < rb_gc_register_stack_start) {
        rb_gc_register_stack_start = (VALUE*)bsp;
    }
#endif
#ifdef HAVE_GETRLIMIT
    set_stack_size();
#elif defined _WIN32
    {
	MEMORY_BASIC_INFORMATION mi;
	DWORD size;
	DWORD space;

	if (VirtualQuery(&mi, &mi, sizeof(mi))) {
	    size = (char *)mi.BaseAddress - (char *)mi.AllocationBase;
	    space = size / 5;
	    if (space > 1024*1024) space = 1024*1024;
	    ruby_set_stack_size(size - space);
	}
    }
#endif
}

/*
 * Document-class: ObjectSpace
 *
 *  The <code>ObjectSpace</code> module contains a number of routines
 *  that interact with the garbage collection facility and allow you to
 *  traverse all living objects with an iterator.
 *
 *  <code>ObjectSpace</code> also provides support for object
 *  finalizers, procs that will be called when a specific object is
 *  about to be destroyed by garbage collection.
 *
 *     include ObjectSpace
 *
 *
 *     a = "A"
 *     b = "B"
 *     c = "C"
 *
 *
 *     define_finalizer(a, proc {|id| puts "Finalizer one on #{id}" })
 *     define_finalizer(a, proc {|id| puts "Finalizer two on #{id}" })
 *     define_finalizer(b, proc {|id| puts "Finalizer three on #{id}" })
 *
 *  <em>produces:</em>
 *
 *     Finalizer three on 537763470
 *     Finalizer one on 537763480
 *     Finalizer two on 537763480
 *
 */

void
Init_heap()
{
    if (!rb_gc_stack_start) {
	Init_stack(0);
    }
    add_heap();
}

static VALUE
os_obj_of(of)
    VALUE of;
{
    int i;
    int n = 0;
    volatile VALUE v;

    for (i = 0; i < heaps_used; i++) {
	RVALUE *p, *pend;

	p = heaps[i].slot; pend = p + heaps[i].limit;
	for (;p < pend; p++) {
	    if (p->as.basic.flags) {
		switch (BUILTIN_TYPE(p)) {
		  case T_NONE:
		  case T_ICLASS:
		  case T_VARMAP:
		  case T_SCOPE:
		  case T_NODE:
		    continue;
		  case T_CLASS:
		    if (FL_TEST(p, FL_SINGLETON)) continue;
		  default:
		    if (!p->as.basic.klass) continue;
                    v = (VALUE)p;
		    if (!of || rb_obj_is_kind_of(v, of)) {
			rb_yield(v);
			n++;
		    }
		}
	    }
	}
    }

    return INT2FIX(n);
}

/*
 *  call-seq:
 *     ObjectSpace.each_object([module]) {|obj| ... } => fixnum
 *
 *  Calls the block once for each living, nonimmediate object in this
 *  Ruby process. If <i>module</i> is specified, calls the block
 *  for only those classes or modules that match (or are a subclass of)
 *  <i>module</i>. Returns the number of objects found. Immediate
 *  objects (<code>Fixnum</code>s, <code>Symbol</code>s
 *  <code>true</code>, <code>false</code>, and <code>nil</code>) are
 *  never returned. In the example below, <code>each_object</code>
 *  returns both the numbers we defined and several constants defined in
 *  the <code>Math</code> module.
 *
 *     a = 102.7
 *     b = 95       # Won't be returned
 *     c = 12345678987654321
 *     count = ObjectSpace.each_object(Numeric) {|x| p x }
 *     puts "Total count: #{count}"
 *
 *  <em>produces:</em>
 *
 *     12345678987654321
 *     102.7
 *     2.71828182845905
 *     3.14159265358979
 *     2.22044604925031e-16
 *     1.7976931348623157e+308
 *     2.2250738585072e-308
 *     Total count: 7
 *
 */

static VALUE
os_each_obj(argc, argv, os)
    int argc;
    VALUE *argv;
    VALUE os;
{
    VALUE of;

    rb_secure(4);
    if (argc == 0) {
	of = 0;
    }
    else {
	rb_scan_args(argc, argv, "01", &of);
    }
    RETURN_ENUMERATOR(os, 1, &of);
    return os_obj_of(of);
}

static VALUE finalizers;

/* deprecated
 */

static VALUE
add_final(os, block)
    VALUE os, block;
{
    rb_warn("ObjectSpace::add_finalizer is deprecated; use define_finalizer");
    if (!rb_respond_to(block, rb_intern("call"))) {
	rb_raise(rb_eArgError, "wrong type argument %s (should be callable)",
		 rb_obj_classname(block));
    }
    rb_ary_push(finalizers, block);
    return block;
}

/*
 * deprecated
 */
static VALUE
rm_final(os, block)
    VALUE os, block;
{
    rb_warn("ObjectSpace::remove_finalizer is deprecated; use undefine_finalizer");
    rb_ary_delete(finalizers, block);
    return block;
}

/*
 * deprecated
 */
static VALUE
finals()
{
    rb_warn("ObjectSpace::finalizers is deprecated");
    return finalizers;
}

/*
 * deprecated
 */

static VALUE
call_final(os, obj)
    VALUE os, obj;
{
    rb_warn("ObjectSpace::call_finalizer is deprecated; use define_finalizer");
    need_call_final = 1;
    FL_SET(obj, FL_FINALIZE);
    return obj;
}

/*
 *  call-seq:
 *     ObjectSpace.undefine_finalizer(obj)
 *
 *  Removes all finalizers for <i>obj</i>.
 *
 */

static VALUE
undefine_final(os, obj)
    VALUE os, obj;
{
    if (finalizer_table) {
	st_delete(finalizer_table, (st_data_t*)&obj, 0);
    }
    return obj;
}

/*
 *  call-seq:
 *     ObjectSpace.define_finalizer(obj, aProc=proc())
 *
 *  Adds <i>aProc</i> as a finalizer, to be called after <i>obj</i>
 *  was destroyed.
 *
 */

static VALUE
define_final(argc, argv, os)
    int argc;
    VALUE *argv;
    VALUE os;
{
    VALUE obj, block, table;

    rb_scan_args(argc, argv, "11", &obj, &block);
    if (argc == 1) {
	block = rb_block_proc();
    }
    else if (!rb_respond_to(block, rb_intern("call"))) {
	rb_raise(rb_eArgError, "wrong type argument %s (should be callable)",
		 rb_obj_classname(block));
    }
    need_call_final = 1;
    FL_SET(obj, FL_FINALIZE);

    block = rb_ary_new3(2, INT2FIX(ruby_safe_level), block);

    if (!finalizer_table) {
	finalizer_table = st_init_numtable();
    }
    if (st_lookup(finalizer_table, obj, &table)) {
	rb_ary_push(table, block);
    }
    else {
	st_add_direct(finalizer_table, obj, rb_ary_new3(1, block));
    }
    return block;
}

void
rb_gc_copy_finalizer(dest, obj)
    VALUE dest, obj;
{
    VALUE table;

    if (!finalizer_table) return;
    if (!FL_TEST(obj, FL_FINALIZE)) return;
    if (st_lookup(finalizer_table, obj, &table)) {
	st_insert(finalizer_table, dest, table);
    }
    RBASIC(dest)->flags |= FL_FINALIZE;
}

static VALUE
run_single_final(args)
    VALUE *args;
{
    rb_eval_cmd(args[0], args[1], (int)args[2]);
    return Qnil;
}

static void
run_final(obj)
    VALUE obj;
{
    long i;
    int status, critical_save = rb_thread_critical;
    VALUE args[3], table, objid;

    objid = rb_obj_id(obj);	/* make obj into id */
    rb_thread_critical = Qtrue;
    args[1] = 0;
    args[2] = (VALUE)ruby_safe_level;
    for (i=0; i<RARRAY(finalizers)->len; i++) {
	args[0] = RARRAY(finalizers)->ptr[i];
	if (!args[1]) args[1] = rb_ary_new3(1, objid);
	rb_protect((VALUE(*)_((VALUE)))run_single_final, (VALUE)args, &status);
    }
    if (finalizer_table && st_delete(finalizer_table, (st_data_t*)&obj, &table)) {
	for (i=0; i<RARRAY(table)->len; i++) {
	    VALUE final = RARRAY(table)->ptr[i];
	    args[0] = RARRAY(final)->ptr[1];
	    if (!args[1]) args[1] = rb_ary_new3(1, objid);
	    args[2] = FIX2INT(RARRAY(final)->ptr[0]);
	    rb_protect((VALUE(*)_((VALUE)))run_single_final, (VALUE)args, &status);
	}
    }
    rb_thread_critical = critical_save;
}

void
rb_gc_finalize_deferred()
{
    RVALUE *p = deferred_final_list;

    deferred_final_list = 0;
    if (p) {
	finalize_list(p);
	free_unused_heaps();
    }
}

void
rb_gc_call_finalizer_at_exit()
{
    RVALUE *p, *pend;
    int i;

    /* run finalizers */
    if (need_call_final) {
	p = deferred_final_list;
	deferred_final_list = 0;
	finalize_list(p);
	for (i = 0; i < heaps_used; i++) {
	    p = heaps[i].slot; pend = p + heaps[i].limit;
	    while (p < pend) {
		if (FL_TEST(p, FL_FINALIZE)) {
		    FL_UNSET(p, FL_FINALIZE);
		    p->as.basic.klass = 0;
		    run_final((VALUE)p);
		}
		p++;
	    }
	}
    }
    /* run data object's finalizers */
    for (i = 0; i < heaps_used; i++) {
	p = heaps[i].slot; pend = p + heaps[i].limit;
	while (p < pend) {
	    if (BUILTIN_TYPE(p) == T_DATA &&
		DATA_PTR(p) && RANY(p)->as.data.dfree) {
		p->as.free.flags = 0;
		if ((long)RANY(p)->as.data.dfree == -1) {
		    RUBY_CRITICAL(free(DATA_PTR(p)));
		}
		else if (RANY(p)->as.data.dfree) {
		    (*RANY(p)->as.data.dfree)(DATA_PTR(p));
		}
	    }
	    else if (BUILTIN_TYPE(p) == T_FILE) {
		p->as.free.flags = 0;
		rb_io_fptr_finalize(RANY(p)->as.file.fptr);
	    }
	    p++;
	}
    }
}

/*
 *  call-seq:
 *     ObjectSpace._id2ref(object_id) -> an_object
 *
 *  Converts an object id to a reference to the object. May not be
 *  called on an object id passed as a parameter to a finalizer.
 *
 *     s = "I am a string"                    #=> "I am a string"
 *     r = ObjectSpace._id2ref(s.object_id)   #=> "I am a string"
 *     r == s                                 #=> true
 *
 */

static VALUE
id2ref(obj, objid)
    VALUE obj, objid;
{
    unsigned long ptr, p0;
    int type;

    rb_secure(4);
    p0 = ptr = NUM2ULONG(objid);
    if (ptr == Qtrue) return Qtrue;
    if (ptr == Qfalse) return Qfalse;
    if (ptr == Qnil) return Qnil;
    if (FIXNUM_P(ptr)) return (VALUE)ptr;
    ptr = objid ^ FIXNUM_FLAG;	/* unset FIXNUM_FLAG */

    if ((ptr % sizeof(RVALUE)) == (4 << 2)) {
        ID symid = ptr / sizeof(RVALUE);
        if (rb_id2name(symid) == 0)
            rb_raise(rb_eRangeError, "%p is not symbol id value", p0);
        return ID2SYM(symid);
    }

    if (!is_pointer_to_heap((void *)ptr)||
	(type = BUILTIN_TYPE(ptr)) >= T_BLKTAG || type == T_ICLASS) {
	rb_raise(rb_eRangeError, "0x%lx is not id value", p0);
    }
    if (BUILTIN_TYPE(ptr) == 0 || RBASIC(ptr)->klass == 0) {
	rb_raise(rb_eRangeError, "0x%lx is recycled object", p0);
    }
    return (VALUE)ptr;
}

/*
 *  Document-method: __id__
 *  Document-method: object_id
 *
 *  call-seq:
 *     obj.__id__       => fixnum
 *     obj.object_id    => fixnum
 *
 *  Returns an integer identifier for <i>obj</i>. The same number will
 *  be returned on all calls to <code>id</code> for a given object, and
 *  no two active objects will share an id.
 *  <code>Object#object_id</code> is a different concept from the
 *  <code>:name</code> notation, which returns the symbol id of
 *  <code>name</code>. Replaces the deprecated <code>Object#id</code>.
 */

/*
 *  call-seq:
 *     obj.hash    => fixnum
 *
 *  Generates a <code>Fixnum</code> hash value for this object. This
 *  function must have the property that <code>a.eql?(b)</code> implies
 *  <code>a.hash == b.hash</code>. The hash value is used by class
 *  <code>Hash</code>. Any hash value that exceeds the capacity of a
 *  <code>Fixnum</code> will be truncated before being used.
 */

VALUE
rb_obj_id(VALUE obj)
{
    /*
     *                32-bit VALUE space
     *          MSB ------------------------ LSB
     *  false   00000000000000000000000000000000
     *  true    00000000000000000000000000000010
     *  nil     00000000000000000000000000000100
     *  undef   00000000000000000000000000000110
     *  symbol  ssssssssssssssssssssssss00001110
     *  object  oooooooooooooooooooooooooooooo00        = 0 (mod sizeof(RVALUE))
     *  fixnum  fffffffffffffffffffffffffffffff1
     *
     *                    object_id space
     *                                       LSB
     *  false   00000000000000000000000000000000
     *  true    00000000000000000000000000000010
     *  nil     00000000000000000000000000000100
     *  undef   00000000000000000000000000000110
     *  symbol   000SSSSSSSSSSSSSSSSSSSSSSSSSSS0        S...S % A = 4 (S...S = s...s * A + 4)
     *  object   oooooooooooooooooooooooooooooo0        o...o % A = 0
     *  fixnum  fffffffffffffffffffffffffffffff1        bignum if required
     *
     *  where A = sizeof(RVALUE)/4
     *
     *  sizeof(RVALUE) is
     *  20 if 32-bit, double is 4-byte aligned
     *  24 if 32-bit, double is 8-byte aligned
     *  40 if 64-bit
     */
    if (TYPE(obj) == T_SYMBOL) {
        return (SYM2ID(obj) * sizeof(RVALUE) + (4 << 2)) | FIXNUM_FLAG;
    }
    if (SPECIAL_CONST_P(obj)) {
        return LONG2NUM((long)obj);
    }
    return (VALUE)((long)obj|FIXNUM_FLAG);
}

/*
 *  The <code>GC</code> module provides an interface to Ruby's mark and
 *  sweep garbage collection mechanism. Some of the underlying methods
 *  are also available via the <code>ObjectSpace</code> module.
 */

void
Init_GC()
{
    VALUE rb_mObSpace;

#if !STACK_GROW_DIRECTION
    rb_gc_stack_end = stack_grow_direction(&rb_mObSpace);
#endif
    rb_mGC = rb_define_module("GC");
    rb_define_singleton_method(rb_mGC, "start", rb_gc_start, 0);
    rb_define_singleton_method(rb_mGC, "enable", rb_gc_enable, 0);
    rb_define_singleton_method(rb_mGC, "disable", rb_gc_disable, 0);
    rb_define_singleton_method(rb_mGC, "limit", gc_getlimit, 0);
    rb_define_singleton_method(rb_mGC, "limit=", gc_setlimit, 1);
    rb_define_singleton_method(rb_mGC, "increase", gc_increase, 0);
    rb_define_singleton_method(rb_mGC, "exorcise", gc_exorcise, 0);
    rb_define_method(rb_mGC, "garbage_collect", rb_gc_start, 0);

    rb_mObSpace = rb_define_module("ObjectSpace");
    rb_define_module_function(rb_mObSpace, "each_object", os_each_obj, -1);
    rb_define_module_function(rb_mObSpace, "garbage_collect", rb_gc_start, 0);
    rb_define_module_function(rb_mObSpace, "add_finalizer", add_final, 1);
    rb_define_module_function(rb_mObSpace, "remove_finalizer", rm_final, 1);
    rb_define_module_function(rb_mObSpace, "finalizers", finals, 0);
    rb_define_module_function(rb_mObSpace, "call_finalizer", call_final, 1);

    rb_define_module_function(rb_mObSpace, "define_finalizer", define_final, -1);
    rb_define_module_function(rb_mObSpace, "undefine_finalizer", undefine_final, 1);

    rb_define_module_function(rb_mObSpace, "_id2ref", id2ref, 1);

    rb_gc_register_address(&rb_mObSpace);
    rb_global_variable(&finalizers);
    rb_gc_unregister_address(&rb_mObSpace);
    finalizers = rb_ary_new();

    source_filenames = st_init_strtable();

    rb_global_variable(&nomem_error);
    nomem_error = rb_exc_new3(rb_eNoMemError,
			      rb_obj_freeze(rb_str_new2("failed to allocate memory")));
    OBJ_TAINT(nomem_error);
    OBJ_FREEZE(nomem_error);

    rb_define_method(rb_mKernel, "hash", rb_obj_id, 0);
    rb_define_method(rb_mKernel, "__id__", rb_obj_id, 0);
    rb_define_method(rb_mKernel, "object_id", rb_obj_id, 0);
}
