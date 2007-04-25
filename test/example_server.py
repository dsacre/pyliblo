#!/usr/bin/env python

import liblo, sys

# create server, listening on port 1234
try:
    server = liblo.Server(1234)
except liblo.ServerError, err:
    print str(err)
    sys.exit()

def foo_bar_callback(path, args):
    print "received message '%s' with arguments '%d' and '%f'" % (path, args[0], args[1])

def foo_baz_callback(path, args, src, data):
    print "received message '%s'" % path
    print "blob contains %d bytes, user data was '%s'" % (len(args[0]), data)

def fallback(path, args, src):
    print "got unknown message '%s' from '%s'" % (path, src.get_url())

# register method taking an int and a float
server.add_method("/foo/bar", 'if', foo_bar_callback)

# register method taking a blob, and passing user data to the callback
server.add_method("/foo/baz", 'b', foo_baz_callback, "blah")

# register a fallback for unhandled messages
server.add_method(None, None, fallback)

# loop and dispatch messages every 100ms
while True:
    server.recv(100)

