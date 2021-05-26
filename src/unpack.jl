unpack(x; strict::Tuple=()) = unpack(x, Any; strict=strict)

"""
    unpack(bytes, T::Type = Any; strict::Tuple=())

Return `unpack(IOBuffer(bytes), T; strict=strict)`.
"""
unpack(bytes, ::Type{T}; strict::Tuple=()) where {T} = unpack(IOBuffer(bytes), T; strict=strict)

"""
    unpack(msgpack_byte_stream::IO, T::Type = Any; strict::Tuple=())

Return the Julia value of type `T` deserialized from `msgpack_byte_stream`.

`T` is assumed to have valid [`msgpack_type`](@ref) and [`from_msgpack`](@ref)
definitions.

If `msgpack_type(T) === AnyType()`, `unpack` will deserialize the next
MessagePack object from `msgpack_byte_stream` into the default Julia
representation corresponding to the object's MessagePack type. For details on
default Julia representations, see [`AbstractMsgPackType`](@ref).

The `strict` keyword argument is a `Tuple` of `DataType`s where each element
`S` must obey `msgpack_type(S) === StructType()`. `unpack` will assume that
encountered MessagePack Maps to be deserialized to e.g. `S` will always contain
fields that correspond strictly to the fields of `S`. In other words, the `i`th
key in the Map must correspond to `fieldname(S, i)`, and the `i`th value must
correspond to `getfield(::S, i)`.

See also: [`pack`](@ref), [`construct`](@ref)
"""
unpack(io::IO, ::Type{T}; strict::Tuple=()) where {T} = unpack_type(io, read(io, UInt8), msgpack_type(T), T; strict=strict)

#####
##### `AnyType`
#####

function unpack_type(io, byte, t::AnyType, U::Union; strict)
    A, B = U.a, U.b # Unions are sorted, so `Nothing`/`Missing` would be first
    if A === Nothing || A === Missing
        byte === magic_byte(NilFormat) && return from_msgpack(A, nothing)
        return unpack_type(io, byte, msgpack_type(B), B; strict=strict)
    end
    return _unpack_any(io, byte, U)
end

@inline unpack_type(io, byte, ::AnyType, T::Type; strict) = _unpack_any(io, byte, T; strict=strict)

function _unpack_any(io, byte, ::Type{T}; strict) where {T}
    if byte <= magic_byte_max(IntFixPositiveFormat)
        return unpack_format(io, IntFixPositiveFormat(byte), T)
    elseif byte <= magic_byte_max(MapFixFormat)
        return unpack_format(io, MapFixFormat(byte), T, strict)
    elseif byte <= magic_byte_max(ArrayFixFormat)
        return unpack_format(io, ArrayFixFormat(byte), T, strict)
    elseif byte <= magic_byte_max(StrFixFormat)
        return unpack_format(io, StrFixFormat(byte), T)
    elseif byte === magic_byte(UInt8Format)
        return unpack_format(io, UInt8Format(), T)
    elseif byte === magic_byte(UInt16Format)
        return unpack_format(io, UInt16Format(), T)
    elseif byte === magic_byte(UInt32Format)
        return unpack_format(io, UInt32Format(), T)
    elseif byte === magic_byte(UInt64Format)
        return unpack_format(io, UInt64Format(), T)
    elseif byte === magic_byte(Int8Format)
        return unpack_format(io, Int8Format(), T)
    elseif byte === magic_byte(Int16Format)
        return unpack_format(io, Int16Format(), T)
    elseif byte === magic_byte(Int32Format)
        return unpack_format(io, Int32Format(), T)
    elseif byte === magic_byte(Int64Format)
        return unpack_format(io, Int64Format(), T)
    elseif byte === magic_byte(Float32Format)
        return unpack_format(io, Float32Format(), T)
    elseif byte === magic_byte(Float64Format)
        return unpack_format(io, Float64Format(), T)
    elseif byte === magic_byte(ComplexF32Format)
        return unpack_format(io, ComplexF32Format(), T)
    elseif byte === magic_byte(ComplexF64Format)
        return unpack_format(io, ComplexF64Format(), T)
    elseif byte === magic_byte(Str8Format)
        return unpack_format(io, Str8Format(), T)
    elseif byte === magic_byte(Str16Format)
        return unpack_format(io, Str16Format(), T)
    elseif byte === magic_byte(Str32Format)
        return unpack_format(io, Str32Format(), T)
    elseif byte === magic_byte(TrueFormat)
        return unpack_format(io, TrueFormat(), T)
    elseif byte === magic_byte(FalseFormat)
        return unpack_format(io, FalseFormat(), T)
    elseif byte === magic_byte(NilFormat)
        return unpack_format(io, NilFormat(), T)
    elseif byte === magic_byte(Array16Format)
        return unpack_format(io, Array16Format(), T, strict)
    elseif byte === magic_byte(Array32Format)
        return unpack_format(io, Array32Format(), T, strict)
    elseif byte === magic_byte(Map16Format)
        return unpack_format(io, Map16Format(), T, strict)
    elseif byte === magic_byte(Map32Format)
        return unpack_format(io, Map32Format(), T, strict)
    elseif byte === magic_byte(Ext8Format)
        return unpack_format(io, Ext8Format(), T)
    elseif byte === magic_byte(Ext16Format)
        return unpack_format(io, Ext16Format(), T)
    elseif byte === magic_byte(Ext32Format)
        return unpack_format(io, Ext32Format(), T)
    elseif byte === magic_byte(ExtFix1Format)
        return unpack_format(io, ExtFix1Format(), T)
    elseif byte === magic_byte(ExtFix2Format)
        return unpack_format(io, ExtFix2Format(), T)
    elseif byte === magic_byte(ExtFix4Format)
        return unpack_format(io, ExtFix4Format(), T)
    elseif byte === magic_byte(ExtFix8Format)
        return unpack_format(io, ExtFix8Format(), T)
    elseif byte === magic_byte(ExtFix16Format)
        return unpack_format(io, ExtFix16Format(), T)
    elseif byte === magic_byte(Bin8Format)
        return unpack_format(io, Bin8Format(), T)
    elseif byte === magic_byte(Bin16Format)
        return unpack_format(io, Bin16Format(), T)
    elseif byte === magic_byte(Bin32Format)
        return unpack_format(io, Bin32Format(), T)
    elseif byte >= magic_byte_min(IntFixNegativeFormat)
        return unpack_format(io, IntFixNegativeFormat(reinterpret(Int8, byte)), T)
    end
    invalid_unpack(io, byte, AnyType(), T) # should be unreachable, but ensures error is thrown if reached
end

#####
##### `StructType`
#####

struct FieldNotFound end

"""
    construct(T::Type, args...)

Return an instance of `T` given `args`; defaults to `T(args...)`.

This function is meant to be overloaded for types `T` where `msgpack_type(T) === StructType()`.

This function is called by [`unpack`](@ref) when deserializing `T` objects. When
called for this purpose, `args` are field values for the given `T` instance and
are passed in the order specified by `fieldname(T, i)`. If a given field of `T`
wasn't found in the object's MessagePack Map representation, the corresponding
value in `args` will be `MsgPack.FieldNotFound()`.
"""
construct(::Type{T}, args...) where {T} = T(args...)

function unpack_type(io, byte, t::StructType, ::Type{T}; strict) where {T}
    if any(T <: S for S in strict)
        byte > magic_byte_max(MapFixFormat) && read(io, UInt8)
        N = fieldcount(T)
        constructor = (args...) -> construct(T, args...)
        Base.@nexprs 32 i -> begin
            F_i = fieldtype(T, i)
            unpack_type(io, read(io, UInt8), StringType(), Skip{Symbol}; strict=strict)
            x_i = unpack_type(io, read(io, UInt8), msgpack_type(F_i), F_i; strict=strict)
            N == i && return Base.@ncall i constructor x
        end
        others = Any[]
        for i in 33:N
            F_i = fieldtype(T, i)
            push!(others, unpack_type(io, read(io, UInt8), msgpack_type(F_i), F_i; strict=strict))
        end
        return constructor(x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13,
                           x14, x15, x16, x17, x18, x19, x20, x21, x22, x23, x24, x25,
                           x26, x27, x28, x29, x30, x31, x32, others...)
    else
        if byte <= magic_byte_max(MapFixFormat)
            pair_count = xor(byte, magic_byte_min(MapFixFormat))
        elseif byte === magic_byte(Map16Format)
            pair_count = ntoh(read(io, UInt16))
        elseif byte === magic_byte(Map32Format)
            pair_count = ntoh(read(io, UInt32))
        else
            invalid_unpack(io, byte, t, T)
        end
        N = fieldcount(T)
        fields = Any[FieldNotFound() for _ in 1:N]
        for _ in 1:pair_count
            key = unpack(io, Symbol) # TODO validation check?
            Base.@nif(32,
                      i -> i <= N && fieldname(T, i) === key,
                      i -> setindex!(fields, unpack(io, fieldtype(T, i); strict=strict), i),
                      i -> begin
                          is_field_still_unread = true
                          for j in 33:N
                              fieldname(T, j) === key || continue
                              setindex!(fields, unpack(io, fieldtype(T, j); strict=strict), j)
                              is_field_still_unread = false
                              break
                          end
                          is_field_still_unread && unpack(io)
                      end)
        end
        return construct(T, fields...)
    end
end

function unpack_type(io, byte, ::StructType, ::Type{Skip{T}}; strict) where {T}
    if any(T <: S for S in strict)
        N = fieldcount(T)
        byte > magic_byte_max(MapFixFormat) && read(io, UInt8)
        Base.@nexprs 32 i -> begin
            F_i = fieldtype(T, i)
            unpack_type(io, read(io, UInt8), StringType(), Skip{Symbol}; strict=strict)
            unpack_type(io, read(io, UInt8), msgpack_type(F_i), Skip{F_i}; strict=strict)
            N == i && return Skip{T}()
        end
        for i in 33:N
            F_i = fieldtype(T, i)
            unpack_type(io, read(io, UInt8), msgpack_type(F_i), Skip{F_i}; strict=strict)
        end
    else
        unpack_type(io, byte, MapType(), Skip{Dict{Symbol,Any}}; strict=strict)
    end
    return Skip{T}()
end

#####
##### `IntegerType`
#####

function unpack_type(io, byte, t::IntegerType, ::Type{T}; strict) where {T}
    if byte <= magic_byte_max(IntFixPositiveFormat)
        return unpack_format(io, IntFixPositiveFormat(byte), T)
    elseif byte === magic_byte(UInt8Format)
        return unpack_format(io, UInt8Format(), T)
    elseif byte === magic_byte(UInt16Format)
        return unpack_format(io, UInt16Format(), T)
    elseif byte === magic_byte(UInt32Format)
        return unpack_format(io, UInt32Format(), T)
    elseif byte === magic_byte(UInt64Format)
        return unpack_format(io, UInt64Format(), T)
    elseif byte === magic_byte(Int8Format)
        return unpack_format(io, Int8Format(), T)
    elseif byte === magic_byte(Int16Format)
        return unpack_format(io, Int16Format(), T)
    elseif byte === magic_byte(Int32Format)
        return unpack_format(io, Int32Format(), T)
    elseif byte === magic_byte(Int64Format)
        return unpack_format(io, Int64Format(), T)
    elseif byte >= magic_byte_min(IntFixNegativeFormat)
        return unpack_format(io, IntFixNegativeFormat(reinterpret(Int8, byte)), T)
    end
    invalid_unpack(io, byte, t, T) # should be unreachable, but ensures error is thrown if reached
end

unpack_format(io, f::IntFixPositiveFormat, ::Type{T}) where {T} = from_msgpack(T, UInt8(f.byte))
unpack_format(io, f::IntFixNegativeFormat, ::Type{T}) where {T} = from_msgpack(T, Int8(f.byte))

unpack_format(io, f::IntFixPositiveFormat, ::Type{T}) where {T<:Skip} = T()
unpack_format(io, f::IntFixNegativeFormat, ::Type{T}) where {T<:Skip} = T()

unpack_format(io, ::UInt8Format, ::Type{T}) where {T} = from_msgpack(T, read(io, UInt8))
unpack_format(io, ::UInt16Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, UInt16)))
unpack_format(io, ::UInt32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, UInt32)))
unpack_format(io, ::UInt64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, UInt64)))

unpack_format(io, ::UInt8Format, ::Type{T}) where {T<:Skip} = (skip(io, 1); T())
unpack_format(io, ::UInt16Format, ::Type{T}) where {T<:Skip} = (skip(io, 2); T())
unpack_format(io, ::UInt32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())
unpack_format(io, ::UInt64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

unpack_format(io, ::Int8Format, ::Type{T}) where {T} = from_msgpack(T, read(io, Int8))
unpack_format(io, ::Int16Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Int16)))
unpack_format(io, ::Int32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Int32)))
unpack_format(io, ::Int64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Int64)))

unpack_format(io, ::Int8Format, ::Type{T}) where {T<:Skip} = (skip(io, 1); T())
unpack_format(io, ::Int16Format, ::Type{T}) where {T<:Skip} = (skip(io, 2); T())
unpack_format(io, ::Int32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())
unpack_format(io, ::Int64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

#####
##### `NilType`
#####

function unpack_type(io, byte, ::NilType, ::Type{T}; strict) where {T}
    byte === magic_byte(NilFormat) && return unpack_format(io, NilFormat(), T)
    invalid_unpack(io, f, T)
end

unpack_type(io, byte, ::NilType, ::Type{T}; strict) where {T<:Skip} = T()

unpack_format(io, ::NilFormat, ::Type{T}) where {T} = from_msgpack(T, nothing)

#####
##### `BooleanType`
#####

function unpack_type(io, byte, t::BooleanType, ::Type{T}; strict) where {T}
    byte === magic_byte(TrueFormat) && return unpack_format(io, TrueFormat(), T)
    byte === magic_byte(FalseFormat) && return unpack_format(io, FalseFormat(), T)
    invalid_unpack(io, byte, t, T)
end

unpack_type(io, byte, ::BooleanType, ::Type{T}; strict) where {T<:Skip} = T()

unpack_format(io, ::TrueFormat, ::Type{T}) where {T} = from_msgpack(T, true)

unpack_format(io, ::FalseFormat, ::Type{T}) where {T} = from_msgpack(T, false)

#####
##### `FloatType`
#####

function unpack_type(io, byte, t::FloatType, ::Type{T}; strict) where {T}
    if byte === magic_byte(Float32Format)
        return unpack_format(io, Float32Format(), T)
    elseif byte === magic_byte(Float64Format)
        return unpack_format(io, Float64Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

unpack_format(io, ::Float32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Float32)))
unpack_format(io, ::Float32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())
unpack_format(io, ::Float64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Float64)))
unpack_format(io, ::Float64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

#####
##### `CFloatType`
#####

function unpack_type(io, byte, t::ComplexFType, ::Type{T}; strict) where {T}
    if byte === magic_byte(ComplexF32Format)
        return unpack_format(io, ComplexF32Format(), T)
    elseif byte === magic_byte(ComplexF64Format)
        return unpack_format(io, ComplexF64Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

unpack_format(io, ::ComplexF32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, ComplexF32)))
unpack_format(io, ::ComplexF32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())

unpack_format(io, ::ComplexF64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, ComplexF64)))
unpack_format(io, ::ComplexF64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

#####
##### `StringType`
#####

function unpack_type(io, byte, t::StringType, ::Type{T}; strict) where {T}
    if byte <= magic_byte_max(StrFixFormat)
        return unpack_format(io, StrFixFormat(byte), T)
    elseif byte === magic_byte(Str8Format)
        return unpack_format(io, Str8Format(), T)
    elseif byte === magic_byte(Str16Format)
        return unpack_format(io, Str16Format(), T)
    elseif byte === magic_byte(Str32Format)
        return unpack_format(io, Str32Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

unpack_format(io, ::Str8Format, ::Type{T}) where {T} = _unpack_string(io, read(io, UInt8), T)
unpack_format(io, ::Str16Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt16)), T)
unpack_format(io, ::Str32Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt32)), T)
unpack_format(io, f::StrFixFormat, ::Type{T}) where {T} = _unpack_string(io, xor(f.byte, magic_byte_min(StrFixFormat)), T)

_unpack_string(io, n, ::Type{T}) where {T} = from_msgpack(T, String(read(io, n)))
_unpack_string(io, n, ::Type{T}) where {T<:Skip} = (skip(io, n); T())

# Below is a nice optimization we can apply when `io` wraps an indexable byte
# buffer; this is really nice for skipping an extra copy when we deserialize
# the field names of `T` where `msgpack_type(T)::MutableStruct`. Like much of
# this package, this trick can be traced back to Jacob Quinn's magnificent
# JSON3.jl!
function _unpack_string(io::Base.GenericIOBuffer, n, ::Type{T}) where {T}
    result = from_msgpack(T, PointerString(pointer(io.data, io.ptr), n))
    skip(io, n)
    return result
end

# necessary to resolve ambiguity
_unpack_string(io::Base.GenericIOBuffer, n, ::Type{T}) where {T<:Skip} = (skip(io, n); T())

#####
##### `BinaryType`
#####

function unpack_type(io, byte, t::BinaryType, ::Type{T}; strict) where {T}
    if byte === magic_byte(Bin8Format)
        return unpack_format(io, Bin8Format(), T)
    elseif byte === magic_byte(Bin16Format)
        return unpack_format(io, Bin16Format(), T)
    elseif byte === magic_byte(Bin32Format)
        return unpack_format(io, Bin32Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

unpack_format(io, ::Bin8Format, ::Type{T}) where {T} = _unpack_binary(io, read(io, UInt8), T)
unpack_format(io, ::Bin16Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt16)), T)
unpack_format(io, ::Bin32Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt32)), T)

_unpack_binary(io, n, ::Type{T}) where {T} = from_msgpack(T, read(io, n))
_unpack_binary(io, n, ::Type{T}) where {T<:Skip} = (skip(io, n); T())

#####
##### `ArrayType`
#####

function unpack_type(io, byte, t::ArrayType, ::Type{T}; strict) where {T}
    if byte <= magic_byte_max(ArrayFixFormat)
        return unpack_format(io, ArrayFixFormat(byte), T, strict)
    elseif byte === magic_byte(Array16Format)
        return unpack_format(io, Array16Format(), T, strict)
    elseif byte === magic_byte(Array32Format)
        return unpack_format(io, Array32Format(), T, strict)
    else
        invalid_unpack(io, byte, t, T)
    end
end

unpack_format(io, ::Array16Format, ::Type{T}, strict) where {T} = _unpack_array(io, ntoh(read(io, UInt16)), T, strict)
unpack_format(io, ::Array32Format, ::Type{T}, strict) where {T} = _unpack_array(io, ntoh(read(io, UInt32)), T, strict)
unpack_format(io, f::ArrayFixFormat, ::Type{T}, strict) where {T} = _unpack_array(io, xor(f.byte, magic_byte_min(ArrayFixFormat)), T, strict)

_eltype(T) = eltype(T)

function _unpack_array(io, n, ::Type{T}, strict) where {T}
E = _eltype(T)
    e = msgpack_type(E)
    result = Vector{E}(undef, n)
    for i in 1:n
        result[i] = unpack_type(io, read(io, UInt8), e, E; strict=strict)
    end
    return from_msgpack(T, result)
end

function _unpack_array(io, n, ::Type{Skip{T}}, strict) where {T}
    E = _eltype(T)
    e = msgpack_type(E)
    for _ in 1:n
        unpack_type(io, read(io, UInt8), e, Skip{E}; strict=strict)
    end
    return Skip{T}()
end

function _unpack_array(io::Base.GenericIOBuffer, n, ::Type{T}, strict) where {T<:ArrayView}
    E = _eltype(T)
    e = msgpack_type(E)
    start = position(io)
    positions = Vector{UInt64}(undef, n)
    for i in 1:length(positions)
        positions[i] = (position(io) - start) + 1
        unpack_type(io, read(io, UInt8), e, Skip{E}; strict=strict)
    end
    bytes = view(io.data, (start + 1):position(io))
    return ArrayView{E}(bytes, positions, strict)
end

#####
##### `MapType`
#####

function unpack_type(io, byte, t::MapType, ::Type{T}; strict) where {T}
    if byte <= magic_byte_max(MapFixFormat)
        return unpack_format(io, MapFixFormat(byte), T, strict)
    elseif byte === magic_byte(Map16Format)
        return unpack_format(io, Map16Format(), T, strict)
    elseif byte === magic_byte(Map32Format)
        return unpack_format(io, Map32Format(), T, strict)
    else
        invalid_unpack(io, byte, t, T)
    end
end

unpack_format(io, ::Map16Format, ::Type{T}, strict) where {T} = _unpack_map(io, ntoh(read(io, UInt16)), T, strict)
unpack_format(io, ::Map32Format, ::Type{T}, strict) where {T} = _unpack_map(io, ntoh(read(io, UInt32)), T, strict)
unpack_format(io, f::MapFixFormat, ::Type{T}, strict) where {T} = _unpack_map(io, xor(f.byte, magic_byte_min(MapFixFormat)), T, strict)

_keytype(T) = Any
_keytype(::Type{T}) where {K,V,T<:AbstractDict{K,V}} = keytype(T)

_valtype(T) = Any
_valtype(::Type{T}) where {K,V,T<:AbstractDict{K,V}} = valtype(T)

function _unpack_map(io, n, ::Type{T}, strict) where {T}
    K = _keytype(T)
    k = msgpack_type(K)
    V = _valtype(T)
    v = msgpack_type(V)
    dict = Dict{K,V}()
    for _ in 1:n
        key = unpack_type(io, read(io, UInt8), k, K; strict=strict)
        val = unpack_type(io, read(io, UInt8), v, V; strict=strict)
        dict[key] = val
    end
    return from_msgpack(T, dict)
end

function _unpack_map(io, n, ::Type{Skip{T}}, strict) where {T}
    K = _keytype(T)
    k = msgpack_type(K)
    V = _valtype(T)
    v = msgpack_type(V)
    for i in 1:n
        unpack_type(io, read(io, UInt8), k, Skip{K}; strict=strict)
        unpack_type(io, read(io, UInt8), v, Skip{V}; strict=strict)
    end
    return Skip{T}()
end

function _unpack_map(io::Base.GenericIOBuffer, n, ::Type{T}, strict) where {T<:MapView}
    K = _keytype(T)
    k = msgpack_type(K)
    V = _valtype(T)
    v = msgpack_type(V)
    start = position(io)
    positions = Dict{K,UnitRange{UInt64}}()
    for _ in 1:n
        key = unpack_type(io, read(io, UInt8), k, K; strict=strict)
        value_start = (position(io) - start) + 1
        unpack_type(io, read(io, UInt8), v, Skip{V}; strict=strict)
        positions[key] = value_start:(position(io) - start)
    end
    bytes = view(io.data, (start + 1):position(io))
    return MapView{K,V}(bytes, positions, strict)
end

#####
##### `ExtensionType`
#####

function unpack_type(io, byte, t::ExtensionType, ::Type{T}; strict) where {T}
    byte === magic_byte(ExtFix1Format) && return unpack_format(io, ExtFix1Format(), T)
    byte === magic_byte(ExtFix2Format) && return unpack_format(io, ExtFix2Format(), T)
    byte === magic_byte(ExtFix4Format) && return unpack_format(io, ExtFix4Format(), T)
    byte === magic_byte(ExtFix8Format) && return unpack_format(io, ExtFix8Format(), T)
    byte === magic_byte(ExtFix16Format) && return unpack_format(io, ExtFix16Format(), T)
    byte === magic_byte(Ext8Format) && return unpack_format(io, Ext8Format(), T)
    byte === magic_byte(Ext16Format) && return unpack_format(io, Ext16Format(), T)
    byte === magic_byte(Ext32Format) && return unpack_format(io, Ext32Format(), T)
    invalid_unpack(io, byte, t, T)
end

unpack_format(io, ::ExtFix1Format, ::Type{T}) where {T} = _unpack_extension(io, 1, T)
unpack_format(io, ::ExtFix2Format, ::Type{T}) where {T} = _unpack_extension(io, 2, T)
unpack_format(io, ::ExtFix4Format, ::Type{T}) where {T} = _unpack_extension(io, 4, T)
unpack_format(io, ::ExtFix8Format, ::Type{T}) where {T} = _unpack_extension(io, 8, T)
unpack_format(io, ::ExtFix16Format, ::Type{T}) where {T} = _unpack_extension(io, 16, T)
unpack_format(io, ::Ext8Format, ::Type{T}) where {T} = _unpack_extension(io, read(io, UInt8), T)
unpack_format(io, ::Ext16Format, ::Type{T}) where {T} = _unpack_extension(io, ntoh(read(io, UInt16)), T)
unpack_format(io, ::Ext32Format, ::Type{T}) where {T} = _unpack_extension(io, ntoh(read(io, UInt32)), T)

function _unpack_extension(io, n, ::Type{T}) where {T}
    type = read(io, Int8)
    data = read(io, n)
    return from_msgpack(T, Extension(type, data))
end

#####
##### utilities
#####

@noinline function invalid_unpack(io, byte, m, T)
    error("invalid byte $(repr(byte)) encountered in $(io) attempting to read a MsgPack $(m) into a Julia $(T) at position $(position(io))")
end
