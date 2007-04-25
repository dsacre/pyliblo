#!/usr/bin/env python

import liblo, sys

# send all messages to port 1234 on the local machine
try:
    target = liblo.Address(1234)
except liblo.AddressError, err:
    print str(err)
    sys.exit()

# send message "/foo/message1" with int, float and string arguments
liblo.send(target, "/foo/message1", 123, 456.789, "test")

# send double, int64 and char
liblo.send(target, "/foo/message2", ('d', 3.1415), ('h', 2**42), ('c', 'x'))

# we can also build a message object first...
msg = liblo.Message("/foo/blah")
# ... append arguments later...
msg.add(123, "foo")
# ... and then send it
liblo.send(target, msg)

# send a list of bytes as a blob
blob = [4, 8, 15, 16, 23, 42]
liblo.send(target, "/foo/blob", blob)

