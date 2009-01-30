#include "rubysig.h"  /* for STACK_WIPE_SITES */

#define string_arg(s) #s
#define MBARI_RELEASE(wipe_sites) "-mbari7/" string_arg(wipe_sites)

#define RUBY_VERSION "1.6.8" MBARI_RELEASE(STACK_WIPE_SITES)
#define RUBY_RELEASE_DATE "2009-1-29"
#define RUBY_VERSION_CODE 168
#define RUBY_RELEASE_CODE 20090129

#define RUBY_VERSION_MAJOR 1
#define RUBY_VERSION_MINOR 6
#define RUBY_VERSION_TEENY 8

#define RUBY_RELEASE_YEAR 2009
#define RUBY_RELEASE_MONTH 1
#define RUBY_RELEASE_DAY 29
