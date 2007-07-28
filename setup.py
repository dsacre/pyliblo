#!/usr/bin/env python
# -*- coding: utf-8 -*-

from distutils.core import setup, Extension
from distutils.command.build_scripts import build_scripts
from distutils import util
import os

try:
    from Pyrex.Distutils import build_ext
except ImportError:
    # no pyrex, build using existing .c file
    kwargs = {
        'ext_modules': [
            Extension('liblo', ['src/liblo.c'], libraries = ['lo'])
        ],
        'cmdclass': {
        }
    }
else:
    # build with pyrex
    kwargs = {
        'ext_modules': [
            Extension('liblo', ['src/liblo.pyx'], libraries = ['lo'])
        ],
        'cmdclass': {
            'build_ext': build_ext
        }
    }

class build_scripts_rename(build_scripts):
    def copy_scripts(self):
        build_scripts.copy_scripts(self)
        # remove the .py extension from scripts
        for s in self.scripts:
            f = util.convert_path(s)
            before = os.path.join(self.build_dir, os.path.basename(f))
            after = os.path.splitext(before)[0]
            print "renaming", before, "->", after
            os.rename(before, after)

kwargs['cmdclass']['build_scripts'] = build_scripts_rename

setup (
    name = 'pyliblo',
    version = '0.6.2',
    author = 'Dominic Sacre',
    author_email = 'dominic.sacre@gmx.de',
    url = 'http://das.nasophon.de/pyliblo/',
    description = 'A Python wrapper for the liblo OSC library',
    license = "GPL",
    scripts = [
        'scripts/send_osc.py',
        'scripts/dump_osc.py',
    ],
    **kwargs
)
