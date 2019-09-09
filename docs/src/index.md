# API Documentation

Below is the documentation for all MsgPack API functions. For information on MsgPack, please see [the package's README](https://github.com/JuliaIO/MsgPack.jl).

```@meta
CurrentModule = MsgPack
```

## Basic Serialization/Deserialization

```@docs
unpack
pack
```

## Julia <--> MessagePack Conversion

```@docs
MsgPack.msgpack_type
MsgPack.to_msgpack
MsgPack.from_msgpack
```

## Julia <--> MessagePack Interface Types

```@docs
AbstractMsgPackType
IntegerType
NilType
BooleanType
FloatType
StringType
BinaryType
ArrayType
MapType
ExtensionType
AnyType
ImmutableStructType
MutableStructType
```

## View Types

```@docs
MsgPack.ArrayView
MsgPack.MapView
```

## MessagePack Extension Functionality

```@docs
MsgPack.Extension
MsgPack.extserialize
MsgPack.extdeserialize
```
