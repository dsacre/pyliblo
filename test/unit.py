#!/usr/bin/env python

import unittest
import re
import time
import liblo


class ServerTestCaseBase(unittest.TestCase):
    def setUp(self):
        self.cb = None

    class Arguments:
        def __init__(self, path, args, types, src, data):
            self.path = path
            self.args = args
            self.types = types
            self.src = src
            self.data = data

    def callback(self, path, args, types, src, data):
        self.cb = self.Arguments(path, args, types, src, data)

    def callback_dict(self, path, args, types, src, data):
        if self.cb == None:
            self.cb = { }
        self.cb[path] = self.Arguments(path, args, types, src, data)


class ServerTestCase(ServerTestCaseBase):
    def setUp(self):
        ServerTestCaseBase.setUp(self)
        self.server = liblo.Server('1234')

    def tearDown(self):
        del self.server

    def matchHost(self, host):
        r = re.compile("osc\.udp://.*:1234/")
        return r.match(host) != None

    def approx(self, a, b, e = 0.0002):
        return abs(a - b) < e

    def testPort(self):
        assert self.server.get_port() == 1234

    def testURL(self):
        assert self.matchHost(self.server.get_url())

    def testSendInt(self):
        self.server.add_method('/foo', 'i', self.callback, "data")
        self.server.send('1234', '/foo', 123)
        assert self.server.recv() == True
        assert self.cb.path == '/foo'
        assert self.cb.args[0] == 123
        assert self.cb.types == 'i'
        assert self.cb.data == "data"
        assert self.matchHost(self.cb.src.get_url())

    def testSendBlob(self):
        self.server.add_method('/blob', 'b', self.callback)
        self.server.send('1234', '/blob', [4, 8, 15, 16, 23, 42])
        assert self.server.recv() == True
        assert self.cb.args[0] == [4, 8, 15, 16, 23, 42]

    def testSendVarious(self):
        self.server.add_method('/blah', 'ihfdscb', self.callback)
        self.server.send(1234, '/blah', 123, 2**42, 123.456, 666.666, "hello", ('c', 'x'), (12, 34, 56))
        assert self.server.recv() == True
        assert self.cb.types == 'ihfdscb'
        assert len(self.cb.args) == len(self.cb.types)
        assert self.cb.args[0] == 123
        assert self.cb.args[1] == 2**42
        assert self.approx(self.cb.args[2], 123.456)
        assert self.approx(self.cb.args[3], 666.666)
        assert self.cb.args[4] == "hello"
        assert self.cb.args[5] == 'x'
        assert self.cb.args[6] == [12, 34, 56]

    def testSendOthers(self):
        self.server.add_method('/blubb', 'tmSTFNI', self.callback)
        self.server.send(1234, '/blubb', ('t', 666666.666), ('m', (1, 2, 3, 4)), ('S', 'foo'), True, ('F',), None, ('I',))
        assert self.server.recv() == True
        assert self.cb.types == 'tmSTFNI'
        assert self.approx(self.cb.args[0], 666666.666)
        assert self.cb.args[1] == (1, 2, 3, 4)
        assert self.cb.args[2] == 'foo'
        assert self.cb.args[3] == True
        assert self.cb.args[4] == False
        assert self.cb.args[5] == None
        assert self.cb.args[6] == float('inf')

    def testSendBundle(self):
        self.server.add_method('/foo', 'i', self.callback_dict)
        self.server.add_method('/bar', 's', self.callback_dict)
        self.server.send(1234, liblo.Bundle(
            liblo.Message('/foo', 123),
            liblo.Message('/bar', "blubb"))
        )
        assert self.server.recv(100) == True
        assert self.cb['/foo'].args[0] == 123
        assert self.cb['/bar'].args[0] == "blubb"

    def testSendTimestamped(self):
        self.server.add_method('/blubb', 'i', self.callback)
        d = 1.23
        t1 = time.time()
        b = liblo.Bundle(liblo.time() + d)
        b.add('/blubb', 42)
        self.server.send(1234, b)
        while not self.cb:
            self.server.recv(1)
        t2 = time.time()
        assert self.approx(t2 - t1, d, 0.01)

    def testSendInvalid(self):
        try:
            self.server.send(1234, '/blubb', ('x', 'y'))
        except TypeError, e:
            pass
        else:
            assert False

    def testSendBlobOutOfRange(self):
        try:
            self.server.send(1234, '/blubb', [123, 456, 789])
        except ValueError, e:
            pass
        else:
            assert False

    def testRecvTimeout(self):
        t1 = time.time()
        assert self.server.recv(500) == False
        t2 = time.time()
        assert t2 - t1 < 0.666

    def testRecvImmediate(self):
        t1 = time.time()
        assert self.server.recv(0) == False
        t2 = time.time()
        assert t2 - t1 < 0.01


class ServerCreationTestCase(unittest.TestCase):
    def testNoPermission(self):
        try:
            s = liblo.Server('22')
        except liblo.ServerError, e:
            pass
        else:
            assert False

    def testRandomPort(self):
        s = liblo.Server()
        assert 1024 <= s.get_port() <= 65535


class ServerThreadTestCase(ServerTestCaseBase):
    def setUp(self):
        ServerTestCaseBase.setUp(self)
        self.server = liblo.ServerThread('1234')

    def tearDown(self):
        del self.server

    def testSendAndReceive(self):
        self.server.add_method('/foo', 'i', self.callback)
        self.server.send('1234', '/foo', 42)
        self.server.start()
        time.sleep(0.2)
        self.server.stop()
        assert self.cb.args[0] == 42


if __name__ == "__main__":
    unittest.main()

