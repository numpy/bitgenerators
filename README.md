# BitGenerators for `numpy.random.Generator`

The NumPy random number generator accepts a BitGenerator that provides
a bitstream. This package provides a variety of BitGenerators.

* MT19937 - The standard Python BitGenerator. Produces identical results to
  Python using the same seed/state. Adds a MT19937.jumped function
  that returns a new generator with state as-if ``2**128`` draws have been made.
* `DSFMT - SSE2 enabled versions of the MT19937 generator. Probably behind as
  many papers as any other generator. Good performance on any CPU with SSE2 or
  Altivec. See the [dSFMT authors'
  page](http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/SFMT/).
* Xoshiro256 and Xoshiro512 - The most recently introduced XOR, shift, and
  rotate generator. Fast and popular bit generator, despite some reservations
  in rare corner cases. More information about these bit generators is
  available at the xorshift, xoroshiro and xoshiro [authors'
  page](http://xoroshiro.di.unimi.it).
* ThreeFry and Philox - counter-based generators capable of being advanced an
  arbitrary number of steps or generating independent streams. Very popular in
  machine learning. See the [Random123
  page](https://www.deshawresearch.com/resources_random123.html) for more
  details about this class of bit generators.
* PCG32 and PCG64 are permutation-congruential generators with very good
  statistical properties.  More information is available on the [PCG authors'
  page](http://www.pcg-random.org/).
* GJrand, SFC64, JSF64 - Fast chaotic 256-bit BitGenerators architected fairly
  similarly, based on random invertible mappings. They are very well-tested.
  JSF64 has been analyzed for a long time. SFC64 seems to be inspired by that
  work; it was written by the author of
  [PractRand](http://pracrand.sourceforge.net/) so it too has been pretty
  thoroughly tested.

## Installation from source

`pip install .`


## Building
`
`python setup.py bdist_wheel`
Then upload the wheel


## Testing
```
pip install . --target /tmp/tmpsite
PYTHONPATH=/tmp/tmpsite pytest tests
```
