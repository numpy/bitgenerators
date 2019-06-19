import numpy as np
cimport numpy as np

from .common cimport *

from .bit_generator cimport BitGenerator

__all__ = ['PCG32']

np.import_array()

cdef extern from "src/pcg32/pcg32.h":

    cdef struct pcg_state_setseq_64:
        uint64_t state
        uint64_t inc

    ctypedef pcg_state_setseq_64 pcg32_random_t

    struct s_pcg32_state:
        pcg32_random_t *pcg_state

    ctypedef s_pcg32_state pcg32_state

    uint64_t pcg32_next64(pcg32_state *state)  nogil
    uint32_t pcg32_next32(pcg32_state *state)  nogil
    double pcg32_next_double(pcg32_state *state)  nogil
    void pcg32_jump(pcg32_state *state)
    void pcg32_advance_state(pcg32_state *state, uint64_t step)
    void pcg32_set_seed(pcg32_state *state, uint64_t seed, uint64_t inc)

cdef uint64_t pcg32_uint64(void* st) nogil:
    return pcg32_next64(<pcg32_state *>st)

cdef uint32_t pcg32_uint32(void *st) nogil:
    return pcg32_next32(<pcg32_state *> st)

cdef double pcg32_double(void* st) nogil:
    return pcg32_next_double(<pcg32_state *>st)

cdef uint64_t pcg32_raw(void* st) nogil:
    return <uint64_t>pcg32_next32(<pcg32_state *> st)


cdef class PCG32(BitGenerator):
    """
    PCG32(seed=None)

    BitGenerator for the PCG-32 pseudo-random number generator.

    Parameters
    ----------
    seed_seq : {None, SeedSequence, int, array_like[ints]}, optional
        A SeedSequence to initialize the BitGenerator. If None, one will be
        created. If an int or array_like[ints], it will be used as the entropy
        for creating a SeedSequence.

    Notes
    -----
    PCG-32 is a 64-bit implementation of O'Neill's permutation congruential
    generator ([1]_, [2]_). PCG-32 has a period of :math:`2^{64}` and supports
    advancing an arbitrary number of steps as well as :math:`2^{63}` streams.

    ``PCG32`` provides a capsule containing function pointers that produce
    doubles, and unsigned 32 and 64- bit integers. These are not
    directly consumable in Python and must be consumed by a ``Generator``
    or similar object that supports low-level access.

    Supports the method advance to advance the RNG an arbitrary number of
    steps. The state of the PCG-32 PRNG is represented by 2 64-bit unsigned
    integers.

    See ``PCG64`` for a similar implementation with a larger period.

    **State and Seeding**

    The ``PCG32`` state vector consists of 2 unsigned 64-bit values.
    ``PCG32`` is seeded using a single 64-bit unsigned integer.
    In addition, a second 64-bit unsigned integer is used to set the stream.

    **Parallel Features**

    The preferred way to use a BitGenerator in parallel applications is to use
    the `SeedSequence.spawn` method to obtain entropy values, and to use these
    to generate new BitGenerators:

    >>> from numpy.random import Generator, PCG32, SeedSequence
    >>> sg = SeedSequence(1234)
    >>> rg = [Generator(PCG32(s)) for s in sg.spawn(10)]

    **Compatibility Guarantee**

    ``PCG32`` makes a guarantee that a fixed seed and will always produce
    the same random integer stream.

    References
    ----------
    .. [1] "PCG, A Family of Better Random Number Generators",
           http://www.pcg-random.org/
    .. [2] O'Neill, Melissa E. "PCG: A Family of Simple Fast Space-Efficient
           Statistically Good Algorithms for Random Number Generation"
    """

    cdef pcg32_state rng_state
    cdef pcg32_random_t pcg32_random_state

    def __init__(self, seed_seq=None):
        BitGenerator.__init__(self, seed_seq)
        self.rng_state.pcg_state = &self.pcg32_random_state

        self._bitgen.state = <void *>&self.rng_state
        self._bitgen.next_uint64 = &pcg32_uint64
        self._bitgen.next_uint32 = &pcg32_uint32
        self._bitgen.next_double = &pcg32_double
        self._bitgen.next_raw = &pcg32_raw

        # Seed the _bitgen
        val = self._seed_seq.generate_state(2, np.uint64)
        pcg32_set_seed(&self.rng_state,
                       <uint64_t>val[0],
                       <uint64_t>val[1])

    cdef jump_inplace(self, jumps):
        """
        Jump state in-place
        Not part of public API

        Parameters
        ----------
        jumps : integer, positive
            Number of times to jump the state of the rng.

        Notes
        -----
        The step size is phi-1 when divided by 2**64 where phi is the
        golden number.
        """
        step = int(0x9e3779b97f4a7c16)
        self.advance(step * int(jumps))

    def jumped(self, jumps=1):
        """
        jumped(jumps=1)
        Returns a new bit generator with the state jumped

        Jumps the state as-if jumps * 11400714819323198486 * random numbers
        have been generated.

        Parameters
        ----------
        jumps : integer, positive
            Number of times to jump the state of the bit generator returned

        Returns
        -------
        bit_generator : PCG32
            New instance of generator jumped iter times

        Notes
        -----
        The jump size is phi-1 when divided by 2**64 where phi is the
        golden number.
        """
        cdef PCG32 bit_generator

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
        return {'bit_generator': self.__class__.__name__,
                'state': {'state': self.rng_state.pcg_state.state,
                          'inc': self.rng_state.pcg_state.inc}}

    @state.setter
    def state(self, value):
        if not isinstance(value, dict):
            raise TypeError('state must be a dict')
        bitgen = value.get('bit_generator', '')
        if bitgen != self.__class__.__name__:
            raise ValueError('state must be for a {0} '
                             'PRNG'.format(self.__class__.__name__))
        self.rng_state.pcg_state.state = value['state']['state']
        self.rng_state.pcg_state.inc = value['state']['inc']

    def advance(self, delta):
        """
        advance(delta)

        Advance the underlying RNG as-if delta draws have occurred.

        Parameters
        ----------
        delta : integer, positive
            Number of draws to advance the RNG. Must be less than the
            size state variable in the underlying RNG.

        Returns
        -------
        self : PCG32
            RNG advanced delta steps

        Notes
        -----
        Advancing a RNG updates the underlying RNG state as-if a given
        number of calls to the underlying RNG have been made. In general
        there is not a one-to-one relationship between the number output
        random values from a particular distribution and the number of
        draws from the core RNG.  This occurs for two reasons:

        * The random values are simulated using a rejection-based method
          and so, on average, more than one value from the underlying
          RNG is required to generate an single draw.
        * The number of bits required to generate a simulated value
          differs from the number of bits generated by the underlying
          RNG.  For example, two 16-bit integer values can be simulated
          from a single draw of a 32-bit RNG.
        """
        delta = wrap_int(delta, 64)
        pcg32_advance_state(&self.rng_state, <uint64_t>delta)
        return self


