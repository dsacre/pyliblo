#
# pyliblo - A Python wrapper for the liblo OSC library
#
# Copyright (C) 2007  Dominic Sacré  <dominic.sacre@gmx.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#

cdef extern from "stdint.h":
    ctypedef long int32_t
    ctypedef long long int64_t

cdef extern from 'stdlib.h':
    ctypedef unsigned size_t
    void *malloc(size_t size)
    void free(void *ptr)

cdef extern from 'lo/lo.h':
    # type definitions
    ctypedef void* lo_server
    ctypedef void* lo_method
    ctypedef void* lo_address
    ctypedef void* lo_message
    ctypedef void* lo_blob

    ctypedef union lo_arg:
        int32_t i
        int64_t h
        float f
        double d
        unsigned char c
        char s

    ctypedef void(*lo_err_handler)(int num, char *msg, char *where)
    ctypedef int(*lo_method_handler)(char *path, char *types, lo_arg **argv, int argc, lo_message msg, void *user_data)

    # server
    lo_server lo_server_new(char *port, lo_err_handler err_h)
    void lo_server_free(lo_server s)
    char *lo_server_get_url(lo_server s)
    int lo_server_get_port(lo_server s)
    lo_method lo_server_add_method(lo_server s, char *path, char *typespec, lo_method_handler h, void *user_data)
    int lo_server_recv(lo_server s)
    int lo_server_recv_noblock(lo_server s, int timeout)

    # address
    lo_address lo_address_new(char *host, char *port)
    lo_address lo_address_new_from_url(char *url)
    void lo_address_free(lo_address)
    char *lo_address_get_url(lo_address a)
    char *lo_address_get_hostname(lo_address a)
    char *lo_address_get_port(lo_address a)

    # message
    lo_message lo_message_new()
    void lo_message_free(lo_message)
    void lo_message_add_int32(lo_message m, int32_t a)
    void lo_message_add_int64(lo_message m, int64_t a)
    void lo_message_add_float(lo_message m, float a)
    void lo_message_add_double(lo_message m, double a)
    void lo_message_add_char(lo_message m, char a)
    void lo_message_add_string(lo_message m, char *a)
    void lo_message_add_blob(lo_message m, lo_blob a)
    lo_address lo_message_get_source(lo_message m)

    # blob
    lo_blob lo_blob_new(int32_t size, void *data)
    void lo_blob_free(lo_blob b)

    # "global" functions
    int lo_send_message(lo_address targ, char *path, lo_message msg)
    int lo_send_message_from(lo_address targ, lo_server serv, char *path, lo_message msg)


import inspect


def _is_int(s):
    try: int(s)
    except ValueError: return False
    else: return True


class Argument:
    def __init__(self, type, value):
        self.type = type
        self.value = value
    def __getitem__(self, i):
        return (self.type, self.value)[i]


cdef class Address
cdef class Message


################################################################################################
#  Server
################################################################################################

class ServerError:
    def __init__(self, num, msg, where):
        self.num = num
        self.msg = msg
        self.where = where
    def __str__(self):
        s = "server error " + str(self.num)
        if self.where: s = s + " in " + self.where
        s = s + ": " + self.msg
        return s


class _CallbackData:
    def __init__(self, func, data):
        self.func = func
        self.data = data


cdef int _callback(char *path, char *types, lo_arg **argv, int argc, lo_message msg, void *cb_data):
    cdef unsigned char u

    args = []
    for i in range(argc):
        t = chr(types[i])
        if   t == 'i': v = argv[i].i
        elif t == 'h': v = argv[i].h
        elif t == 'f': v = argv[i].f
        elif t == 'd': v = argv[i].d
        elif t == 'c': v = chr(argv[i].c)
        elif t == 's': v = &argv[i].s
        elif t == 'b':
            # convert binary data to python list
            v = []
            size = argv[i].i  # blob size
            for j from 0 <= j < size:
                u = (&argv[i].s + 4)[j]  # blob data, starts at 5th byte
                v.append(u)
        else: v = None  # unhandled data type
        args.append(Argument(t, v))

    src = Address(lo_address_get_url(lo_message_get_source(msg)))

    cb = <object>cb_data
    func_args = (path, args, src, cb.data)

    # number of arguments to call the function with
    n = len(inspect.getargspec(cb.func)[0])
    if inspect.ismethod(cb.func): n = n - 1  # self doesn't count

    cb.func(*func_args[0:n])
    return 0


cdef void _err_handler(int num, char *msg, char *where):
    # can't raise exception in cdef function, so use a global variable instead
    global __exception
    __exception = ServerError(num, msg, None)
    if where: __exception.where = where


cdef class Server:
    cdef lo_server _serv
    cdef object _keep_refs

    def __init__(self, port = None):
        cdef char *cs
        self._keep_refs = []
        p = str(port); cs = p
        if port == None:
            cs = NULL
        global __exception
        __exception = None
        self._serv = lo_server_new(cs, _err_handler)
        if __exception:
            raise __exception

    def __dealloc__(self):
        lo_server_free(self._serv)

    def get_url(self):
        return lo_server_get_url(self._serv)

    def get_port(self):
        return lo_server_get_port(self._serv)

    def add_method(self, path, typespec, func, user_data = None):
        cdef char *p
        cdef char *t

        if isinstance(path, str): p = path
        elif path == None:        p = NULL
        else: raise TypeError("path must be string or None")

        if isinstance(typespec, str): t = typespec
        elif typespec == None:        t = NULL
        else: raise TypeError("typespec must be string or None")

        cb = _CallbackData(func, user_data)
        self._keep_refs.append(cb)
        lo_server_add_method(self._serv, p, t, _callback, <void*>cb)

    def recv(self, timeout = None):
        if timeout:
            r = lo_server_recv_noblock(self._serv, timeout)
            return r and True or False
        else:
            lo_server_recv(self._serv)
            return True

    def send(self, target, msg, *data):
        if isinstance(target, Address):
            a = target
        elif isinstance(target, tuple):
            a = Address(target[0], target[1])
        else:
            a = Address(target)

        if isinstance(msg, Message):
            m = msg
        else:
            m = Message(msg, *data)

        lo_send_message_from((<Address>a)._addr, self._serv, (<Message>m).path, (<Message>m)._msg)


################################################################################################
#  Address
################################################################################################

class AddressError:
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return "address error: " + self.msg


cdef class Address:
    cdef lo_address _addr

    def __init__(self, a, b = None):
        cdef char *cs

        if b:
            # Address("host", port)
            s = str(b); cs = s
            self._addr = lo_address_new(a, cs)
            # assume this cannot fail
        else:
            if isinstance(a, int) or (isinstance(a, str) and _is_int(a)):
                # Address(port)
                s = str(a); cs = s
                self._addr = lo_address_new(NULL, cs)
                # assume this cannot fail
            else:
                # Address("url")
                self._addr = lo_address_new_from_url(a)
                # lo_address_errno() is of no use if self._addr == NULL
                if not self._addr:
                    raise AddressError("invalid URL '" + str(a) + "'")

    def __dealloc__(self):
        lo_address_free(self._addr)

    def get_url(self):
        return lo_address_get_url(self._addr)

    def get_hostname(self):
        return lo_address_get_hostname(self._addr)

    def get_port(self):
        return lo_address_get_port(self._addr)


################################################################################################
#  Message
################################################################################################

cdef class _Blob:
    cdef lo_blob _blob

    def __init__(self, arr):
        # supported types include list, tuple and array('B')
        cdef unsigned char *p
        size = len(arr)
        # copy each element of arr to c array
        p = <unsigned char*>malloc(size)
        for i from 0 <= i < size:
            p[i] = arr[i]
        # build blob
        self._blob = lo_blob_new(size, p)
        free(p)

    def __dealloc__(self):
        lo_blob_free(self._blob)


cdef class Message:
    cdef object path
    cdef lo_message _msg
    cdef object _keep_refs

    def __init__(self, char *path, *data):
        self._keep_refs = []
        self.path = path
        self._msg = lo_message_new()

        for i in data:
            self.add(i)

    def __dealloc__(self):
        lo_message_free(self._msg)

    def add(self, *args):
        cdef char *cs

        # multiple arguments
        if len(args) > 1:
            for a in args:
                self.add(a)
            return

        # single argument...
        arg = args[0]
        if isinstance(arg, tuple) or isinstance(arg, Argument):
            if (arg[0] == 'i'):
                lo_message_add_int32(self._msg, arg[1])
            elif (arg[0] == 'h'):
                lo_message_add_int64(self._msg, arg[1])
            elif (arg[0] == 'f'):
                lo_message_add_float(self._msg, arg[1])
            elif (arg[0] == 'd'):
                lo_message_add_double(self._msg, arg[1])
            elif (arg[0] == 'c'):
                lo_message_add_char(self._msg, ord(arg[1]))
            elif (arg[0] == 's'):
                s = str(arg[1]); cs = s
                lo_message_add_string(self._msg, cs)
            elif (arg[0] == 'b'):
                b = _Blob(arg[1])
                # make sure the blob is not deleted as long as this message exists
                self._keep_refs.append(b)
                lo_message_add_blob(self._msg, (<_Blob>b)._blob)
            else:
                raise TypeError("unknown OSC data type '" + str(arg[0]) + "'")

        elif isinstance(arg, int):
            self.add(('i', arg))
        elif isinstance(arg, float):
            self.add(('f', arg))
        elif isinstance(arg, str):
            self.add(('s', arg))
        else:
            raise TypeError("message argument must be int, float, str or tuple")


################################################################################################
#  global functions
################################################################################################

def send(target, msg, *data):
    if isinstance(target, Address):
        a = target
    elif isinstance(target, tuple):
        a = Address(target[0], target[1])
    else:
        a = Address(target)

    if isinstance(msg, Message):
        m = msg
    else:
        m = Message(msg, *data)

    lo_send_message((<Address>a)._addr, (<Message>m).path, (<Message>m)._msg)
