#
# pyliblo - Python bindings for the liblo OSC library
#
# Copyright (C) 2007-2009  Dominic Sacré  <dominic.sacre@gmx.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of the
# License, or (at your option) any later version.
#

__version__ = '0.8.0'


cdef extern from 'stdint.h':
    ctypedef long int32_t
    ctypedef unsigned long uint32_t
    ctypedef long long int64_t
    ctypedef unsigned char uint8_t

cdef extern from *:
    ctypedef char * const_char_ptr 'const char *'

cdef extern from 'stdlib.h':
    ctypedef unsigned size_t
    void *malloc(size_t size)
    void free(void *ptr)

cdef extern from 'math.h':
    double modf(double x, double *iptr)

cdef extern from 'Python.h':
    void PyEval_InitThreads()
    ctypedef void *PyGILState_STATE
    PyGILState_STATE PyGILState_Ensure()
    void PyGILState_Release(PyGILState_STATE)

cdef extern from 'lo/lo.h':
    # type definitions
    ctypedef void *lo_server
    ctypedef void *lo_server_thread
    ctypedef void *lo_method
    ctypedef void *lo_address
    ctypedef void *lo_message
    ctypedef void *lo_blob
    ctypedef void *lo_bundle

    ctypedef struct lo_timetag:
        uint32_t sec
        uint32_t frac

    ctypedef union lo_arg:
        int32_t i
        int64_t h
        float f
        double d
        unsigned char c
        char s
        uint8_t m[4]
        lo_timetag t

    cdef enum:
        LO_DEFAULT  = 0x0
        LO_UDP      = 0x1
        LO_UNIX     = 0x2
        LO_TCP      = 0x4

    ctypedef void(*lo_err_handler)(int num, const_char_ptr msg, const_char_ptr where)
    ctypedef int(*lo_method_handler)(const_char_ptr path, const_char_ptr types, lo_arg **argv, int argc, lo_message msg, void *user_data)

    # send
    int lo_send_message_from(lo_address targ, lo_server serv, char *path, lo_message msg)
    int lo_send_bundle_from(lo_address targ, lo_server serv, lo_bundle b)

    # server
    lo_server lo_server_new_with_proto(char *port, int proto, lo_err_handler err_h)
    void lo_server_free(lo_server s)
    char *lo_server_get_url(lo_server s)
    int lo_server_get_port(lo_server s)
    lo_method lo_server_add_method(lo_server s, char *path, char *typespec, lo_method_handler h, void *user_data)
    int lo_server_recv(lo_server s)
    int lo_server_recv_noblock(lo_server s, int timeout)

    # server thread
    lo_server_thread lo_server_thread_new_with_proto(char *port, int proto, lo_err_handler err_h)
    void lo_server_thread_free(lo_server_thread st)
    lo_server lo_server_thread_get_server(lo_server_thread st)
    void lo_server_thread_start(lo_server_thread st)
    void lo_server_thread_stop(lo_server_thread st)

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
    void lo_message_add_symbol(lo_message m, char *a)
    void lo_message_add_true(lo_message m)
    void lo_message_add_false(lo_message m)
    void lo_message_add_nil(lo_message m)
    void lo_message_add_infinitum(lo_message m)
    void lo_message_add_midi(lo_message m, uint8_t a[4])
    void lo_message_add_timetag(lo_message m, lo_timetag a)
    void lo_message_add_blob(lo_message m, lo_blob a)
    lo_address lo_message_get_source(lo_message m)

    # blob
    lo_blob lo_blob_new(int32_t size, void *data)
    void lo_blob_free(lo_blob b)
    void *lo_blob_dataptr(lo_blob b)
    uint32_t lo_blob_datasize(lo_blob b)

    # bundle
    lo_bundle lo_bundle_new(lo_timetag tt)
    void lo_bundle_free(lo_bundle b)
    void lo_bundle_add_message(lo_bundle b, char *path, lo_message m)

    # timetag
    void lo_timetag_now(lo_timetag *t)


import inspect as _inspect
import weakref as _weakref
import new as _new

class _weakref_method:
    def __init__(self, f):
        self.f = f.im_func
        self.c = _weakref.ref(f.im_self)
    def __call__(self, *args):
        return _new.instancemethod(self.f, self.c(), self.c().__class__)


cdef class _ServerBase
cdef class Address
cdef class Message
cdef class Bundle


################################################################################################
#  timetag
################################################################################################

cdef lo_timetag _double_to_timetag(double f):
    cdef lo_timetag tt
    cdef double intr, frac
    frac = modf(f, &intr)
    tt.sec = <uint32_t>intr
    tt.frac = <uint32_t>(frac * 4294967296.0)
    return tt

cdef double _timetag_to_double(lo_timetag tt):
    return <double>tt.sec + (<double>(tt.frac) / 4294967296.0)

def time():
    cdef lo_timetag tt
    lo_timetag_now(&tt)
    return _timetag_to_double(tt)


################################################################################################
#  send
################################################################################################

def _send(target, src, *msg):
    cdef lo_server serv

    if isinstance(target, Address):
        addr = target
    elif isinstance(target, tuple):
        addr = Address(target[0], target[1])
    else:
        addr = Address(target)

    if not isinstance(msg[0], (Message, Bundle)):
        # treat arguments as one single message
        msg = [Message(*msg)]

    if src:
        serv = (<_ServerBase>src)._serv
    else:
        serv = NULL

    for m in msg:
        if isinstance(m, Message):
            lo_send_message_from((<Address>addr)._addr, serv, (<Message>m)._path, (<Message>m)._msg)
        else:
            lo_send_bundle_from((<Address>addr)._addr, serv, (<Bundle>m)._bundle)


def send(target, *msg):
    _send(target, None, *msg)


################################################################################################
#  Server
################################################################################################

UDP  = LO_UDP
TCP  = LO_TCP
UNIX = LO_UNIX


class ServerError(Exception):
    def __init__(self, num, msg, where):
        self.num = num
        self.msg = msg
        self.where = where
    def __str__(self):
        s = "server error %d" % self.num
        if self.where: s += " in %s" % self.where
        s += ": %s" % self.msg
        return s


class _CallbackData:
    def __init__(self, func, data):
        self.func = func
        self.data = data


cdef int _callback(const_char_ptr path, const_char_ptr types, lo_arg **argv, int argc, lo_message msg, void *cb_data):
    cdef unsigned char *ptr
    cdef uint32_t size, j
    cdef char *url
    args = []

    for i from 0 <= i < argc:
        t = chr(types[i])
        if   t == 'i': v = argv[i].i
        elif t == 'h': v = argv[i].h
        elif t == 'f': v = argv[i].f
        elif t == 'd': v = argv[i].d
        elif t == 'c': v = chr(argv[i].c)
        elif t == 's': v = &argv[i].s
        elif t == 'S': v = &argv[i].s
        elif t == 'T': v = True
        elif t == 'F': v = False
        elif t == 'N': v = None
        elif t == 'I': v = float('inf')
        elif t == 'm': v = (argv[i].m[0], argv[i].m[1], argv[i].m[2], argv[i].m[3])
        elif t == 't': v = _timetag_to_double(argv[i].t)
        elif t == 'b':
            # convert binary data to python list
            v = []
            ptr = <unsigned char*>lo_blob_dataptr(argv[i])
            size = lo_blob_datasize(argv[i])
            for j from 0 <= j < size:
                v.append(ptr[j])
        else:
            v = None  # unhandled data type

        args.append(v)

    url = lo_address_get_url(lo_message_get_source(msg))
    src = Address(url)
    free(url)

    cb = <object>cb_data
    if isinstance(cb.func, _weakref_method):
        func = cb.func()
    else:
        func = cb.func
    func_args = (path, args, types, src, cb.data)

    # call function
    if _inspect.getargspec(func)[1] == None:
        # determine number of arguments to call the function with
        n = len(_inspect.getargspec(func)[0])
        if _inspect.ismethod(func): n = n - 1  # self doesn't count
        r = func(*func_args[0:n])
    else:
        # function has argument list, pass all arguments
        r = func(*func_args)

    if r == None:
        return 0
    else:
        return r


cdef int _callback_threaded(const_char_ptr path, const_char_ptr types, lo_arg **argv, int argc, lo_message msg, void *cb_data):
    cdef PyGILState_STATE gil

    # acquire the global interpreter lock
    gil = PyGILState_Ensure()
    # call the regular callback function.
    # this can't raise an exception, so it's safe to rely on the GIL to be released
    _callback(path, types, argv, argc, msg, cb_data)
    PyGILState_Release(gil)
    return 0


cdef void _err_handler(int num, const_char_ptr msg, const_char_ptr where):
    # can't raise exception in cdef function, so use a global variable instead
    global __exception
    __exception = ServerError(num, msg, None)
    if where: __exception.where = where


# decorator to register callbacks

class make_method:
    # counter to keep track of the order in which the callback functions where defined
    _counter = 0

    def __init__(self, path, types, user_data=None):
        self.spec = (make_method._counter, path, types, user_data)
        make_method._counter += 1

    def __call__(self, f):
        # we can't access the Server object here, because at the time the decorator is run it
        # doesn't even exist yet. so we store the path/typespec in the function object instead...
        if not hasattr(f, '_method_spec'):
            f._method_spec = []
        f._method_spec.append(self.spec)
        return f


# common base class for both Server and ServerThread

cdef class _ServerBase:
    cdef lo_server _serv
    cdef lo_method_handler _cb_func
    cdef object _keep_refs

    def __init__(self, **kwargs):
        self._keep_refs = []

        if not kwargs.has_key('reg_methods') or kwargs['reg_methods']:
            self.register_methods()

    def register_methods(self, obj=None):
        if obj == None:
            obj = self
        # find and register methods that were defined using decorators
        methods = []
        for m in _inspect.getmembers(obj):
            if hasattr(m[1], '_method_spec'):
                for s in m[1]._method_spec:
                    methods.append((s, m[1]))
        # sort by counter (first element in each tuple)
        methods.sort()
        for e in methods:
            self.add_method(e[0][1], e[0][2], e[1], e[0][3])

    def get_url(self):
        cdef char *tmp
        tmp = lo_server_get_url(self._serv)
        r = tmp
        free(tmp)
        return r

    def get_port(self):
        return lo_server_get_port(self._serv)

    def add_method(self, path, typespec, func, user_data=None):
        cdef char *p
        cdef char *t

        if isinstance(path, str): p = path
        elif path == None:        p = NULL
        else: raise TypeError("path must be a string or None")

        if isinstance(typespec, str): t = typespec
        elif typespec == None:        t = NULL
        else: raise TypeError("typespec must be a string or None")

        # use a weak reference if func is a method, to avoid circular references in
        # cases where func is a method an object that also has a reference to the server
        # (e.g. when deriving from the Server class)
        if _inspect.ismethod(func):
            func = _weakref_method(func)

        cb = _CallbackData(func, user_data)
        self._keep_refs.append(cb)
        lo_server_add_method(self._serv, p, t, self._cb_func, <void*>cb)

    def send(self, target, *msg):
        _send(target, self, *msg)


cdef class Server(_ServerBase):
    def __init__(self, port=None, proto=LO_DEFAULT, **kwargs):
        cdef char *cs

        if port != None:
            p = str(port); cs = p
        else:
            cs = NULL

        global __exception
        __exception = None
        self._serv = lo_server_new_with_proto(cs, proto, _err_handler)
        if __exception:
            raise __exception

        self._cb_func = _callback
        _ServerBase.__init__(self, **kwargs)

    def __dealloc__(self):
        lo_server_free(self._serv)

    def recv(self, timeout=None):
        if timeout != None:
            r = lo_server_recv_noblock(self._serv, timeout)
            return r and True or False
        else:
            lo_server_recv(self._serv)
            return True


cdef class ServerThread(_ServerBase):
    cdef lo_server_thread _thread

    def __init__(self, port=None, proto=LO_DEFAULT, **kwargs):
        cdef char *cs

        if port != None:
            p = str(port); cs = p
        else:
            cs = NULL

        # make sure python can handle threading
        PyEval_InitThreads()

        global __exception
        __exception = None
        self._thread = lo_server_thread_new_with_proto(cs, proto, _err_handler)
        if __exception:
            raise __exception
        self._serv = lo_server_thread_get_server(self._thread)

        self._cb_func = _callback_threaded
        _ServerBase.__init__(self, **kwargs)

    def __dealloc__(self):
        lo_server_thread_free(self._thread)

    def start(self):
        lo_server_thread_start(self._thread)

    def stop(self):
        lo_server_thread_stop(self._thread)


################################################################################################
#  Address
################################################################################################

class AddressError(Exception):
    def __init__(self, msg):
        self.msg = msg
    def __str__(self):
        return "address error: %s" % self.msg


cdef class Address:
    cdef lo_address _addr

    def __init__(self, a, b=None):
        cdef char *cs

        if b:
            # Address("host", port)
            s = str(b); cs = s
            self._addr = lo_address_new(a, cs)
            # assume this cannot fail
        else:
            if isinstance(a, int) or (isinstance(a, str) and a.isdigit()):
                # Address(port)
                s = str(a); cs = s
                self._addr = lo_address_new(NULL, cs)
                # assume this cannot fail
            else:
                # Address("url")
                self._addr = lo_address_new_from_url(a)
                # lo_address_errno() is of no use if self._addr == NULL
                if not self._addr:
                    raise AddressError("invalid URL '%s'" % str(a))

    def __dealloc__(self):
        lo_address_free(self._addr)

    def get_url(self):
        cdef char *tmp
        tmp = lo_address_get_url(self._addr)
        r = tmp
        free(tmp)
        return r

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
        # arr can by any sequence type
        cdef unsigned char *p
        cdef uint32_t size, i
        size = len(arr)
        if size < 1:
            raise ValueError("blob is empty")
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
    cdef object _path
    cdef lo_message _msg
    cdef object _keep_refs

    def __init__(self, char *path, *args):
        self._keep_refs = []
        self._path = path
        self._msg = lo_message_new()

        self.add(*args)

    def __dealloc__(self):
        lo_message_free(self._msg)

    def add(self, *args):
        for arg in args:
            if isinstance(arg, tuple) and len(arg) <= 2 and isinstance(arg[0], str) and len(arg[0]) == 1:
                # type explicitly specified
                if len(arg) == 2:
                    self._add(arg[0], arg[1])
                else:
                    self._add(arg[0], None)
            else:
                # detect type automatically
                self._add_auto(arg)

    def _add(self, t, v):
        cdef char *cs
        cdef uint8_t midi[4]

        if t == 'i':
            lo_message_add_int32(self._msg, int(v))
        elif t == 'h':
            lo_message_add_int64(self._msg, long(v))
        elif t == 'f':
            lo_message_add_float(self._msg, float(v))
        elif t == 'd':
            lo_message_add_double(self._msg, float(v))
        elif t == 'c':
            lo_message_add_char(self._msg, ord(v))
        elif t == 's':
            s = str(v); cs = s
            lo_message_add_string(self._msg, cs)
        elif t == 'S':
            s = str(v); cs = s
            lo_message_add_symbol(self._msg, cs)
        elif t == 'T':
            lo_message_add_true(self._msg)
        elif t == 'F':
            lo_message_add_false(self._msg)
        elif t == 'N':
            lo_message_add_nil(self._msg)
        elif t == 'I':
            lo_message_add_infinitum(self._msg)
        elif t == 'm':
            for n from 0 <= n < 4:
                midi[n] = v[n]
            lo_message_add_midi(self._msg, midi)
        elif t == 't':
            lo_message_add_timetag(self._msg, _double_to_timetag(v))
        elif t == 'b':
            b = _Blob(v)
            # make sure the blob is not deleted as long as this message exists
            self._keep_refs.append(b)
            lo_message_add_blob(self._msg, (<_Blob>b)._blob)
        else:
            raise TypeError("unknown OSC data type '%s'" % str(t))

    def _add_auto(self, arg):
        # bool is a subclass of int, so check those first
        if arg is True:
            self._add('T', None)
        elif arg is False:
            self._add('F', None)
        elif isinstance(arg, int):
            self._add('i', arg)
        elif isinstance(arg, long):
            self._add('h', arg)
        elif isinstance(arg, float):
            self._add('f', arg)
        elif isinstance(arg, str):
            self._add('s', arg)
        elif arg == None:
            self._add('N', None)
        elif arg == float('inf'):
            self._add('I', None)
        else:
            # last chance: could be a blob
            try:
                iter(arg)
            except TypeError:
                raise TypeError("unsupported message argument type")
            self._add('b', arg)


################################################################################################
#  Bundle
################################################################################################

cdef class Bundle:
    cdef lo_bundle _bundle
    cdef object _keep_refs

    def __init__(self, *msgs):
        cdef lo_timetag tt
        tt.sec, tt.frac = 0, 0
        self._keep_refs = []

        if len(msgs) and not isinstance(msgs[0], Message):
            t = msgs[0]
            if isinstance(t, (float, int, long)):
                tt = _double_to_timetag(t)
            elif isinstance(t, tuple) and len(t) == 2:
                tt.sec, tt.frac = t
            else:
                raise TypeError("invalid timetag")
            # first argument was timetag, so continue with second
            msgs = msgs[1:]

        self._bundle = lo_bundle_new(tt)
        if len(msgs):
            self.add(*msgs)

    def __dealloc__(self):
        lo_bundle_free(self._bundle)

    def add(self, *msgs):
        if isinstance(msgs[0], Message):
            # arguments are message objects
            for m in msgs:
                self._keep_refs.append(m)
                lo_bundle_add_message(self._bundle, (<Message>m)._path, (<Message>m)._msg)
        else:
            # arguments are one single message
            m = Message(*msgs)
            self._keep_refs.append(m)
            lo_bundle_add_message(self._bundle, (<Message>m)._path, (<Message>m)._msg)
