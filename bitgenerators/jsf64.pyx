import numpy as np
cimport numpy as np

from numpy.random.common cimport *
from numpy.random.bit_generator cimport BitGenerator

__all__ = ['JSF64']

cdef extern from "src/jsf64/jsf64.h":
    struct s_jsf64_state:
        uint64_t s[4]
        int has_uint32
        uint32_t uinteger

    ctypedef s_jsf64_state jsf64_state
    uint64_t jsf64_next64(jsf64_state *state)  nogil
    uint32_t jsf64_next32(jsf64_state *state)  nogil
    void jsf64_set_seed(jsf64_state *state, uint64_t *seed)
    void jsf64_get_state(jsf64_state *state, uint64_t *state_arr, int *has_uint32, uint32_t *uinteger)
    void jsf64_set_state(jsf64_state *state, uint64_t *state_arr, int has_uint32, uint32_t uinteger)


cdef uint64_t jsf64_uint64(void* st) nogil:
    return jsf64_next64(<jsf64_state *>st)

cdef uint32_t jsf64_uint32(void *st) nogil:
    return jsf64_next32(<jsf64_state *> st)

cdef double jsf64_double(void* st) nogil:
    return uint64_to_double(jsf64_next64(<jsf64_state *>st))


cdef class JSF64(BitGenerator):
    """
    JSF64(seed_seq=None)

    BitGenerator for Bob Jenkin's Small Fast PRNG.

    Parameters
    ----------
    seed_seq : {None, ISeedSequence, int, array_like[ints]}, optional
        A SeedSequence to initialize the BitGenerator. If None, one will be
        created. If an int or array_like[ints], it will be used as the entropy
        for creating a SeedSequence.

    Notes
    -----
    JSF64 is a 256-bit implementation of Bob Jenkin's Small Fast PRNG ([1]_). Strictly
    speaking, JSF64 has a few different cycles that one might be on, depending
    on the seed, but its seeding should prevent most of the "short" ones. The
    expected period will be about :math:`2^{255}` ([2]_).

    ``JSF64`` provides a capsule containing function pointers that produce
    doubles, and unsigned 32 and 64- bit integers. These are not
    directly consumable in Python and must be consumed by a ``Generator``
    or similar object that supports low-level access.

    **Compatibility Guarantee**

    ``JSF64`` makes a guarantee that a fixed seed and will always produce
    the same random integer stream.

    References
    ----------
    .. [1] "A small noncryptographic PRNG",
            http://burtleburtle.net/bob/rand/smallprng.html
    .. [2] "Random Invertible Mapping Statistics",
            http://www.pcg-random.org/posts/random-invertible-mapping-statistics.html
    """

    cdef jsf64_state rng_state

    def __init__(self, seed_seq=None):
        BitGenerator.__init__(self, seed_seq)
        self._bitgen.state = <void *>&self.rng_state
        self._bitgen.next_uint64 = &jsf64_uint64
        self._bitgen.next_uint32 = &jsf64_uint32
        self._bitgen.next_double = &jsf64_double
        self._bitgen.next_raw = &jsf64_uint64
        # Seed the _bitgen
        val = self._seed_seq.generate_state(3, np.uint64)
        jsf64_set_seed(&self.rng_state, <uint64_t*>np.PyArray_DATA(val))
        self._reset_state_variables()

    cdef _reset_state_variables(self):
        self.rng_state.has_uint32 = 0
        self.rng_state.uinteger = 0

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
        cdef np.ndarray state_vec
        cdef int has_uint32
        cdef uint32_t uinteger

        state_vec = <np.ndarray>np.empty(4, dtype=np.uint64)
        jsf64_get_state(&self.rng_state,
                        <uint64_t *>np.PyArray_DATA(state_vec),
                        &has_uint32, &uinteger)
        return {'bit_generator': self.__class__.__name__,
                'state': {'state': state_vec},
                'has_uint32': has_uint32,
                'uinteger': uinteger}

    @state.setter
    def state(self, value):
        cdef np.ndarray state_vec
        cdef int has_uint32
        cdef uint32_t uinteger
        if not isinstance(value, dict):
            raise TypeError('state must be a dict')
        bitgen = value.get('bit_generator', '')
        if bitgen != self.__class__.__name__:
            raise ValueError('state must be for a {0} '
                             'RNG'.format(self.__class__.__name__))
        state_vec = <np.ndarray>np.empty(4, dtype=np.uint64)
        state_vec[:] = value['state']['state']
        has_uint32 = value['has_uint32']
        uinteger = value['uinteger']
        jsf64_set_state(&self.rng_state,
                        <uint64_t *>np.PyArray_DATA(state_vec),
                        has_uint32, uinteger)
