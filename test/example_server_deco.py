#!/usr/bin/env python

from liblo import *
import sys

class MyServer(ServerThread):
    def __init__(self):
        ServerThread.__init__(self, 1234)

    @make_method('/foo', 'ifs')
    def foo_callback(self, path, args):
        i, f, s = args
        print "received message '%s' with arguments: %d, %f, %s" % (path, i, f, s)

    @make_method(None, None)
    def fallback(self, path, args):
        print "received unknown message '%s'" % path

try:
    server = MyServer()
except ServerError, err:
    print str(err)
    sys.exit()

server.start()
raw_input("press any key to quit...\n")

