# MsgPack

[![Build Status](https://travis-ci.org/kmsquire/MsgPack.jl.svg?branch=master)](https://travis-ci.org/kmsquire/MsgPack.jl)

Provides basic support for the [msgpack](http://msgpack.org) format.

```
julia> import MsgPack

julia> MsgPack.pack("hi")
3-element Array{Uint8,1}:
 0xa2
 0x68
 0x69

julia> a = MsgPack.pack([1,2,"hi"])
6-element Array{Uint8,1}:
 0x93
 0x01
 0x02
 0xa2
 0x68
 0x69

julia> MsgPack.unpack(Msgpack.pack(4.5))
4.5

julia> f = open("in.mp")
julia> MsgPack.unpack(f)
"hello"

julia> f2 = open("out.mp", "w")
julia> MsgPack.pack(f2, [1,2,"hi"])



```
NOTE: The standard method for encoding integers in msgpack is to use the most compact representation possible, and to encode negative integers as signed ints and non-negative numbers as unsigned ints.

For compatibility with other implementations, I'm following this convention.  On the unpacking side, every integer type becomes an Int64 in Julia, unless it doesn't fit (ie. values greater than 2^63 are unpacked as Uint64).

Unfortunately, this means that type information is potentially lost on a roundtrip of packing and unpacking.  This matters most for Dicts, where, e.g. int64(5) isn't the same key as uint64(5) (i.e. isqual(int64(5), uint64(5)) is false).

I might change this at some point, and/or provide a way to control the unpacked types.
