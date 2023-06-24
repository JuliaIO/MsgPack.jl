using Test, MsgPack, Serialization

function can_round_trip(value, T,
                        expected_typed_output = value,
                        expected_any_output = value)
    bytes = pack(value)
    if T <: AbstractArray
        S = eltype(T)
    elseif T <: AbstractDict
        S = valtype(T)
    else
        S = T
    end
    return isequal(unpack(bytes, T; strict=(S,)), expected_typed_output) &&
           isequal(unpack(bytes, T), expected_typed_output) &&
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

let s = :wake_after_sleep_onset_percentage
    @test can_round_trip(s, Symbol, s, string(s))
end

# BinaryType

struct ByteVec
    bytes::Vector{UInt8}
end

Base.:(==)(a::ByteVec, b::ByteVec) = a.bytes == b.bytes

MsgPack.msgpack_type(::Type{ByteVec}) = MsgPack.BinaryType()
MsgPack.to_msgpack(::MsgPack.BinaryType, x::ByteVec) = x.bytes
MsgPack.from_msgpack(::Type{ByteVec}, bytes::Vector{UInt8}) = ByteVec(bytes)

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
    A = MsgPack.ArrayView{typeof(x)}
    a = fill(x, 9)
    @test can_round_trip(a, T)
    @test can_round_trip(a, A)
    a = fill(x, typemax(UInt8) - 1)
    @test can_round_trip(a, T)
    @test can_round_trip(a, A)
    a = fill(x, typemax(UInt8) + 1)
    @test can_round_trip(a, T)
    @test can_round_trip(a, A)
    a = fill(x, typemax(UInt16) + 1)
    @test can_round_trip(a, T)
    @test can_round_trip(a, A)
end

tup = (arr...,)
@test can_round_trip(tup, Tuple, tup, arr)

@test can_round_trip(tup, typeof(tup), tup, arr)

@test can_round_trip((true, tup), typeof((true, tup)), (true, tup), [true, arr])

set = Set(arr)
@test can_round_trip(set, Set, set, collect(set))

# MapType

dict = Dict(zip(arr, reverse(arr)))

@test can_round_trip(dict, Dict{Any,Any})
for v in values(dict)
    T = Dict{Int,typeof(v)}
    M = MsgPack.MapView{Int,typeof(v)}
    d = Dict(zip(1:9, fill(v, 9)))
    m = unpack(pack(d), M)
    @test length(m) == length(d)
    for i in 1:length(d)
        @test m[i] == d[i]
        @test get(() -> nothing, m, i + 1) == get(() -> nothing, d, i + 1)
        @test get(m, i + 1, nothing) == get(d, i + 1, nothing)
    end
    @test Set(collect(m)) == Set(collect(d))
    @test Set(collect(keys(m))) == Set(collect(keys(d)))
    @test Set(collect(values(m))) == Set(collect(values(d)))
    @test can_round_trip(d, T)
    @test can_round_trip(d, M)
    d = Dict(zip(1:(typemax(UInt8) - 1), fill(v, typemax(UInt8) - 1)))
    @test can_round_trip(d, T)
    @test can_round_trip(d, M)
    d = Dict(zip(1:(typemax(UInt8) + 1), fill(v, typemax(UInt8) + 1)))
    @test can_round_trip(d, T)
    @test can_round_trip(d, M)
    d = Dict(zip(1:(typemax(UInt16) + 1), fill(v, typemax(UInt16) + 1)))
    @test can_round_trip(d, T)
    @test can_round_trip(d, M)
end

namedtup = (x = arr[1], y = arr[2], z = arr[3], others = arr[4:end])
namedtup_dict = Dict((string(k) => v for (k, v) in pairs(namedtup))...)
@test can_round_trip(namedtup, NamedTuple{keys(namedtup),<:Tuple}, namedtup, namedtup_dict)

arr = [dict]
@test can_round_trip(arr, MsgPack.ArrayView{MsgPack.MapView{Any,Any}})

# StructType

struct Bar{T}
    a::T
    b::T
end

Base.:(==)(a::Bar, b::Bar) = a.a == b.a && a.b == b.b

MsgPack.construct(::Type{T}, args...) where {T<:Bar} = T(promote(args...)...)

MsgPack.msgpack_type(::Type{<:Bar}) = MsgPack.StructType()

struct Foo{T,S}
    x::Union{Nothing,T}
    y::Vector{S}
    z::Bar{T}
end

Base.:(==)(a::Foo, b::Foo) = a.x == b.x && a.y == b.y && a.z == b.z

MsgPack.msgpack_type(::Type{<:Foo}) = MsgPack.StructType()

foo = Foo{Int,String}(nothing, String["abc", join(rand(Char,typemax(UInt16)))],
                      Bar(rand(Int), rand(Int)))
foo_dict = Dict("x" => foo.x, "y" => foo.y, "z" => Dict("a" => foo.z.a, "b" => foo.z.b))
@test can_round_trip(foo, typeof(foo), foo, foo_dict)

foo = Foo{Float64,Char}(rand(), rand('a':'z', 100), Bar(rand(), rand()))
foo_dict = Dict("x" => foo.x, "y" => map(string, foo.y), "z" => Dict("a" => foo.z.a, "b" => foo.z.b))
@test can_round_trip(foo, typeof(foo), foo, foo_dict)

arr = [foo, foo]
@test can_round_trip(arr, MsgPack.ArrayView{typeof(foo)}, arr, [foo_dict, foo_dict])

mutable struct MBar{T}
    a::T
    b::T
    MBar{T}() where {T} = new{T}()
end

Base.:(==)(a::MBar, b::MBar) = a.a == b.a && a.b == b.b

MsgPack.msgpack_type(::Type{<:MBar}) = MsgPack.StructType()

function MsgPack.construct(::Type{T}, a, b) where {T<:MBar}
    bar = T()
    bar.a = a
    bar.b = b
    return bar
end

mutable struct MFoo{T,S}
    x::Union{Nothing,T}
    y::Vector{S}
    z::MBar{T}
    MFoo{T,S}() where {T,S} = new{T,S}()
end

Base.:(==)(a::MFoo, b::MFoo) = a.x == b.x && a.y == b.y && a.z == b.z

MsgPack.msgpack_type(::Type{<:MFoo}) = MsgPack.StructType()

function MsgPack.construct(::Type{T}, x, y, z) where {T<:MFoo}
    foo = T()
    foo.x = x
    foo.y = y
    foo.z = z
    return foo
end

foo = MFoo{Int,String}()
foo.x = nothing
foo.y = String["abc", join(rand(Char, typemax(UInt16)))]
foo.z = (z = MBar{Int}(); z.a = rand(Int); z.b = rand(Int); z)
foo_dict = Dict("x" => foo.x, "y" => foo.y, "z" => Dict("a" => foo.z.a, "b" => foo.z.b))
@test can_round_trip(foo, typeof(foo), foo, foo_dict)

foo = MFoo{Float64,Char}()
foo.x = rand()
foo.y = rand('a':'z', 100)
foo.z = (z = MBar{Float64}(); z.a = rand(); z.b = rand(); z)
foo_dict = Dict("x" => foo.x, "y" => map(string, foo.y), "z" => Dict("a" => foo.z.a, "b" => foo.z.b))
@test can_round_trip(foo, typeof(foo), foo, foo_dict)

arr = [foo, foo]
@test can_round_trip(arr, MsgPack.ArrayView{typeof(foo)}, arr, [foo_dict, foo_dict])

# ExtensionType

type = 123
data = (io = IOBuffer(); serialize(io, arr); take!(io))
@test MsgPack.Ext(type, data) === MsgPack.Extension(type, data)
ext = MsgPack.extserialize(type, arr)
@test ext.type == type
@test ext.data == data
ext_type, ext_arr = MsgPack.extdeserialize(ext)
@test ext_type == ext.type
@test ext_arr == arr

ext = MsgPack.Extension(4, [0xbb])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(-32, [0x56, 0x8d])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(-123, [0x80, 0x7c, 0x8b, 0xf8])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(111, [0x04, 0x16, 0x94, 0x13, 0x0a, 0x7d, 0x6f, 0x0c])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(79, [0x00, 0x30, 0xd5, 0x64, 0x0f, 0x8d, 0x92, 0x90,
                             0x98, 0x99, 0x14, 0x57, 0x0e, 0x8d, 0xf1, 0x3a])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(-118, [0xc7, 0x00, 0x8a])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(50, [0x62, 0x4c, 0x7c, 0x0f, 0x86, 0x04])
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(78, rand(UInt8, typemax(UInt8) - 1))
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(32, rand(UInt8, typemax(UInt8) + 1))
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(-14, rand(UInt8, typemax(UInt16) + 1))
@test can_round_trip(ext, MsgPack.Extension)
ext = MsgPack.Extension(84, UInt8[])
@test can_round_trip(ext, MsgPack.Extension)
