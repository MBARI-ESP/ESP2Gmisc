#include "rubysig.h"  /* for STACK_WIPE_SITES */

#define string_arg(s) #s
#define MBARI_RELEASE(wipe_sites) "-mbari8B/" string_arg(wipe_sites)

#define RUBY_VERSION "1.6.8" MBARI_RELEASE(STACK_WIPE_SITES)
#define RUBY_RELEASE_DATE "2011-3-20"
#define RUBY_VERSION_CODE 168
#define RUBY_RELEASE_CODE 200110320

#define RUBY_VERSION_MAJOR 1
#define RUBY_VERSION_MINOR 6
#define RUBY_VERSION_TEENY 8

#define RUBY_RELEASE_YEAR 2011
#define RUBY_RELEASE_MONTH 3
#define RUBY_RELEASE_DAY 20
