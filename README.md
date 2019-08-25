# MsgPack2.jl

This is a WIP MsgPack implementation in pure Julia, inspired by [JSON3.jl](https://github.com/quinnj/JSON3.jl) and the original [MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl).

Currently, this package supports:

- basic packing/unpacking (see `pack` and `unpack`)
- overloadable pre-(de)serialization transformations (see `from_msgpack` and `to_msgpack`)
- automatic type construction/destruction (see `msgpack_type`, `ImmutableStructType`, and `MutableStructType`)
- some basic zero-copy immutable "views" over MsgPack-formatted byte buffers (see `ArrayView`, `MapView`).

Things that still need to happen:

- tests
- support for MsgPack extension types
- collaboration with original MsgPack.jl (maybe we will just fold this into there?)
