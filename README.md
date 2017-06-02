# MsgPack

[![Build Status](https://travis-ci.org/JuliaIO/MsgPack.jl.svg?branch=master)](https://travis-ci.org/JuliaIO/MsgPack.jl)

[![Build status](https://ci.appveyor.com/api/projects/status/93qbkbnqh0fn9qr4/branch/master?svg=true)](https://ci.appveyor.com/project/kmsquire/msgpack-jl/branch/master)

[![Coverage Status](https://coveralls.io/repos/JuliaIO/MsgPack.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/JuliaIO/MsgPack.jl?branch=master)

[![codecov.io](http://codecov.io/github/JuliaIO/MsgPack.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaIO/MsgPack.jl?branch=master)

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

julia> MsgPack.unpack(MsgPack.pack(4.5))
4.5

julia> f = open("in.mp")
julia> MsgPack.unpack(f)
"hello"

julia> f2 = open("out.mp", "w")
julia> MsgPack.pack(f2, [1,2,"hi"])



```
NOTE: The standard method for encoding integers in msgpack is to use the most compact representation possible, and to encode negative integers as signed ints and non-negative numbers as unsigned ints.

For compatibility with other implementations, I'm following this convention.  On the unpacking side, every integer type becomes an Int64 in Julia, unless it doesn't fit (ie. values greater than 2^63 are unpacked as Uint64).

I might change this at some point, and/or provide a way to control the unpacked types.

### The Extension Type

The MsgPack spec [defines](https://github.com/msgpack/msgpack/blob/master/spec.md#formats-ext) the [extension type](https://github.com/msgpack/msgpack/blob/master/spec.md#types-extension-type) to be a tuple of `(typecode, bytearray)` where `typecode` is an application-specific identifier for the data in `bytearray`. MsgPack.jl provides support for the extension type through the `Ext` immutable.

It is defined like so

```julia
immutable Ext
    typecode::Int8
    data::Vector{Uint8}
end
```

and used like this

```julia
julia> a = [0x34, 0xff, 0x76, 0x22, 0xd3, 0xab]
6-element Array{UInt8,1}:
 0x34
 0xff
 0x76
 0x22
 0xd3
 0xab

julia> b = Ext(22, a)
MsgPack.Ext(22,UInt8[0x34,0xff,0x76,0x22,0xd3,0xab])

julia> p = pack(b)
9-element Array{UInt8,1}:
 0xc7
 0x06
 0x16
 0x34
 0xff
 0x76
 0x22
 0xd3
 0xab

julia> c = unpack(p)
MsgPack.Ext(22,UInt8[0x34,0xff,0x76,0x22,0xd3,0xab])

julia> c == b
true
```

MsgPack reserves typecodes in the range `[-128, -1]` for future types specified by the MsgPack spec. MsgPack.jl enforces this when creating an `Ext` but if you are packing an implementation defined extension type (currently there are none) you can pass `impltype=true`.

```julia
julia> Ext(-43, Uint8[1, 5, 3, 9])
ERROR: MsgPack Ext typecode -128 through -1 reserved by implementation
 in call at /Users/sean/.julia/v0.4/MsgPack/src/MsgPack.jl:48

julia> Ext(-43, Uint8[1, 5, 3, 9], impltype=true)
MsgPack.Ext(-43,UInt8[0x01,0x05,0x03,0x09])
```

#### Serialization

MsgPack.jl also defines the `extserialize` and `extdeserialize` convenience functions. These functions can turn an arbitrary object into an `Ext` and vice-versa.

```julia
julia> type Point{T}
        x::T
        y::T
       end

julia> r = Point(2.5, 7.8)
Point{Float64}(2.5,7.8)

julia> e = MsgPack.extserialize(123, r)
MsgPack.Ext(123,UInt8[0x11,0x01,0x02,0x05,0x50,0x6f,0x69,0x6e,0x74,0x23  …  0x40,0x0e,0x33,0x33,0x33,0x33,0x33,0x33,0x1f,0x40])

julia> s = MsgPack.extdeserialize(e)
(123,Point{Float64}(2.5,7.8))

julia> s[2]
Point{Float64}(2.5,7.8)

julia> r
Point{Float64}(2.5,7.8)
```

Since these functions use [`serialize`](http://docs.julialang.org/en/latest/stdlib/base/#Base.serialize) under the hood they are subject to the following caveat.

> In general, this process will not work if the reading and writing are done by
> different versions of Julia, or an instance of Julia with a different system
> image.
