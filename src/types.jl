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

#####
##### types for interfacing with Julia
#####

struct AnyType <: AbstractMsgPackType end

struct ImmutableStructType <: AbstractMsgPackType end

struct MutableStructType <: AbstractMsgPackType end

#####
##### `msgpacktype` + `construct` defaults
#####

# int-y things

@inline msgpacktype(::Type{<:Integer}) = IntegerType()

# nil-y things

@inline msgpacktype(::Type{Nothing}) = NilType()

@inline msgpacktype(::Type{Missing}) = NilType()
@inline construct(::Type{Missing}, ::Nothing) = missing

# bool-y things

@inline msgpacktype(::Type{Bool}) = BooleanType()

# float-y things

@inline msgpacktype(::Type{<:AbstractFloat}) = FloatType()

# string-y things

@inline msgpacktype(::Type{<:AbstractString}) = StringType()

@inline msgpacktype(::Type{Symbol}) = StringType()
@inline construct(::Type{Symbol}, x::AbstractString) = Symbol(x)

@inline msgpacktype(::Type{<:Enum}) = StringType()
@inline msgpacktype(::Type{Char}) = StringType()

# array-y things

@inline msgpacktype(::Type{<:AbstractArray}) = ArrayType()

@inline msgpacktype(::Type{<:AbstractSet}) = ArrayType()

@inline msgpacktype(::Type{<:Tuple}) = ArrayType()

# map-y things

@inline msgpacktype(::Type{<:AbstractDict}) = MapType()

@inline msgpacktype(::Type{<:NamedTuple}) = MapType()

# any-y things

@inline msgpacktype(::Type) = AnyType()
@inline construct(T::Type, x) = convert(T, x)
