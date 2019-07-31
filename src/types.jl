#####
##### MsgPack types
#####

abstract type AbstractMsgPackType end

struct IntegerType <: AbstractMsgPackType end

struct NilType <: AbstractMsgPackType end

struct BooleanType <: AbstractMsgPackType end

struct FloatType <: AbstractMsgPackType end

struct StringType <: AbstractMsgPackType end

struct BinaryType <: AbstractMsgPackType end

struct ArrayType <: AbstractMsgPackType end

struct MapType <: AbstractMsgPackType end

struct ExtensionType <: AbstractMsgPackType end

#####
##### types for interfacing with Julia
#####

struct AnyType end

struct ImmutableStructType end

struct MutableStructType end

struct Skip{T} end

#####
##### `msgpack_type`, `to_msgpack`, `from_msgpack` defaults
#####

# int-y things

msgpack_type(::Type{<:Integer}) = IntegerType()

# nil-y things

msgpack_type(::Type{Nothing}) = NilType()
msgpack_type(::Type{Missing}) = NilType()

from_msgpack(::Type{Missing}, ::Nothing) = missing

# bool-y things

msgpack_type(::Type{Bool}) = BooleanType()

# float-y things

msgpack_type(::Type{<:AbstractFloat}) = FloatType()

# string-y things

msgpack_type(::Type{<:AbstractString}) = StringType()
msgpack_type(::Type{Symbol}) = StringType()
msgpack_type(::Type{Char}) = StringType()

to_msgpack(::StringType, x::Char) = x
to_msgpack(::StringType, x::Symbol) = _symbol_to_string(x)

from_msgpack(::Type{Char}, x::AbstractString) = first(x)
from_msgpack(::Type{Symbol}, x::AbstractString) = Symbol(x)

# array-y things

msgpack_type(::Type{<:AbstractArray}) = ArrayType()
msgpack_type(::Type{<:AbstractSet}) = ArrayType()
msgpack_type(::Type{<:Tuple}) = ArrayType()

# map-y things

msgpack_type(::Type{<:AbstractDict}) = MapType()
msgpack_type(::Type{<:NamedTuple}) = MapType()

@generated function to_msgpack(::MapType, x::NamedTuple)
    fields = Any[]
    for i in 1:fieldcount(x)
        push!(fields, Expr(:tuple, Expr(:quote, fieldname(x, i)), :(getfield(x, $i))))
    end
    return Expr(:tuple, fields...)
end

@generated function from_msgpack(::Type{T}, x::Dict) where {T<:NamedTuple}
    fields = Any[]
    for i in 1:fieldcount(T)
        name = fieldname(T, i)
        strname = String(name)
        push!(fields, :($name = x[$strname]))
    end
    return Expr(:tuple, fields...)
end

# fallbacks

msgpack_type(::Type) = AnyType()

msgpack_type(::Type{Skip{T}}) where {T} = msgpack_type(T)

to_msgpack(::AbstractMsgPackType, x) = x

from_msgpack(T::Type, x) = convert(T, x)

from_msgpack(::Type{T}, x) where {T<:Skip} = T()

#####
##### `PointerString`
#####

struct PointerString
    ptr::Ptr{UInt8}
    len::UInt64
end

Base.length(s::PointerString) = s.len

Base.write(io::IO, s::PointerString) = Base.unsafe_write(io, s.ptr, s.len)

from_msgpack(::Type{Symbol}, x::PointerString) = ccall(:jl_symbol_n, Ref{Symbol}, (Ptr{UInt8}, Int), x.ptr, x.len)
from_msgpack(::Type{PointerString}, x::PointerString) = x
from_msgpack(S::Type, x::PointerString) = from_msgpack(S, unsafe_string(x.ptr, x.len))

function _symbol_to_string(x::Symbol)
    ptr = Base.unsafe_convert(Ptr{UInt8}, x)
    for len in 0:typemax(UInt32)
        unsafe_load(ptr + len) === 0x00 && return PointerString(ptr, len)
    end
    return nothing
end
