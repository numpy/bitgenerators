import operator

import numpy as np
cimport numpy as np

from .common cimport *
from .bit_generator cimport BitGenerator
from .entropy import random_entropy

__all__ = ['DSFMT']

np.import_array()

DEF DSFMT_MEXP = 19937
DEF DSFMT_N = 191  # ((DSFMT_MEXP - 128) / 104 + 1)
DEF DSFMT_N_PLUS_1 = 192  # DSFMT_N + 1
DEF DSFMT_N64 = DSFMT_N * 2

cdef extern from "src/dsfmt/dSFMT.h":

    union W128_T:
        uint64_t u[2]
        uint32_t u32[4]
        double d[2]

    ctypedef W128_T w128_t

    struct DSFMT_T:
        w128_t status[DSFMT_N_PLUS_1]
        int idx

    ctypedef DSFMT_T dsfmt_t

    struct s_dsfmt_state:
        dsfmt_t *state
        int has_uint32
        uint32_t uinteger

        double *buffered_uniforms
        int buffer_loc

    ctypedef s_dsfmt_state dsfmt_state

    double dsfmt_next_double(dsfmt_state *state)  nogil
    uint64_t dsfmt_next64(dsfmt_state *state)  nogil
    uint32_t dsfmt_next32(dsfmt_state *state)  nogil
    uint64_t dsfmt_next_raw(dsfmt_state *state)  nogil

    void dsfmt_init_gen_rand(dsfmt_t *dsfmt, uint32_t seed)
    void dsfmt_init_by_array(dsfmt_t *dsfmt, uint32_t init_key[], int key_length)
    void dsfmt_jump(dsfmt_state *state)

cdef uint64_t dsfmt_uint64(void* st) nogil:
    return dsfmt_next64(<dsfmt_state *>st)

cdef uint32_t dsfmt_uint32(void *st) nogil:
    return dsfmt_next32(<dsfmt_state *> st)

cdef double dsfmt_double(void* st) nogil:
    return dsfmt_next_double(<dsfmt_state *>st)

cdef uint64_t dsfmt_raw(void *st) nogil:
    return dsfmt_next_raw(<dsfmt_state *>st)

cdef class DSFMT(BitGenerator):
    """
    DSFMT(seed_seq=None)

    Container for the SIMD-based Mersenne Twister pseudo RNG.

    Parameters
    ----------
    seed_seq : {None, int, array_like, SeedSequence}, optional
        A SeedSequence to initialize the BitGenerator. If None, one will be
        created. If an int or array_like, it will be used as the entropy for
        creating a SeedSequence.

    Attributes
    ----------
    lock: threading.Lock
        Lock instance that is shared so that the same bit git generator can
        be used in multiple Generators without corrupting the state. Code that
        generates values from a bit generator should hold the bit generator's
        lock.

    Notes
    -----
    ``DSFMT`` provides a capsule containing function pointers that produce
    doubles, and unsigned 32 and 64- bit integers [1]_ . These are not
    directly consumable in Python and must be consumed by a ``Generator``
    or similar object that supports low-level access.

    The Python stdlib module "random" also contains a Mersenne Twister
    pseudo-random number generator.

    **State and Seeding**

    The preferred way to use a BitGenerator in parallel applications is to use
    the `SeedSequence.spawn` method to obtain entropy values, and to use these
    to generate new BitGenerators:

    >>> from numpy.random import Generator, DSFMT, SeedSequence
    >>> sg = SeedSequence(1234)
    >>> rg = [Generator(DSFMT(s)) for s in sg.spawn(10)]

    The ``DSFMT`` state vector consists of a 384 element array of 64-bit
    unsigned integers plus a single integer value between 0 and 382
    indicating the current position within the main array. The implementation
    used here augments this with a 382 element array of doubles which are used
    to efficiently access the random numbers produced by the dSFMT generator.

    ``DSFMT`` is seeded using either a single 32-bit unsigned integer or a
    vector of 32-bit unsigned integers. In either case, the input seed_seq is
    used as an input (or inputs) for a hashing function, and the output of the
    hashing function is used as the initial state. Using a single 32-bit value
    for the seedseq can only initialize a small range of the possible initial
    state values.

    **Parallel Features**

    ``DSFMT`` can be used in parallel applications by calling the method
    ``jumped`` which advances the state as-if :math:`2^{128}` random numbers
    have been generated [2]_. This allows the original sequence to be split
    so that distinct segments can be used in each worker process. All
    generators should be chained to ensure that the segments come from the same
    sequence.

    >>> from numpy.random.entropy import random_entropy
    >>> from numpy.random import Generator, DSFMT
    >>> seed_seq = SeedSequence()
    >>> bit_generator = DSFMT(seed_seq)
    >>> rg = []
    >>> for _ in range(10):
    ...    rg.append(Generator(bit_generator))
    ...    # Chain the BitGenerators
    ...    bit_generator = bit_generator.jumped()

    **Compatibility Guarantee**

    ``DSFMT`` makes a guarantee that a fixed seed and will always produce
    the same random integer stream.

    References
    ----------
    .. [1] Mutsuo Saito and Makoto Matsumoto, "SIMD-oriented Fast Mersenne
           Twister: a 128-bit Pseudorandom Number Generator." Monte Carlo
           and Quasi-Monte Carlo Methods 2006, Springer, pp. 607--622, 2008.
    .. [2] Hiroshi Haramoto, Makoto Matsumoto, and Pierre L\'Ecuyer, "A Fast
           Jump Ahead Algorithm for Linear Recurrences in a Polynomial Space",
           Sequences and Their Applications - SETA, 290--298, 2008.
    """
    cdef dsfmt_state rng_state

    def __init__(self, seed_seq=None):
        BitGenerator.__init__(self, seed_seq)
        self.rng_state.state = <dsfmt_t *>PyArray_malloc_aligned(sizeof(dsfmt_t))
        self.rng_state.buffered_uniforms = <double *>PyArray_calloc_aligned(DSFMT_N64, sizeof(double))
        self.rng_state.buffer_loc = DSFMT_N64

        self._bitgen.state = <void *>&self.rng_state
        self._bitgen.next_uint64 = &dsfmt_uint64
        self._bitgen.next_uint32 = &dsfmt_uint32
        self._bitgen.next_double = &dsfmt_double
        self._bitgen.next_raw = &dsfmt_raw
        val = self._seed_seq.generate_state(DSFMT_N * 4, np.uint32)
        dsfmt_init_by_array(self.rng_state.state,
                                <uint32_t *>np.PyArray_DATA(val),
                                np.PyArray_DIM(val, 0))

        self._reset_state_variables()

    def __dealloc__(self):
        if self.rng_state.state:
            PyArray_free_aligned(self.rng_state.state)
        if self.rng_state.buffered_uniforms:
            PyArray_free_aligned(self.rng_state.buffered_uniforms)

    cdef _reset_state_variables(self):
        self.rng_state.buffer_loc = DSFMT_N64

    cdef jump_inplace(self, iter):
        """
        Jump state in-place

        Not part of public API

        Parameters
        ----------
        iter : integer, positive
            Number of times to jump the state of the rng.
        """
        cdef np.npy_intp i
        for i in range(iter):
            dsfmt_jump(&self.rng_state)
        # Clear the buffer
        self._reset_state_variables()

    def jumped(self, np.npy_intp jumps=1):
        """
        jumped(jumps=1)

        Returns a new bit generator with the state jumped

        The state of the returned big generator is jumped as-if
        2**(128 * jumps) random numbers have been generated.

        Parameters
        ----------
        jumps : integer, positive
            Number of times to jump the state of the bit generator returned

        Returns
        -------
        bit_generator : DSFMT
            New instance of generator jumped iter times
        """
        cdef DSFMT bit_generator

        bit_generator = self.__class__()
        bit_generator.state = self.state
        bit_generator.jump_inplace(jumps)

        return bit_generator

    @property
    def state(self):
        """
        Get or set the PRNG state

        Returns
        -------
        state : dict
            Dictionary containing the information required to describe the
            state of the PRNG
        """

        cdef Py_ssize_t i, j, loc = 0
        cdef uint64_t[::1] state
        cdef double[::1] buffered_uniforms

        state = np.empty(2 *DSFMT_N_PLUS_1, dtype=np.uint64)
        for i in range(DSFMT_N_PLUS_1):
            for j in range(2):
                state[loc] = self.rng_state.state.status[i].u[j]
                loc += 1
        buffered_uniforms = np.empty(DSFMT_N64, dtype=np.double)
        for i in range(DSFMT_N64):
            buffered_uniforms[i] = self.rng_state.buffered_uniforms[i]
        return {'bit_generator': self.__class__.__name__,
                'state': {'state': np.asarray(state),
                          'idx': self.rng_state.state.idx},
                'buffer_loc': self.rng_state.buffer_loc,
                'buffered_uniforms': np.asarray(buffered_uniforms)}

    @state.setter
    def state(self, value):
        cdef Py_ssize_t i, j, loc = 0
        if not isinstance(value, dict):
            raise TypeError('state must be a dict')
        bitgen = value.get('bit_generator', '')
        if bitgen != self.__class__.__name__:
            raise ValueError('state must be for a {0} '
                             'PRNG'.format(self.__class__.__name__))
        state = value['state']['state']
        for i in range(DSFMT_N_PLUS_1):
            for j in range(2):
                self.rng_state.state.status[i].u[j] = state[loc]
                loc += 1
        self.rng_state.state.idx = value['state']['idx']
        buffered_uniforms = value['buffered_uniforms']
        for i in range(DSFMT_N64):
            self.rng_state.buffered_uniforms[i] = buffered_uniforms[i]
        self.rng_state.buffer_loc = value['buffer_loc']
