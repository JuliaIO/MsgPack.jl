# MsgPack2.jl

This is a WIP MsgPack implementation in pure Julia, inspired by [JSON3.jl](https://github.com/quinnj/JSON3.jl) and the original [MsgPack.jl](https://github.com/JuliaIO/MsgPack.jl).

Currently, this package supports:

- basic packing/unpacking
- overloadable pre-(de)serialization definitions via `from_msgpack` and `to_msgpack`.
- automatic type construction/destruction via `msgpack_type`, `ImmutableStructType`, `MutableStructType`, etc.
- some very, *very* basic zero-copy "views" over MsgPack-formatted byte buffers (`ArrayView`, `MapView`).

Things that still need to happen:

- docs
- tests
- MsgPack extension types
- collaboration with original MsgPack.jl (maybe we will just fold this into there?)
