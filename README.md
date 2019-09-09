# MsgPack.jl

[![Build Status](https://travis-ci.com/JuliaIO/MsgPack.jl.svg?token=Jbjm3zfgVHsfbKqsz3ki&branch=master)](https://travis-ci.com/JuliaIO/MsgPack.jl)
[![Build status](https://ci.appveyor.com/api/projects/status/93qbkbnqh0fn9qr4/branch/master?svg=true)](https://ci.appveyor.com/project/kmsquire/msgpack-jl/branch/master)
[![codecov](https://codecov.io/gh/JuliaIO/MsgPack.jl/branch/master/graph/badge.svg?token=D0bcI0Rtsw)](https://codecov.io/gh/JuliaIO/MsgPack.jl)

[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://JuliaIO.github.io/MsgPack.jl/stable/)
[![](https://img.shields.io/badge/docs-latest-blue.svg)](https://JuliaIO.github.io/MsgPack.jl/latest/)

MsgPack.jl is a MessagePack implementation in pure Julia, inspired by [JSON3.jl](https://github.com/quinnj/JSON3.jl). This package supports:

- (de)serialization of Julia values to/from MessagePack (see `pack` and `unpack`)
- overloadable pre-(de)serialization transformations (see `from_msgpack` and `to_msgpack`)
- automatic type construction/destruction (see `msgpack_type`, `ImmutableStructType`, and `MutableStructType`)
- some basic immutable "views" over MsgPack-formatted byte buffers (see `ArrayView`, `MapView`).
- native `Serialization.serialize` support via MessagePack Extensions (see `Extension`, `extserialize`, and `extdeserialize`)

## `pack`/`unpack`

Use `pack` to serialize Julia values to MessagePack bytes, and `unpack` to deserialize MessagePack bytes to Julia values:

```julia
julia> bytes = pack(["hello", Dict(:this => 1, ['i', 's'] => 3.14, "messagepack!" => nothing)])
42-element Array{UInt8,1}:
 0x92
 0xa5
 0x68
 ⋮

julia> unpack(bytes)
 2-element Array{Any,1}:
  "hello"
  Dict{Any,Any}("messagepack!" => nothing,"this" => 0x01,Any["i", "s"] => 3.14)
```

`pack` and `unpack` also accept IO streams as arguments:

```julia
julia> io = IOBuffer();

julia> pack(io, "see it really does take an IO stream");

julia> unpack(seekstart(io))
"see it really does take an IO stream"
```

## Translating between Julia and MessagePack types

By default, MsgPack defines (de)serialization between the following Julia and MessagePack types:

| MessagePack Type | `AbstractMsgPackType` Subtype | Julia Types                                                              |
|------------------|-------------------------------|--------------------------------------------------------------------------|
| Integer          | `IntegerType`                 | `UInt8`, `UInt16`, `UInt32`, `UInt64`, `Int8`, `Int16`, `Int32`, `Int64` |
| Nil              | `NilType`                     | `Nothing`, `Missing`                                                     |
| Boolean          | `BooleanType`                 | `Bool`                                                                   |
| Float            | `FloatType`                   | `Float32`, `Float64`                                                     |
| String           | `StringType`                  | `AbstractString`, `Char`, `Symbol`                                       |
| Array            | `ArrayType`                   | `AbstractArray`, `AbstractSet`, `Tuple`                                  |
| Map              | `MapType`                     | `AbstractDict`, `NamedTuple`                                             |
| Binary           | `BinaryType`                  | (no defaults)                                                            |
| Extension        | `ExtensionType`               | (no defaults)                                                            |

To support additional Julia types, we can define that type's "translation" to its corresponding `AbstractMsgPackType` via the following methods:

```julia
julia> using MsgPack, UUIDs

# declare `UUID`'s correspondence to the MessagePack String type
julia> MsgPack.msgpack_type(::Type{UUID}) = MsgPack.StringType()

# convert UUIDs to a MessagePack String-compatible representation for serialization
julia> MsgPack.to_msgpack(::MsgPack.StringType, uuid::UUID) = string(uuid)

# convert values deserialized as MessagePack Strings to UUIDs
julia> MsgPack.from_msgpack(::Type{UUID}, uuid::AbstractString) = UUID(uuid)

julia> unpack(pack(uuid4()))
"df416048-e513-41c5-aa49-32623d5d7e1f"

julia> unpack(pack(uuid4()), UUID)
UUID("4812d96f-bc7b-434b-ac54-1985a1263882")
```

Note that each subtype of `AbstractMsgPackType` makes its own assumptions about the return values of `to_msgpack` and `from_msgpack`; these assumptions are documented in the subtype's docstring. For additional details, see the docstrings for `AbstractMsgPackType`, `msgpack_type`, `to_msgpack`, and `from_msgpack`.

## Automatic `struct` (de)serialization

MsgPack substantially copies the approach taken by [JSON3.jl](https://github.com/quinnj/JSON3.jl) to provide an interface that facilitates automatic, performant (de)serialization of MessagePack Maps to/from Julia `struct`s. This interface supports two different possibilities: a slower approach that doesn't depend on field ordering during deserialization, and a faster approach that does.

The slower (but more robust/flexible) approach looks like the following:

```julia
julia> using MsgPack

julia> mutable struct MyMessage
           a::Int
           b::String
           c::Bool
           MyMessage() = new() # this constructor is called during deserialization
           MyMessage(a, b, c) = new(a, b, c)
       end

julia> MsgPack.msgpack_type(::Type{MyMessage}) = MsgPack.MutableStructType()

julia> messages = [MyMessage(rand(Int), join(rand('a':'z', 10)), rand(Bool)) for _ in 1:3]
3-element Array{MyMessage,1}:
 MyMessage(4625239811981161650, "whosayfsvb", true)
 MyMessage(4988660392033153177, "mazsmrsawu", false)
 MyMessage(7955638288702558596, "gueytzhjvy", true)

julia> unpack(pack(messages), Vector{MyMessage})
3-element Array{MyMessage,1}:
 MyMessage(4625239811981161650, "whosayfsvb", true)
 MyMessage(4988660392033153177, "mazsmrsawu", false)
 MyMessage(7955638288702558596, "gueytzhjvy", true)
```

The faster (but heavily constrained) approach looks much the same:

```julia
julia> using MsgPack

julia> struct MyImmutableMessage
           a::Int
           b::String
           c::Bool
       end

julia> MsgPack.msgpack_type(::Type{MyImmutableMessage}) = MsgPack.ImmutableStructType()

julia> imessages = [MyImmutableMessage(rand(Int), join(rand('a':'z', 10)), rand(Bool)) for _ in 1:3]
3-element Array{MyImmutableMessage,1}:
 MyImmutableMessage(3014962033538290449, "rwnumnkqxe", true)
 MyImmutableMessage(2400218223538654838, "ohfzkssphv", true)
 MyImmutableMessage(-6862137169467973847, "zylrifledh", false)

julia> unpack(pack(imessages), Vector{MyImmutableMessage})
3-element Array{MyImmutableMessage,1}:
 MyImmutableMessage(3014962033538290449, "rwnumnkqxe", true)
 MyImmutableMessage(2400218223538654838, "ohfzkssphv", true)
 MyImmutableMessage(-6862137169467973847, "zylrifledh", false)
```

**Do not use `ImmutableStructType` unless you can ensure that the MessagePack Maps you are deserializing maintain the exact same fields in the exact same order as the target `struct`.** This property generally cannot be assumed unless you, yourself, were the original serializer of the message.

For additional details, see the docstrings for `MutableStructType` and `ImmutableStructType`.

## Immutable, lazy Julia views over MessagePack bytes

Often, one will want to delay full deserialization of a MessagePack collection, and instead only deserialize elements upon access. To facilitate this approach, MsgPack provides the `ArrayView` and `MapView` types. Reusing the toy `MyMessage` from the earlier example:

```julia
julia> using BenchmarkTools

julia> bytes = pack([MyMessage(rand(Int), join(rand('a':'z', 10)), rand(Bool)) for _ in 1:10_000_000]);

# deserialize the whole thing in one go
julia> @time x = unpack(bytes, Vector{MyMessage});
  3.547294 seconds (20.00 M allocations: 686.646 MiB, 13.42% gc time)

# scan bytes to tag object positions, but don't fully deserialize
julia> @time v = unpack(bytes, MsgPack.ArrayView{MyMessage});
  0.462374 seconds (14 allocations: 76.295 MiB)

# has normal `Vector` access performance, since it's a normal `Vector`
julia> @btime $x[1]
  1.824 ns (0 allocations: 0 bytes)
MyMessage(-5988715016767300083, "anrcvpbqge", true)

# access time is much slower, since element is deserialized upon access
julia> @btime $v[1]
  274.990 ns (4 allocations: 176 bytes)
MyMessage(-5988715016767300083, "anrcvpbqge", true)
```

For additional details, see the docstrings for `ArrayView` and `MapView`.

## Should I use JSON or MessagePack?

Use JSON by default (with the lovely JSON3 package!), and only switch to MessagePack if you actually measure a significant performance benefit from doing so. In my experience, the main potential advantage of MessagePack is improved (de)serialization performance for certain kinds of structures. If you merely seek to reduce message size, MessagePack has little advantage over JSON, as general-purpose compression seems to achieve similar sizes when applied to either format.
