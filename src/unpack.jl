@inline unpack(x) = unpack(x, Any)
@inline unpack(bytes, ::Type{T}) where {T} = unpack(IOBuffer(bytes), T)::T
@inline unpack(io::IO, ::Type{T}) where {T} = unpack_type(io, msgpacktype(T), T)::T

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
        return construct(T, true)
    elseif byte === magic_byte(FalseFormat)
        return construct(T, false)
    elseif byte === magic_byte(NilFormat)
        return construct(T, nothing)
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
        F_i = fieldtype(T, i) # TODO should skip field names
        x_i = unpack_type(io, msgpacktype(F_i), F_i)
        N == i && return Base.@ncall i T x
    end
    others = Any[]
    for i = 33:N
        F_i = fieldtype(T, i)
        push!(others, unpack_type(io, msgpacktype(F_i), F_i))
    end
    return T(x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16,
             x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29, x30,
             x31, x32, vals...)
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

@inline unpack_format(io, f::IntFixPositiveFormat, ::Type{T}) where {T} = construct(T, UInt8(f.byte))
@inline unpack_format(io, f::IntFixNegativeFormat, ::Type{T}) where {T} = construct(T, Int8(f.byte))

@inline unpack_format(io, ::UInt8Format, ::Type{T}) where {T} = construct(T, read(io, UInt8))
@inline unpack_format(io, ::UInt16Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, UInt16)))
@inline unpack_format(io, ::UInt32Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, UInt32)))
@inline unpack_format(io, ::UInt64Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, UInt64)))

@inline unpack_format(io, ::Int8Format, ::Type{T}) where {T} = construct(T, read(io, Int8))
@inline unpack_format(io, ::Int16Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, Int16)))
@inline unpack_format(io, ::Int32Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, Int32)))
@inline unpack_format(io, ::Int64Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, Int64)))

#####
##### `NilType`
#####

@inline unpack_type(io, t::NilType, ::Type{T}) where {T} = unpack_format(io, t, T)

@inline function unpack_format(io, f::NilFormat, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(NilFormat) && return construct(T, nothing)
    invalid_unpack(io, f, T)
end

#####
##### `BooleanType`
#####

@inline function unpack_type(io, t::BooleanType, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(TrueFormat) && return construct(T, true)
    byte === magic_byte(FalseFormat) && return construct(T, false)
    invalid_unpack(io, byte, t, T)
end

@inline function unpack_format(io, f::TrueFormat, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(TrueFormat) && return construct(T, true)
    invalid_unpack(io, f, T)
end

@inline function unpack_format(io, f::FalseFormat, ::Type{T}) where {T}
    byte = read(io, UInt8)
    byte === magic_byte(FalseFormat) && return construct(T, false)
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

@inline unpack_format(io, ::Float32Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, Float32)))
@inline unpack_format(io, ::Float64Format, ::Type{T}) where {T} = construct(T, ntoh(read(io, Float64)))

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

@inline unpack_format(io, ::Str8Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt8)), T)
@inline unpack_format(io, ::Str16Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt16)), T)
@inline unpack_format(io, ::Str32Format, ::Type{T}) where {T} = _unpack_string(io, ntoh(read(io, UInt32)), T)
@inline unpack_format(io, f::StrFixFormat, ::Type{T}) where {T} = _unpack_string(io, xor(f.byte, magic_byte_min(StrFixFormat)), T)

@inline _unpack_string(io, n, ::Type{T}) where {T} = construct(T, String(read(io, n)))

# Below is a nice optimization we can apply when `io` wraps an indexable byte
# buffer; this is really nice for skipping an extra copy when we deserialize
# the field names of `T` where `msgpacktype(T)::MutableStruct`. Like much of
# this package, this trick can be traced back to Jacob Quinn's magnificent
# JSON3.jl!

struct PointerString
    ptr::Ptr{UInt8}
    len::Int
end

@inline construct(::Type{Symbol}, x::PointerString) = ccall(:jl_symbol_n, Ref{Symbol}, (Ptr{UInt8}, Int), x.ptr, x.len)
@inline construct(::Type{PointerString}, x::PointerString) = x
@inline construct(S::Type, x::PointerString) = construct(S, unsafe_string(x.ptr, x.len))

@inline function _unpack_string(io::Base.GenericIOBuffer, n, ::Type{T}) where {T}
    result = construct(T, PointerString(pointer(io.data, io.ptr), n))
    skip(io, n)
    return result
end

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

@inline unpack_format(io, ::Bin8Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt8)), T)
@inline unpack_format(io, ::Bin16Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt16)), T)
@inline unpack_format(io, ::Bin32Format, ::Type{T}) where {T} = _unpack_binary(io, ntoh(read(io, UInt32)), T)

@inline _unpack_binary(io, n, ::Type{T}) where {T} = construct(T, read(io, n))

#####
##### `array` format
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
    e = msgpacktype(E)
    return construct(T, E[unpack_type(io, e, E) for _ in 1:n])
end

#####
##### `map` format
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
    k = msgpacktype(K)
    V = _valtype(T)
    v = msgpacktype(V)
    dict = Dict{K,V}()
    for _ in 1:n
        key = unpack_type(io, k, K)
        val = unpack_type(io, v, V)
        dict[key] = val
    end
    return construct(T, dict)
end

#####
##### utilities
#####

@noinline function invalid_unpack(io, byte, m, T)
    error("invalid byte $(repr(byte)) encountered in $(io) attempting to read a MsgPack $(m) into a Julia $(T) at position $(position(io))")
end
