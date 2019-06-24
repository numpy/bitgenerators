#ifndef _RANDOMDGEN__JSF64_H_
#define _RANDOMDGEN__JSF64_H_

#include <inttypes.h>
#ifdef _WIN32
#include <stdlib.h>
#endif
#include "numpy/npy_common.h"

typedef struct s_jsf64_state {
  uint64_t s[4];
  int has_uint32;
  uint32_t uinteger;
} jsf64_state;


static NPY_INLINE uint64_t rotl(const uint64_t value, unsigned int rot) {
#ifdef _WIN32
  return _rotl64(value, rot);
#else
  return (value << rot) | (value >> ((-rot) & 63));
#endif
}

static NPY_INLINE uint64_t jsf64_next(uint64_t *s) {
  const uint64_t e = s[0] - rotl(s[1], 7);

  s[0] = s[1] ^ rotl(s[2], 13);
  s[1] = s[2] + rotl(s[3], 37);
  s[2] = s[3] + e;
  s[3] = e + s[0];

  return s[3];
}


static NPY_INLINE uint64_t jsf64_next64(jsf64_state *state) {
  return jsf64_next(&state->s[0]);
}

static NPY_INLINE uint32_t jsf64_next32(jsf64_state *state) {
  uint64_t next;
  if (state->has_uint32) {
    state->has_uint32 = 0;
    return state->uinteger;
  }
  next = jsf64_next(&state->s[0]);
  state->has_uint32 = 1;
  state->uinteger = (uint32_t)(next >> 32);
  return (uint32_t)(next & 0xffffffff);
}

void jsf64_set_seed(jsf64_state *state, uint64_t *seed);

void jsf64_get_state(jsf64_state *state, uint64_t *state_arr, int *has_uint32,
                     uint32_t *uinteger);

void jsf64_set_state(jsf64_state *state, uint64_t *state_arr, int has_uint32,
                     uint32_t uinteger);

#endif
