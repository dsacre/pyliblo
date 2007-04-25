#!/usr/bin/env python

import liblo
import time

st = liblo.ServerThread()
print "Created Server Thread on Port", st.get_port()

def foo_cb(path, args):
    print "foo_cb():"
    for a in args:
        print "received argument %s of type %s" % (a, a.type)

def bar_cb(path, args, src, user_data):
    print "bar_cb():"
    print "message from", src.get_url()
    for a in args:
        print "received argument %s of type %s" % (a, a.type)

def baz_cb(path, args):
    print "baz_cb():"
    print args[0]

st.add_method('/foo', 'ifs', foo_cb)
st.add_method('/bar', 'hdc', bar_cb)
st.add_method('/baz', 'b',   baz_cb)

st.start()

liblo.send(st.get_port(), "/foo", 123, 456.789, "buh!")
liblo.send(st.get_port(), "/bar", 1234567890123456L, 666, ('c', "x"))
liblo.send(st.get_port(), "/baz", [1,2,3,4,5,6,7,8,9,10])

time.sleep(1)
