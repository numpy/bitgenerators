#ifndef _RANDOM_COMMON_H
#define _RANDOM_COMMON_H

#pragma once
#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct bitgen {
  void *state;
  uint64_t (*next_uint64)(void *st);
  uint32_t (*next_uint32)(void *st);
  double (*next_double)(void *st);
  uint64_t (*next_raw)(void *st);
} bitgen_t;


#endif
