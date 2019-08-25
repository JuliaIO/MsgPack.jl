#####
##### `AbstractMsgPackType`
#####

"""
    AbstractMsgPackType

An abstract type whose subtypes define a MessagePack <--> Julia type interface.

The subtypes of `AbstractMsgPackType` are:

- [`IntegerType`](@ref)
- [`NilType`](@ref)
- [`BooleanType`](@ref)
- [`FloatType`](@ref)
- [`StringType`](@ref)
- [`BinaryType`](@ref)
- [`ArrayType`](@ref)
- [`MapType`](@ref)
- [`AnyType`](@ref)
- [`ImmutableStructType`](@ref)
- [`MutableStructType`](@ref)
"""
abstract type AbstractMsgPackType end

"""
    IntegerType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Integer type.

If `msgpack_type(T)` is defined to return `IntegerType()`, then `T` must support:

- `to_msgpack(::IntegerType, ::T)::S`
- `from_msgpack(::Type{T}, ::S)::T`
- standard numeric comparators (`>`, `<`, `==`, etc.) against values of type `S`

where `S` may be one of the following types:

- `UInt8`
- `UInt16`
- `UInt32`
- `UInt64`
- `Int8`
- `Int16`
- `Int32`
- `Int64`
"""
struct IntegerType <: AbstractMsgPackType end

"""
    NilType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Nil type.

If `msgpack_type(T)` is defined to return `NilType()`, then `T` must support:

- `from_msgpack(::Type{T}, ::Nothing)::T`
"""
struct NilType <: AbstractMsgPackType end

"""
    BooleanType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Boolean type.

If `msgpack_type(T)` is defined to return `BooleanType()`, then `T` must support:

- `to_msgpack(::BooleanType, ::T)::Bool`
- `from_msgpack(::Type{T}, ::Bool)::T`
"""
struct BooleanType <: AbstractMsgPackType end

"""
    FloatType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Float type.

If `msgpack_type(T)` is defined to return `FloatType()`, then `T` must support:

- `to_msgpack(::FloatType, ::T)::S`
- `from_msgpack(::Type{T}, ::S)::T`
- standard numeric comparators (`>`, `<`, `==`, etc.) against values of type `S`

where `S` may be one of the following types:

- `Float32`
- `Float64`
"""
struct FloatType <: AbstractMsgPackType end

"""
    StringType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack String type.

If `msgpack_type(T)` is defined to return `StringType()`, then `T` must support:

- `to_msgpack(::StringType, ::T)::String`
- `from_msgpack(::Type{T}, ::String)::T`
"""
struct StringType <: AbstractMsgPackType end

"""
    BinaryType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Binary type.

If `msgpack_type(T)` is defined to return `BinaryType()`, then `T` must support:

- `to_msgpack(::BinaryType, ::T)::Vector{UInt8}`
- `from_msgpack(::Type{T}, ::Vector{UInt8})::T`
"""
struct BinaryType <: AbstractMsgPackType end

"""
    ArrayType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Array type.

If `msgpack_type(T)` is defined to return `ArrayType()`, then `T` must support
the Julia `AbstractArray` interface, and/or must support:

- `to_msgpack(::ArrayType, ::T)::AbstractArray`
- `from_msgpack(::Type{T}, ::Vector)::T`
"""
struct ArrayType <: AbstractMsgPackType end

"""
    MapType <: AbstractMsgPackType

A Julia type corresponding to the MessagePack Map type.

If `msgpack_type(T)` is defined to return `MapType()`, then `T` must support
the Julia `AbstractDict` interface, and/or must support:

- `to_msgpack(::ArrayType, ::T)::AbstractDict`
- `from_msgpack(::Type{T}, ::Dict)::T`
"""
struct MapType <: AbstractMsgPackType end

"""
    AnyType <: AbstractMsgPackType

The fallback return type of `msgpack_type(::Type)`, indicating that the given
Julia type does not have a known corresponding MessagePack type.
"""
struct AnyType <: AbstractMsgPackType end

"""
    ImmutableStructType <: AbstractMsgPackType

If `msgpack_type(T)` is defined to return `ImmutableStructType`, `T` will be
(de)serialized as a MessagePack Map type assuming certain constraints that
enable additional optimizations:

- `T` supports `fieldcount`, `fieldtype`, `fieldname`, `getfield`, and a constructor
that can be called as `T((getfield(x::T, i) for i in 1:fieldcount(T))...)` for any
`T` instance `x`.

- [`unpack`](@ref) will assume that incoming bytes to be deserialized to `T`
will always be formmatted as a MessagePack Map whose fields correspond exactly
to the fields of `T`. In other words, the `i`th key in the Map must correspond
to `fieldname(T, i)`, and the `i`th value must correspond to `getfield(::T, i)`.

This type is similar to [`MutableStructType`](@ref), but generally achieves
greater (de)serialization performance by imposing tighter constraints.
"""
struct ImmutableStructType <: AbstractMsgPackType end

"""
    MutableStructType <: AbstractMsgPackType

If `msgpack_type(T)` is defined to return `MutableStructType`, `T` will be
(de)serialized as a MessagePack Map type assuming certain constraints that
enable additional optimizations:

- `T` supports `fieldcount`, `fieldtype`, `fieldname`, `getfield`, `setfield!`,
and has the inner constructor `T() = new()`.

- [`unpack`](@ref) will assume that incoming bytes to be deserialized to `T`
will always be formmatted as a MessagePack Map whose fields are an unordered
subset of the fields of `T`. If a given field is not present in the MessagePack
Map, the corresponding field of the returned `T` instance will be left
uninitialized.

This type is similar to [`ImmutableStructType`](@ref), but imposes fewer
constraints at the cost of (de)serialization performance.
"""
struct MutableStructType <: AbstractMsgPackType end

#####
##### `msgpack_type`, `to_msgpack`, `from_msgpack` defaults
#####

"""
    msgpack_type(::Type{T}) where {T}

Return an instance of the [`AbstractMsgPackType`](@ref) subtype corresponding
to `T`'s intended MessagePack representation. For example:

```
msgpack_type(::Type{UUID}) = StringType()
```

If this method is overloaded such that `msgpack_type(T) === M()`, then `to_msgpack(::M, ::T)`
and `from_msgpack(::Type{T}, x)` should also be overloaded to handle conversion of `T`
instances to/from MsgPack2-compatible types.

By default, this method returns `AnyType()`. While this fallback method need not be overloaded to
support deserialization of `T` instances via `unpack`, `msgpack_type(T)` must be overloaded to
return a non-`AnyType` `AbstractMsgPackType` instance in order to support serializing `T` instances
via `pack`.

See also: [`from_msgpack`](@ref), [`to_msgpack`](@ref)
"""
msgpack_type(::Type) = AnyType()

"""
    to_msgpack(::M, value_to_serialize::T) where {M<:AbstractMsgPackType,T}

Return an "`M`-compatible" representation of `value_to_serialize` (for compatibility
definitions, see the docstrings for subtypes of `AbstractMsgPackType).

By default, `to_msgpack` simply returns `value_to_serialize` directly.

The implementation of [`pack`](@ref) utilizes this function for every value
encountered during serialization, calling it in a manner similar to the
following psuedocode:

```
t = msgpack_type(T)
value_in_compatible_representation = to_msgpack(t, value_to_serialize::T)
_serialize_in_msgpack_format(t, value_in_compatible_representation)
```

For example, if `msgpack_type(UUID)` was defined to return `StringType()`, an
appropriate `to_msgpack` implementation might be:

```
to_msgpack(::StringType, uuid::UUID) = string(uuid)
```

See also: [`from_msgpack`](@ref), [`msgpack_type`](@ref), [`AbstractMsgPackType`](@ref)
"""
to_msgpack(::AbstractMsgPackType, x) = x

"""
    from_msgpack(::Type{T}, value_deserialized_by_msgpack) where {T}

Return the `value_deserialized_by_msgpack` converted to type `T`. By default,
this method simply calls `convert(T, value_deserialized_by_msgpack)`.

The implementation of [`unpack`](@ref) calls this function on every deserialized
value; in this case, `T` is generally derived from the type specified by
the caller of `unpack`.

For example, if `msgpack_type(UUID)` was defined to return `StringType()`, an
appropriate `from_msgpack` implementation might be:

```
from_msgpack(::Type{UUID}, uuid::AbstractString) = UUID(uuid)
```

See also: [`to_msgpack`](@ref), [`msgpack_type`](@ref), [`AbstractMsgPackType`](@ref)
"""
from_msgpack(T::Type, x) = convert(T, x)

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

#####
##### `Skip`
#####

struct Skip{T} end

msgpack_type(::Type{Skip{T}}) where {T} = msgpack_type(T)

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
