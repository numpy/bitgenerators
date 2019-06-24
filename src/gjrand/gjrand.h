#ifndef _RANDOMDGEN__GJRAND_H_
#define _RANDOMDGEN__GJRAND_H_

#include <inttypes.h>
#ifdef _WIN32
#include <stdlib.h>
#endif
#include "numpy/npy_common.h"

typedef struct s_gjrand_state {
  uint64_t s[4];
  int has_uint32;
  uint32_t uinteger;
} gjrand_state;


static NPY_INLINE uint64_t rotl(const uint64_t value, unsigned int rot) {
#ifdef _WIN32
  return _rotl64(value, rot);
#else
  return (value << rot) | (value >> ((-rot) & 63));
#endif
}

static NPY_INLINE uint64_t gjrand_next(uint64_t *s) {
  s[1] += s[2];
  s[0] = rotl(s[0], 32);
  s[2] ^= s[1];
  s[3] += 0x55aa96a5;
  s[0] += s[1];
  s[2] = rotl(s[2], 23);
  s[1] ^= s[0];
  s[0] += s[2];
  s[1] = rotl(s[1], 19);
  s[2] += s[0];
  s[1] += s[3];

  return s[0];
}


static NPY_INLINE uint64_t gjrand_next64(gjrand_state *state) {
  return gjrand_next(&state->s[0]);
}

static NPY_INLINE uint32_t gjrand_next32(gjrand_state *state) {
  uint64_t next;
  if (state->has_uint32) {
    state->has_uint32 = 0;
    return state->uinteger;
  }
  next = gjrand_next(&state->s[0]);
  state->has_uint32 = 1;
  state->uinteger = (uint32_t)(next >> 32);
  return (uint32_t)(next & 0xffffffff);
}

void gjrand_set_seed(gjrand_state *state, uint64_t *seed);

void gjrand_get_state(gjrand_state *state, uint64_t *state_arr, int *has_uint32,
                     uint32_t *uinteger);

void gjrand_set_state(gjrand_state *state, uint64_t *state_arr, int has_uint32,
                     uint32_t uinteger);

#endif
