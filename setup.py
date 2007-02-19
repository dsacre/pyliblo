#!/usr/bin/env python
# -*- coding: utf-8 -*-

from distutils.core import setup, Extension
from Pyrex.Distutils import build_ext

setup(
    name = 'pyliblo',
    version = '0.1',
    author = 'Dominic Sacré',
    author_email = 'dominic.sacre@gmx.de',
    url = 'das.nasophon.de/pyliblo',
    description = 'Python wrapper for the liblo OSC library',
    license = "GPL",
    ext_modules = [
        Extension(
            'liblo',
            ['liblo/liblo.pyx'],
            libraries = ['lo']),
    ],
    cmdclass = {
        'build_ext': build_ext,
    },
    scripts = [
        'scripts/send_osc',
        'scripts/dump_osc',
    ]
)
