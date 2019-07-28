@inline unpack(x) = unpack(x, Any)
@inline unpack(bytes, ::Type{T}) where {T} = unpack(IOBuffer(bytes), T)::T
@inline unpack(io::IO, ::Type{T}) where {T} = unpack_type(io, msgpack_type(T), T)::T

#####
##### `AnyType`
#####

@inline function unpack_type(io, t::AnyType, ::Type{T}) where {T}
    byte = read(io, UInt8)
    if byte <= magic_byte_max(IntFixPositiveFormat)
        return unpack_format(io, IntFixPositiveFormat(byte), T)
    elseif byte <= magic_byte_max(MapFixFormat)
        return unpack_format(io, MapFixFormat(byte), T)
    elseif byte <= magic_byte_max(ArrayFixFormat)
        return unpack_format(io, ArrayFixFormat(byte), T)
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
    elseif byte === magic_byte(Str8Format)
        return unpack_format(io, Str8Format(), T)
    elseif byte === magic_byte(Str16Format)
        return unpack_format(io, Str16Format(), T)
    elseif byte === magic_byte(Str32Format)
        return unpack_format(io, Str32Format(), T)
    elseif byte === magic_byte(TrueFormat)
        return from_msgpack(T, true)
    elseif byte === magic_byte(FalseFormat)
        return from_msgpack(T, false)
    elseif byte === magic_byte(NilFormat)
        return from_msgpack(T, nothing)
    elseif byte === magic_byte(Array16Format)
        return unpack_format(io, Array16Format(), T)
    elseif byte === magic_byte(Array32Format)
        return unpack_format(io, Array32Format(), T)
    elseif byte === magic_byte(Map16Format)
        return unpack_format(io, Map16Format(), T)
    elseif byte === magic_byte(Map32Format)
        return unpack_format(io, Map32Format(), T)
    elseif byte === magic_byte(Bin8Format)
        return unpack_format(io, Bin8Format(), T)
    elseif byte === magic_byte(Bin16Format)
        return unpack_format(io, Bin16Format(), T)
    elseif byte === magic_byte(Bin32Format)
        return unpack_format(io, Bin32Format(), T)
    elseif byte >= magic_byte_min(IntFixNegativeFormat)
        return unpack_format(io, IntFixNegativeFormat(byte), T)
    else
        invalid_unpack(io, byte, t, T)
    end
    # TODO Ext*Format
end

#####
##### `ImmutableStructType`
#####

@inline function unpack_type(io, ::ImmutableStructType, ::Type{T}) where {T}
    N = fieldcount(T)
    read(io, UInt8) > magic_byte_max(MapFixFormat) && read(io, UInt8)
    Base.@nexprs 32 i -> begin
        F_i = fieldtype(T, i)
        unpack_type(io, StringType(), Skip{Symbol})
        x_i = unpack_type(io, msgpack_type(F_i), F_i)
        N == i && return Base.@ncall i T x
    end
    others = Any[]
    for i in 33:N
        F_i = fieldtype(T, i)
        push!(others, unpack_type(io, msgpack_type(F_i), F_i))
    end
    return T(x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16,
             x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30,
             x31, x32, vals...)
end

@inline function unpack_type(io, ::ImmutableStructType, ::Type{Skip{T}}) where {T}
    N = fieldcount(T)
    read(io, UInt8) > magic_byte_max(MapFixFormat) && read(io, UInt8)
    Base.@nexprs 32 i -> begin
        F_i = fieldtype(T, i)
        unpack_type(io, StringType(), Skip{Symbol})
        unpack_type(io, msgpack_type(F_i), Skip{F_i})
        N == i && return Skip{T}()
    end
    for i in 33:N
        F_i = fieldtype(T, i)
        unpack_type(io, msgpack_type(F_i), Skip{F_i})
    end
    return Skip{T}()
end

#####
##### `MutableStructType`
#####

@inline function unpack_type(io, t::MutableStructType, ::Type{T}) where {T}
    N = fieldcount(T)
    byte = read(io, UInt8)
    if byte <= magic_byte_max(MapFixFormat)
        pair_count = xor(byte, magic_byte_min(MapFixFormat))
    elseif byte === magic_byte(Map16Format)
        pair_count = ntoh(read(io, UInt16))
    elseif byte === magic_byte(Map32Format)
        pair_count = ntoh(read(io, UInt32))
    else
        invalid_unpack(io, byte, t, T)
    end
    object = T()
    for _ in 1:pair_count
        key = unpack(io, Symbol) # TODO validation check?
        Base.@nif(32,
                  i -> i <= N && fieldname(T, i) === key,
                  i -> setfield!(object, i, unpack(io, fieldtype(T, i))),
                  i -> begin
                      is_field_still_unread = true
                      for j in 33:N
                          fieldname(T, j) === key || continue
                          setfield!(object, j, unpack(io, fieldtype(T, j)))
                          is_field_still_unread = false
                          break
                      end
                      is_field_still_unread && unpack(io)
                  end)
    end
    return object
end

@inline unpack_type(io, ::MutableStructType, ::Type{<:Skip}) = unpack_type(io, MapType(), Skip{Dict{Any,Any}})

#####
##### `IntegerType`
#####

@inline function unpack_type(io, t::IntegerType, ::Type{T}) where {T}
    byte = read(io, UInt8)
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
        return unpack_format(io, IntFixNegativeFormat(byte), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

@inline unpack_format(io, f::IntFixPositiveFormat, ::Type{T}) where {T} = from_msgpack(T, UInt8(f.byte))
@inline unpack_format(io, f::IntFixNegativeFormat, ::Type{T}) where {T} = from_msgpack(T, Int8(f.byte))

@inline unpack_format(io, f::IntFixPositiveFormat, ::Type{T}) where {T<:Skip} = T()
@inline unpack_format(io, f::IntFixNegativeFormat, ::Type{T}) where {T<:Skip} = T()

@inline unpack_format(io, ::UInt8Format, ::Type{T}) where {T} = from_msgpack(T, read(io, UInt8))
@inline unpack_format(io, ::UInt16Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, UInt16)))
@inline unpack_format(io, ::UInt32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, UInt32)))
@inline unpack_format(io, ::UInt64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, UInt64)))

@inline unpack_format(io, ::UInt8Format, ::Type{T}) where {T<:Skip} = (skip(io, 1); T())
@inline unpack_format(io, ::UInt16Format, ::Type{T}) where {T<:Skip} = (skip(io, 2); T())
@inline unpack_format(io, ::UInt32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())
@inline unpack_format(io, ::UInt64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

@inline unpack_format(io, ::Int8Format, ::Type{T}) where {T} = from_msgpack(T, read(io, Int8))
@inline unpack_format(io, ::Int16Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Int16)))
@inline unpack_format(io, ::Int32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Int32)))
@inline unpack_format(io, ::Int64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Int64)))

@inline unpack_format(io, ::Int8Format, ::Type{T}) where {T<:Skip} = (skip(io, 1); T())
@inline unpack_format(io, ::Int16Format, ::Type{T}) where {T<:Skip} = (skip(io, 2); T())
@inline unpack_format(io, ::Int32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())
@inline unpack_format(io, ::Int64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

#####
##### `NilType`
#####

@inline unpack_type(io, t::NilType, ::Type{T}) where {T} = unpack_format(io, t, T)
@inline unpack_type(io, ::NilType, ::Type{T}) where {T<:Skip} = (skip(io, 1); T())

@inline function unpack_format(io, f::NilFormat, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(NilFormat) && return from_msgpack(T, nothing)
    invalid_unpack(io, f, T)
end

#####
##### `BooleanType`
#####

@inline function unpack_type(io, t::BooleanType, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(TrueFormat) && return from_msgpack(T, true)
    byte === magic_byte(FalseFormat) && return from_msgpack(T, false)
    invalid_unpack(io, byte, t, T)
end

@inline unpack_type(io, ::BooleanType, ::Type{T}) where {T<:Skip} = (skip(io, 1); T())

@inline function unpack_format(io, f::TrueFormat, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(TrueFormat) && return from_msgpack(T, true)
    invalid_unpack(io, f, T)
end

@inline function unpack_format(io, f::FalseFormat, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(FalseFormat) && return from_msgpack(T, false)
    invalid_unpack(io, f, T)
end

#####
##### `FloatType`
#####

@inline function unpack_type(io, t::FloatType, ::Type{T}) where {T}
    byte = read(io, UInt8)
    if byte === magic_byte(Float32Format)
        return unpack_format(io, Float32Format(), T)
    elseif byte === magic_byte(Float64Format)
        return unpack_format(io, Float64Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

@inline unpack_format(io, ::Float32Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Float32)))
@inline unpack_format(io, ::Float32Format, ::Type{T}) where {T<:Skip} = (skip(io, 4); T())
@inline unpack_format(io, ::Float64Format, ::Type{T}) where {T} = from_msgpack(T, ntoh(read(io, Float64)))
@inline unpack_format(io, ::Float64Format, ::Type{T}) where {T<:Skip} = (skip(io, 8); T())

#####
##### `StringType`
#####

@inline function unpack_type(io, t::StringType, ::Type{T}) where {T}
    byte = read(io, UInt8)
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

@inline unpack_format(io, ::Str8Format, ::Type{T}) where {T} = _unpack_string(io, read(io, UInt8), T)
@inline unpack_format(io, ::Str16Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt16)), T)
@inline unpack_format(io, ::Str32Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt32)), T)
@inline unpack_format(io, f::StrFixFormat, ::Type{T}) where {T} = _unpack_string(io, xor(f.byte, magic_byte_min(StrFixFormat)), T)

@inline _unpack_string(io, n, ::Type{T}) where {T} = from_msgpack(T, String(read(io, n)))
@inline _unpack_string(io, n, ::Type{T}) where {T<:Skip} = (skip(io, n); T())

# Below is a nice optimization we can apply when `io` wraps an indexable byte
# buffer; this is really nice for skipping an extra copy when we deserialize
# the field names of `T` where `msgpack_type(T)::MutableStruct`. Like much of
# this package, this trick can be traced back to Jacob Quinn's magnificent
# JSON3.jl!
@inline function _unpack_string(io::Base.GenericIOBuffer, n, ::Type{T}) where {T}
    result = from_msgpack(T, PointerString(pointer(io.data, io.ptr), n))
    skip(io, n)
    return result
end

# necessary to resolve ambiguity
@inline _unpack_string(io::Base.GenericIOBuffer, n, ::Type{T}) where {T<:Skip} = (skip(io, n); T())

#####
##### `BinaryType`
#####

@inline function unpack_type(io, t::BinaryType, ::Type{T}) where {T}
    byte = read(io, UInt8)
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

@inline unpack_format(io, ::Bin8Format, ::Type{T}) where {T} = _unpack_binary(io, read(io, UInt8), T)
@inline unpack_format(io, ::Bin16Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt16)), T)
@inline unpack_format(io, ::Bin32Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt32)), T)

@inline _unpack_binary(io, n, ::Type{T}) where {T} = from_msgpack(T, read(io, n))
@inline _unpack_binary(io, n, ::Type{T}) where {T<:Skip} = (skip(io, n); T())

#####
##### `ArrayType`
#####

@inline function unpack_type(io, t::ArrayType, ::Type{T}) where {T}
    byte = read(io, UInt8)
    if byte <= magic_byte_max(ArrayFixFormat)
        return unpack_format(io, ArrayFixFormat(byte), T)
    elseif byte === magic_byte(Array16Format)
        return unpack_format(io, Array16Format(), T)
    elseif byte === magic_byte(Array32Format)
        return unpack_format(io, Array32Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

@inline unpack_format(io, ::Array16Format, ::Type{T}) where {T} = _unpack_array(io, ntoh(read(io, UInt16)), T)
@inline unpack_format(io, ::Array32Format, ::Type{T}) where {T} = _unpack_array(io, ntoh(read(io, UInt32)), T)
@inline unpack_format(io, f::ArrayFixFormat, ::Type{T}) where {T} = _unpack_array(io, xor(f.byte, magic_byte_min(ArrayFixFormat)), T)

@inline function _unpack_array(io, n, ::Type{T}) where {T}
    E = eltype(T)
    e = msgpack_type(E)
    result = Vector{E}(undef, n)
    for i in 1:n
        result[i] = unpack_type(io, e, E)
    end
    return from_msgpack(T, result)
end

@inline function _unpack_array(io, n, ::Type{Skip{T}}) where {T}
    E = eltype(T)
    e = msgpack_type(E)
    for _ in 1:n
        unpack_type(io, e, Skip{E})
    end
    return Skip{T}()
end

@inline function _unpack_array(io::Base.GenericIOBuffer, n, ::Type{T}) where {T<:ArrayView}
    E = eltype(T)
    e = msgpack_type(E)
    start = position(io)
    positions = Vector{UInt64}(undef, n)
    for i in 1:length(positions)
        positions[i] = (position(io) - start) + 1
        unpack_type(io, e, Skip{E})
    end
    bytes = view(io.data, (start + 1):position(io))
    return ArrayView{E}(bytes, positions)
end

#####
##### `MapType`
#####

@inline function unpack_type(io, t::MapType, ::Type{T}) where {T}
    byte = read(io, UInt8)
    if byte <= magic_byte_max(MapFixFormat)
        return unpack_format(io, MapFixFormat(byte), T)
    elseif byte === magic_byte(Map16Format)
        return unpack_format(io, Map16Format(), T)
    elseif byte === magic_byte(Map32Format)
        return unpack_format(io, Map32Format(), T)
    else
        invalid_unpack(io, byte, t, T)
    end
end

@inline unpack_format(io, ::Map16Format, ::Type{T}) where {T} = _unpack_map(io, ntoh(read(io, UInt16)), T)
@inline unpack_format(io, ::Map32Format, ::Type{T}) where {T} = _unpack_map(io, ntoh(read(io, UInt32)), T)
@inline unpack_format(io, f::MapFixFormat, ::Type{T}) where {T} = _unpack_map(io, xor(f.byte, magic_byte_min(MapFixFormat)), T)

@inline _keytype(T) = Any
@inline _keytype(::Type{T}) where {T<:AbstractDict} = keytype(T)
@inline _valtype(T) = Any
@inline _valtype(::Type{T}) where {T<:AbstractDict} = valtype(T)

@inline function _unpack_map(io, n, ::Type{T}) where {T}
    K = _keytype(T)
    k = msgpack_type(K)
    V = _valtype(T)
    v = msgpack_type(V)
    dict = Dict{K,V}()
    for _ in 1:n
        key = unpack_type(io, k, K)
        val = unpack_type(io, v, V)
        dict[key] = val
    end
    return from_msgpack(T, dict)
end

@inline function _unpack_map(io, n, ::Type{Skip{T}}) where {T}
    K = _keytype(T)
    k = msgpack_type(K)
    V = _valtype(T)
    v = msgpack_type(V)
    for i in 1:n
        unpack_type(io, k, Skip{K})
        unpack_type(io, v, Skip{V})
    end
    return Skip{T}()
end

@inline function _unpack_map(io::Base.GenericIOBuffer, n, ::Type{T}) where {T<:MapView}
    K = _keytype(T)
    k = msgpack_type(K)
    V = _valtype(T)
    v = msgpack_type(V)
    start = position(io)
    positions = Vector{Pair{UInt64,UInt64}}(undef, n)
    for i in 1:length(positions)
        key_position = (position(io) - start) + 1
        unpack_type(io, k, Skip{K})
        value_position = (position(io) - start) + 1
        unpack_type(io, v, Skip{V})
        positions[i] = key_position => value_position
    end
    bytes = view(io.data, (start + 1):position(io))
    return MapView{K,V}(bytes, positions)
end

#####
##### `ExtensionType`
#####
# TODO

#####
##### utilities
#####

@noinline function invalid_unpack(io, byte, m, T)
    error("invalid byte $(repr(byte)) encountered in $(io) attempting to read a MsgPack $(m) into a Julia $(T) at position $(position(io))")
end
