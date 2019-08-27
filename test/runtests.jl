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
@test can_round_trip(-30, Int8)
@test can_round_trip(typemax(UInt8), UInt8)
@test can_round_trip(typemax(UInt16), UInt16)
@test can_round_trip(typemax(UInt32), UInt32)
@test can_round_trip(typemax(UInt64), UInt64)
@test can_round_trip(typemax(Int8), Int8)
@test can_round_trip(typemin(Int8), Int8)
@test can_round_trip(typemax(Int16), Int16)
@test can_round_trip(typemin(Int16), Int16)
@test can_round_trip(typemax(Int32), Int32)
@test can_round_trip(typemin(Int32), Int32)
@test can_round_trip(typemax(Int64), Int64)
@test can_round_trip(typemin(Int64), Int64)

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

@test can_round_trip(join(rand(Char, 9)), String)
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

# ArrayType

arr = [30, -30, typemax(UInt8), typemax(UInt16), typemax(UInt32), typemax(UInt64),
       typemax(Int8), typemin(Int8), typemax(Int16), typemin(Int16), typemax(Int32),
       typemin(Int32), typemax(Int64), typemin(Int64), nothing, rand(Float32),
       rand(Float64), true, false, join(rand(Char, typemax(UInt8) - 1))]

push!(arr, deepcopy(arr))

@test can_round_trip(arr, Vector{Any})
for x in arr
    T = Vector{typeof(x)}
    @test can_round_trip(fill(x, 9), T)
    @test can_round_trip(fill(x, typemax(UInt8) - 1), T)
    @test can_round_trip(fill(x, typemax(UInt8) + 1), T)
    @test can_round_trip(fill(x, typemax(UInt16) + 1), T)
end

# MapType

dict = Dict(zip(arr, reverse(arr)))

@test can_round_trip(dict, Dict{Any,Any})
for v in values(dict)
    T = Dict{Int,typeof(v)}
    @test can_round_trip(Dict(zip(1:9, fill(v, 9))), T)
    @test can_round_trip(Dict(zip(1:(typemax(UInt8) - 1), fill(v, typemax(UInt8) - 1))), T)
    @test can_round_trip(Dict(zip(1:(typemax(UInt8) + 1), fill(v, typemax(UInt8) + 1))), T)
    @test can_round_trip(Dict(zip(1:(typemax(UInt16) + 1), fill(v, typemax(UInt16) + 1))), T)
end

# TODO: ImmutableStructType
# TODO: MutableStructType
