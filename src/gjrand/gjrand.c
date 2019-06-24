#include "gjrand.h"

extern void gjrand_set_seed(gjrand_state *state, uint64_t *seed) {
  int i;

  state->s[0] = seed[0];
  state->s[1] = seed[1];
  state->s[2] = 2000001;
  state->s[3] = 0;

  for (i=0; i<14; i++) {
    (void)gjrand_next(state->s);
  }
}

extern void gjrand_get_state(gjrand_state *state, uint64_t *state_arr, int *has_uint32,
                            uint32_t *uinteger) {
  int i;

  for (i=0; i<4; i++) {
    state_arr[i] = state->s[i];
  }
  has_uint32[0] = state->has_uint32;
  uinteger[0] = state->uinteger;
}

extern void gjrand_set_state(gjrand_state *state, uint64_t *state_arr, int has_uint32,
                            uint32_t uinteger) {
  int i;

  for (i=0; i<4; i++) {
    state->s[i] = state_arr[i];
  }
  state->has_uint32 = has_uint32;
  state->uinteger = uinteger;
}
