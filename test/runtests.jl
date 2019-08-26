using Test, MsgPack2

function can_round_trip(value, T,
                        expected_typed_output = value,
                        expected_any_output = value)
    bytes = pack(value)
    return isequal(unpack(bytes, T), expected_typed_output) &&
           isequal(unpack(bytes), expected_any_output)
end

# IntegerType

@test can_round_trip(30, UInt8)
@test can_round_trip(rand(UInt8), UInt8)
@test can_round_trip(rand(UInt16), UInt16)
@test can_round_trip(rand(UInt32), UInt32)
@test can_round_trip(rand(UInt64), UInt64)
@test can_round_trip(-30, Int8)
@test can_round_trip(rand(Int8), Int8)
@test can_round_trip(rand(Int16), Int16)
@test can_round_trip(rand(Int32), Int32)
@test can_round_trip(rand(Int64), Int64)

# NilType

@test can_round_trip(nothing, Nothing)
@test can_round_trip(nothing, Missing, missing, nothing)
@test can_round_trip(missing, Missing, missing, nothing)
@test can_round_trip(missing, Nothing, nothing, nothing)

# BooleanType

@test can_round_trip(true, Bool)
@test can_round_trip(false, Bool)

# FloatType

@test can_round_trip(rand(Float32), Float32)
@test can_round_trip(rand(Float64), Float64)

# StringType

@test can_round_trip(join(rand(Char, 30)), String)
@test can_round_trip(join(rand(Char, typemax(UInt8) - 1)), String)
@test can_round_trip(join(rand(Char, typemax(UInt8) + 1)), String)
@test can_round_trip(join(rand(Char, typemax(UInt16) + 1)), String)

# BinaryType

struct ByteVec
    bytes::Vector{UInt8}
end

Base.:(==)(a::ByteVec, b::ByteVec) = a.bytes == b.bytes

MsgPack2.msgpack_type(::Type{ByteVec}) = MsgPack2.BinaryType()
MsgPack2.to_msgpack(::MsgPack2.BinaryType, x::ByteVec) = x.bytes
MsgPack2.from_msgpack(::Type{ByteVec}, bytes::Vector{UInt8}) = ByteVec(bytes)

bytes = rand(UInt8, typemax(UInt8))
@test can_round_trip(ByteVec(bytes), ByteVec, ByteVec(bytes), bytes)
bytes = rand(UInt8, typemax(UInt8) + 1)
@test can_round_trip(ByteVec(bytes), ByteVec, ByteVec(bytes), bytes)
bytes = rand(UInt8, typemax(UInt16) + 1)
@test can_round_trip(ByteVec(bytes), ByteVec, ByteVec(bytes), bytes)

# TODO: ArrayType
# TODO: MapType
# TODO: ImmutableStructType
# TODO: MutableStructType
