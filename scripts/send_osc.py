#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (C) 2007-2009  Dominic Sacré  <dominic.sacre@gmx.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#

import sys
import liblo

def send_osc_auto(port, path, *args):
    m = liblo.Message(path)

    for a in args:
        try: v = int(a)
        except ValueError:
            try: v = float(a)
            except ValueError:
                v = a
        m.add(v)

    liblo.send(port, m)


def send_osc_manual(port, path, types, *args):
    if len(types) != len(args):
        sys.exit("length of type string doesn't match number of arguments")

    m = liblo.Message(path)
    try:
        for a, t in zip(args, types):
            m.add((t, a))
    except Exception, e:
        sys.exit(str(e))

    liblo.send(port, m)


if __name__ == '__main__':
    # display help
    if len(sys.argv) == 1 or sys.argv[1] in ("-h", "--help"):
        sys.exit("Usage: " + sys.argv[0] + " port path [,types] [args...]")

    # require at least two arguments (target port/url and message path)
    if len(sys.argv) < 2:
        sys.exit("please specify a port or URL")
    if len(sys.argv) < 3:
        sys.exit("please specify a message path")

    if len(sys.argv) > 3 and sys.argv[3].startswith(','):
        send_osc_manual(sys.argv[1], sys.argv[2], sys.argv[3][1:], *sys.argv[4:])
    else:
        send_osc_auto(*sys.argv[1:])
