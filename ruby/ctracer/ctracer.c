/**********************************************************************

  ctracer.c -

  $Author$
  $Date$
  
  Revised:  11/14/07 brent@mbari.org
    fast ruby interpreter event tracer

**********************************************************************/

#include "ruby.h"
#include "rubyio.h"
#include "node.h"
#include <stdio.h>
#include <errno.h>
#include <signal.h>
#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

extern chkblks(void);
extern rb_thread_t rb_curr_thread;

extern VALUE rb_stderr;

#define FIFOSIZELN2  16
#define FIFOSIZE  (1<<FIFOSIZELN2)

typedef struct traceRecord {
    rb_thread_t thread;
    rb_event_t event;
    NODE *node;
    VALUE self;
    ID id;
} traceRecord;

static VALUE name, to_s;

static unsigned ctracer_cursor = 0;
static traceRecord ctracer_fifo[FIFOSIZE];
static int dumping = 0;

static void
ctrace_func(event, node, self, id, klass)
    rb_event_t event;
    NODE *node;
    VALUE self;
    ID id;
    VALUE klass;
{
    if (!dumping) {
      traceRecord *next = ctracer_fifo + (ctracer_cursor & (FIFOSIZE-1));

      next->thread = rb_curr_thread;
      next->event = event;
      next->node = node;
      next->self = self;
      next->id = id;
      ctracer_cursor++;

      chkblks();
    }
}


static VALUE ctracer_clear(void)
{
  unsigned oldSize = ctracer_cursor;
  ctracer_cursor = 0;
  dumping = 0;
  return UINT2NUM(oldSize);
}

extern char *get_event_name(rb_event_t event);

static void ctracer_dump_entry(FILE *f, traceRecord *t, rb_thread_t *lastThread)
{
  char *srcFile = t->node->nd_file;
  int srcLine = nd_line(t->node);
  
  if (*lastThread != t->thread) {
    VALUE threadObj = (*lastThread = t->thread)->thread;
    if (rb_method_boundp(RBASIC(threadObj)->klass, name, 0))
      fprintf (f,"==> %s\n",
        RSTRING_PTR(rb_funcall(rb_funcall(threadObj, name, 0), to_s, 0)));
    else
      fprintf(f,"==> 0x%08x\n", threadObj); 
  }
  if (!srcFile)
    srcFile="(no file)";

  fprintf(f,"%8s %s:%-4d %s.%s\n", get_event_name(t->event),
    srcFile, srcLine, rb_obj_classname(t->self), rb_id2name(t->id)); 
}


static VALUE ctracer_dump(int argc, VALUE *argv)
{
  VALUE output, count;
  rb_thread_t lastThread = NULL;
  traceRecord *entry, *end;
  OpenFile *oFile;
  unsigned cnt;
   
  int args;
  
  args = rb_scan_args(argc, argv, "02", &count, &output);
  if (args<2) {
    output = rb_stderr;
    if (args<1) count=INT2FIX(FIFOSIZE);
  }
  Check_Type(output, T_FILE);
  GetOpenFile(output, oFile);
  cnt = NUM2UINT(count);
  if (cnt > ctracer_cursor)
    cnt = ctracer_cursor;
  count = UINT2NUM(cnt);
  entry = ctracer_fifo + ((ctracer_cursor-cnt)&(FIFOSIZE-1));
  end = ctracer_fifo + FIFOSIZE;
  dumping = 1;
  fprintf (oFile->f, "Last %d events of %d recorded\n", cnt, ctracer_cursor);
  while(cnt) {
    if (entry >= end)
      entry = ctracer_fifo;
    ctracer_dump_entry(oFile->f, entry, &lastThread);
    entry++;
    --cnt;
  }
  dumping = 0;
  return count;
}


static VALUE rb_mTracer;

void
Init_ctracer()
{
    name = rb_intern("name");
    to_s = rb_intern("to_s");
    rb_mTracer = rb_define_module("CTracer");
    rb_define_singleton_method(rb_mTracer, "clear", ctracer_clear,0);
    rb_define_singleton_method(rb_mTracer, "dump", ctracer_dump, -1);
    rb_add_event_hook(ctrace_func, RUBY_EVENT_ALL);
}

