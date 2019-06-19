#!/usr/bin/env python
"""
BitGenerators for numpy.random.Generator

A collection of BitGenerators that can be plugged in:

import numpy
import bitgenerators
g = numpy.random.Generator(bitgenerators.Philox(1234))
data = g.random(1000)

python 3.6+ only.
"""

import sys
import os
import re
import io
from glob import glob
from os.path import basename
from os.path import dirname
from os.path import join
from os.path import relpath
from os.path import splitext

from setuptools import Extension
from setuptools import find_packages
from setuptools import setup


if sys.version_info[:2] < (3, 6):
    raise RuntimeError("Python version >= 3.6 required.")

CLASSIFIERS = """\
Development Status :: 1 - Alpha
Intended Audience :: Science/Research
Intended Audience :: Developers
License :: OSI Approved
Programming Language :: C
Programming Language :: Python
Programming Language :: Python :: 3
Programming Language :: Python :: 3.6
Programming Language :: Python :: 3.7
Programming Language :: Python
Topic :: Software Development
Topic :: Scientific/Engineering
Operating System :: Microsoft :: Windows
Operating System :: POSIX
Operating System :: Unix
Operating System :: MacOS
"""

MAJOR               = 0
MINOR               = 0
MICRO               = 0
ISRELEASED          = False
VERSION             = '%d.%d.%d' % (MAJOR, MINOR, MICRO)

# Return the git revision as a string
def git_version():
    def _minimal_ext_cmd(cmd):
        # construct minimal environment
        env = {}
        for k in ['SYSTEMROOT', 'PATH', 'HOME']:
            v = os.environ.get(k)
            if v is not None:
                env[k] = v
        # LANGUAGE is used on win32
        env['LANGUAGE'] = 'C'
        env['LANG'] = 'C'
        env['LC_ALL'] = 'C'
        out = subprocess.check_output(cmd, stderr=subprocess.STDOUT, env=env)
        return out

    try:
        out = _minimal_ext_cmd(['git', 'rev-parse', 'HEAD'])
        GIT_REVISION = out.strip().decode('ascii')
    except (subprocess.SubprocessError, OSError):
        GIT_REVISION = "Unknown"

    return GIT_REVISION

# BEFORE importing setuptools, remove MANIFEST. Otherwise it may not be
# properly updated when the contents of directories change (true for distutils,
# not sure about setuptools).
if os.path.exists('MANIFEST'):
    os.remove('MANIFEST')

def write_version_py(filename='numpy/version.py'):
    cnt = """
# THIS FILE IS GENERATED FROM NUMPY SETUP.PY
#
# To compare versions robustly, use `numpy.lib.NumpyVersion`
short_version = '%(version)s'
version = '%(version)s'
full_version = '%(full_version)s'
git_revision = '%(git_revision)s'
release = %(isrelease)s

if not release:
    version = full_version
"""
    FULLVERSION, GIT_REVISION = get_version_info()

    a = open(filename, 'w')
    try:
        a.write(cnt % {'version': VERSION,
                       'full_version': FULLVERSION,
                       'git_revision': GIT_REVISION,
                       'isrelease': str(ISRELEASED)})
    finally:
        a.close()

try:
    # Allow installing package without any Cython available. This
    # assumes you are going to include the .c files in your sdist.
    import Cython
except ImportError:
    Cython = None

def read(*names, **kwargs):
    with io.open(
        join(dirname(__file__), *names),
        encoding=kwargs.get('encoding', 'utf8')
    ) as fh:
        return fh.read()

setup(
    name='bitgenerators',
    version='0.0.0',
    license='BSD license',
    description='BitGenerators for numpy.random.Generators',
    long_description='%s' % (
        re.compile('^.. start-badges.*^.. end-badges', re.M | re.S).sub('', read('README.md')),
    ),
    author='Numpy Developers',
    author_email='info@numpy.org',
    url='https://github.com/numpy/bitgenerators',
    packages=find_packages('bitgenerators'),
    package_dir={'': 'bitgenerators'},
    py_modules=[splitext(basename(path))[0] for path in glob('bitgenerators/*.py')],
    include_package_data=True,
    zip_safe=False,
    classifiers=[_f for _f in CLASSIFIERS.split('\n') if _f],
    project_urls={
        'Documentation': 'https://bitgenerators.readthedocs.io/',
        'Changelog': 'https://bitgenerators.readthedocs.io/en/latest/changelog.html',
        'Issue Tracker': 'https://github.com/numpy/bitgenerators/issues',
    },
    keywords=[
        # eg: 'keyword1', 'keyword2', 'keyword3',
    ],
    python_requires='>=3.6',
    install_requires=[
        'numpy>=1.17.0',
    ],
    extras_require={
        # eg:
        #   'rst': ['docutils>=0.11'],
        #   ':python_version=="2.6"': ['argparse'],
    },
    setup_requires=[
        'cython',
    ] if Cython else [],
    ext_modules=[
        Extension(
            splitext(relpath(path, 'bitgenerators').replace(os.sep, '.'))[0],
            sources=[path],
            include_dirs=[dirname(path)]
        )
        for root, _, _ in os.walk('bitgenerators')
        for path in glob(join(root, '*.pyx' if Cython else '*.c'))
    ],
)
