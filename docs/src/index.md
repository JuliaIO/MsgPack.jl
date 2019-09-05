# API Documentation

Below is the documentation for all MsgPack2 API functions. For information on MsgPack2, please see [the package's README](https://github.com/beacon-biosignals/MsgPack2.jl).

```@meta
CurrentModule = MsgPack2
```

## Basic Serialization/Deserialization

```@docs
unpack
pack
```

## Julia <--> MessagePack Conversion

```@docs
MsgPack2.msgpack_type
MsgPack2.to_msgpack
MsgPack2.from_msgpack
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
MsgPack2.ArrayView
MsgPack2.MapView
```

## MessagePack Extension Functionality

```@docs
MsgPack2.Extension
MsgPack2.extserialize
MsgPack2.extdeserialize
```
