/*
  The usual types and constants that are missing from the
  'C' standard  -- brent@mbari.org
*/

#ifndef TYPES_H

#ifndef FALSE
#define FALSE (0)
#endif

#ifndef TRUE
#define TRUE (!FALSE)
#endif

typedef enum{false,true} bool;

typedef unsigned short u16;
typedef unsigned u32;

#endif
