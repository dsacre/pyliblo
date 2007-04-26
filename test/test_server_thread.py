#!/usr/bin/env python

import liblo
import time

st = liblo.ServerThread()
print "Created Server Thread on Port", st.get_port()

def foo_cb(path, args):
    print "foo_cb():"
    for a in args:
        print "received argument %s of type %s" % (a, a.type)

def bar_cb(path, args, src):
    print "bar_cb():"
    print "message from", src.get_url()
    for a in args:
        print "received argument %s of type %s" % (a, a.type)

class Blah:
    def __init__(self, x):
        self.x = x
    def baz_cb(self, path, args, src, user_data):
        print "baz_cb():"
        print args[0]
        print "self.x is", self.x, ", user data was", user_data

st.add_method('/foo', 'ifs', foo_cb)
st.add_method('/bar', 'hdc', bar_cb)

b = Blah(123)
st.add_method('/baz', 'b', b.baz_cb, 456)

st.start()

liblo.send(st.get_port(), "/foo", 123, 456.789, "buh!")
liblo.send(st.get_port(), "/bar", 1234567890123456L, 666, ('c', "x"))

time.sleep(1)
st.stop()
st.start()

liblo.send(st.get_port(), "/baz", [1,2,3,4,5,6,7,8,9,10])

time.sleep(1)
