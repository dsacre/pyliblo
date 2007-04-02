#!/usr/bin/env python
# -*- coding: utf-8 -*-

from distutils.core import setup, Extension
try:
    from Pyrex.Distutils import build_ext
except ImportError:
    # no pyrex, build using existing .c file
    kwargs = {
        'ext_modules': [
            Extension('liblo', ['liblo/liblo.c'], libraries = ['lo'])
        ],
    }
else:
    # build with pyrex
    kwargs = {
        'ext_modules': [
            Extension('liblo', ['liblo/liblo.pyx'], libraries = ['lo'])
        ],
        'cmdclass': {
            'build_ext': build_ext
        },
    }

setup(
    name = 'pyliblo',
    version = '0.2',
    author = 'Dominic Sacre',
    author_email = 'dominic.sacre@gmx.de',
    url = 'http://das.nasophon.de/pyliblo/',
    description = 'A Python wrapper for the liblo OSC library',
    license = "GPL",
    scripts = [
        'scripts/send_osc',
        'scripts/dump_osc',
    ],
    **kwargs
)
