#include "jsf64.h"

extern void jsf64_set_seed(jsf64_state *state, uint64_t *seed) {
  /* Conservatively stick with the original formula. With SeedSequence, it
   * might be fine to just set the state with 4 uint64s and be done.
   */
  int i;

  state->s[0] = 0xf1ea5eed;
  state->s[1] = seed[0];
  state->s[2] = seed[1];
  state->s[3] = seed[2];

  for (i=0; i<20; i++) {
    (void)jsf64_next(state->s);
  }
}

extern void jsf64_get_state(jsf64_state *state, uint64_t *state_arr, int *has_uint32,
                            uint32_t *uinteger) {
  int i;

  for (i=0; i<4; i++) {
    state_arr[i] = state->s[i];
  }
  has_uint32[0] = state->has_uint32;
  uinteger[0] = state->uinteger;
}

extern void jsf64_set_state(jsf64_state *state, uint64_t *state_arr, int has_uint32,
                            uint32_t uinteger) {
  int i;

  for (i=0; i<4; i++) {
    state->s[i] = state_arr[i];
  }
  state->has_uint32 = has_uint32;
  state->uinteger = uinteger;
}
