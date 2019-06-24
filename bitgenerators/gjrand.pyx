import numpy as np
cimport numpy as np

from numpy.random.common cimport *
from numpy.random.bit_generator cimport BitGenerator

__all__ = ['GJrand']

cdef extern from "src/gjrand/gjrand.h":
    struct s_gjrand_state:
        uint64_t s[4]
        int has_uint32
        uint32_t uinteger

    ctypedef s_gjrand_state gjrand_state
    uint64_t gjrand_next64(gjrand_state *state)  nogil
    uint32_t gjrand_next32(gjrand_state *state)  nogil
    void gjrand_set_seed(gjrand_state *state, uint64_t *seed)
    void gjrand_get_state(gjrand_state *state, uint64_t *state_arr, int *has_uint32, uint32_t *uinteger)
    void gjrand_set_state(gjrand_state *state, uint64_t *state_arr, int has_uint32, uint32_t uinteger)


cdef uint64_t gjrand_uint64(void* st) nogil:
    return gjrand_next64(<gjrand_state *>st)

cdef uint32_t gjrand_uint32(void *st) nogil:
    return gjrand_next32(<gjrand_state *> st)

cdef double gjrand_double(void* st) nogil:
    return uint64_to_double(gjrand_next64(<gjrand_state *>st))


cdef class GJrand(BitGenerator):
    """
    GJrand(seed_seq=None)

    BitGenerator for David Blackman's GJrand PRNG.

    Parameters
    ----------
    seed_seq : {None, ISeedSequence, int, array_like[ints]}, optional
        A SeedSequence to initialize the BitGenerator. If None, one will be
        created. If an int or array_like[ints], it will be used as the entropy
        for creating a SeedSequence.

    Notes
    -----
    ``GJrand`` is a 256-bit implementation of David Blackman's GJrand PRNG ([1]_).
    ``GJrand`` has a few different cycles that one might be on, depending on the
    seed; the expected period will be about :math:`2^{255}` ([2]_). ``GJrand`` 
    incorporates a 64-bit counter which means that the absolute minimum cycle
    length is :math:`2**{64}` and that distinct seeds will not run into each
    other for at least :math:`2**{64}` iterations ([3]_).

    ``GJrand`` provides a capsule containing function pointers that produce
    doubles, and unsigned 32 and 64- bit integers. These are not
    directly consumable in Python and must be consumed by a ``Generator``
    or similar object that supports low-level access.

    **Compatibility Guarantee**

    ``GJrand`` makes a guarantee that a fixed seed will always produce the same
    random integer stream.

    References
    ----------
    .. [1] "gjrand random numbers"
            http://gjrand.sourceforge.net/
    .. [2] "Random Invertible Mapping Statistics",
            http://www.pcg-random.org/posts/random-invertible-mapping-statistics.html
    .. [3] "gjrand boasting page"
            http://gjrand.sourceforge.net/boast.html
    """

    cdef gjrand_state rng_state

    def __init__(self, seed_seq=None):
        BitGenerator.__init__(self, seed_seq)
        self._bitgen.state = <void *>&self.rng_state
        self._bitgen.next_uint64 = &gjrand_uint64
        self._bitgen.next_uint32 = &gjrand_uint32
        self._bitgen.next_double = &gjrand_double
        self._bitgen.next_raw = &gjrand_uint64
        # Seed the _bitgen
        val = self._seed_seq.generate_state(2, np.uint64)
        gjrand_set_seed(&self.rng_state, <uint64_t*>np.PyArray_DATA(val))
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
        gjrand_get_state(&self.rng_state,
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
        gjrand_set_state(&self.rng_state,
                        <uint64_t *>np.PyArray_DATA(state_vec),
                        has_uint32, uinteger)
