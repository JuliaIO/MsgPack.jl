"""
    pack(x)

Serialize `x` to MessagePack format and return the resulting `Vector{UInt8}`.

This function uses [`msgpack_type`](@ref) and [`to_msgpack`](@ref) to determine
the appropriate translation of the `value` into MessagePack format.

See also: [`unpack`](@ref)
"""
function pack(x)
    io = IOBuffer(UInt8[]; append = true)
    pack(io, x)
    return take!(io)
end

"""
    pack(io::IO, x)

Like `pack(x)`, but write the resulting bytes to `io`. Returns `nothing`.

See also: [`unpack`](@ref)
"""
function pack(io::IO, x)
    pack_type(io, msgpack_type(typeof(x)), x)
    return nothing
end

#####
##### `AnyType`
#####

# This function might've been reached via another `pack_type` method that
# relied on reflection and ended up calling `msgpack_type` on a type that
# didn't have a non-`AnyType` mapping, even if the underlying value it's trying
# serialize does (e.g. an object field with a `Union` type). Thus, before giving
# up, we first attempt to resolve the issue by calling `msgpack_type(typeof(x))`
# directly.
function pack_type(io, t::AnyType, x)
    tx = msgpack_type(typeof(x))
    if tx isa AnyType
        error("no non-`AnyType` MsgPack mapping found for ", typeof(x), "; please ",
              "overload `msgpack_type` for this type.")
    end
    return pack_type(io, tx, x)
end

#####
##### `StructType`
#####

function pack_type(io, t::StructType, x::T) where {T}
    N = fieldcount(T)
    if N <= 15
        write(io, magic_byte_min(MapFixFormat) | UInt8(N))
    elseif N <= typemax(UInt16)
        write(io, magic_byte(Map16Format))
        write(io, hton(UInt16(N)))
    elseif N <= typemax(UInt32)
        write(io, magic_byte(Map32Format))
        write(io, hton(UInt32(N)))
    else
        invalid_pack(io, t, x)
    end
    Base.@nexprs 32 i -> begin
        F_i = fieldtype(T, i)
        pack_type(io, StringType(), fieldname(T, i))
        pack_type(io, msgpack_type(fieldtype(T, i)), getfield(x, i))
        N == i && return nothing
    end
    for i in 33:N
        F_i = fieldtype(T, i)
        pack_type(io, StringType(), fieldname(T, i))
        pack_type(io, msgpack_type(fieldtype(T, i)), getfield(x, i))
    end
    return nothing
end

#####
##### `IntegerType`
#####

function pack_type(io, t::IntegerType, x)
    x = to_msgpack(t, x)
    if x < 0
        x >= -32 && return pack_format(io, IntFixNegativeFormat(Int8(x)))
        x >= typemin(Int8) && return pack_format(io, Int8Format(), x)
        x >= typemin(Int16) && return pack_format(io, Int16Format(), x)
        x >= typemin(Int32) && return pack_format(io, Int32Format(), x)
        x >= typemin(Int64) && return pack_format(io, Int64Format(), x)
    else
        x <= 127 && return pack_format(io, IntFixPositiveFormat(UInt8(x)))
        x <= typemax(UInt8) && return pack_format(io, UInt8Format(), x)
        x <= typemax(UInt16) && return pack_format(io, UInt16Format(), x)
        x <= typemax(UInt32) && return pack_format(io, UInt32Format(), x)
        x <= typemax(UInt64) && return pack_format(io, UInt64Format(), x)
    end
    invalid_pack(io, t, x)
end

pack_format(io, f::Union{IntFixNegativeFormat,IntFixPositiveFormat}) = write(io, f.byte)
pack_format(io, f::Int8Format, x) = _pack_integer(io, f, Int8, x)
pack_format(io, f::Int16Format, x) = _pack_integer(io, f, Int16, x)
pack_format(io, f::Int32Format, x) = _pack_integer(io, f, Int32, x)
pack_format(io, f::Int64Format, x) = _pack_integer(io, f, Int64, x)
pack_format(io, f::UInt8Format, x) = _pack_integer(io, f, UInt8, x)
pack_format(io, f::UInt16Format, x) = _pack_integer(io, f, UInt16, x)
pack_format(io, f::UInt32Format, x) = _pack_integer(io, f, UInt32, x)
pack_format(io, f::UInt64Format, x) = _pack_integer(io, f, UInt64, x)

function _pack_integer(io, ::F, ::Type{T}, x) where {F,T}
    y = hton(T(x))
    write(io, magic_byte(F))
    write(io, y)
end

#####
##### `NilType`
#####

pack_type(io, ::NilType, x) = pack_format(io, NilFormat(), x)

pack_format(io, ::NilFormat, ::Any) = write(io, magic_byte(NilFormat))

#####
##### `BooleanType`
#####

function pack_type(io, t::BooleanType, x)
    x = to_msgpack(t, x)
    x == true && return pack_format(io, TrueFormat(), x)
    x == false && return pack_format(io, FalseFormat(), x)
    invalid_pack(io, t, x)
end

pack_format(io, ::TrueFormat, ::Any) = write(io, magic_byte(TrueFormat))
pack_format(io, ::FalseFormat, ::Any) = write(io, magic_byte(FalseFormat))

#####
##### `FloatType`
#####

function pack_type(io, t::FloatType, x)
    x = to_msgpack(t, x)
    x isa Float32 && return pack_format(io, Float32Format(), x)
    x isa Float64 && return pack_format(io, Float64Format(), x)
    invalid_pack(io, t, x)
end

function pack_format(io, ::Float32Format, x)
    y = Float32(x)
    write(io, magic_byte(Float32Format))
    write(io, hton(y))
end

function pack_format(io, ::Float64Format, x)
    y = Float64(x)
    write(io, magic_byte(Float64Format))
    write(io, hton(y))
end

#####
##### `CFloatType`
#####

function pack_type(io, t::ComplexFType, x)
    x = to_msgpack(t, x)
    x isa ComplexF32 && return pack_format(io, ComplexF32Format(), x)
    x isa ComplexF64 && return pack_format(io, ComplexF64Format(), x)
    invalid_pack(io, t, x)
end

function pack_format(io, ::ComplexF32Format, x)
    y = Vector{Float32}(undef,2*length(x))
    y[1:2:end] .= Float32(real(x))
    y[2:2:end] .= Float32(imag(x))
    write(io, magic_byte(ComplexF32Format))
    write(io, hton(y))
end

function pack_format(io, ::ComplexF64Format, x)
    y = Vector{Float64}(undef,2)
    y[1] = Float64(real(x))
    y[2] = Float64(imag(x))
    write(io, magic_byte(ComplexF64Format))
    write(io, hton.(y))
end

#####
##### `StringType`
#####

function pack_type(io, t::StringType, x)
    x = to_msgpack(t, x)
    n = x isa PointerString ? x.len : sizeof(x)
    n <= 31 && return pack_format(io, StrFixFormat(magic_byte_min(StrFixFormat) | UInt8(n)), x)
    n <= typemax(UInt8) && return pack_format(io, Str8Format(), x)
    n <= typemax(UInt16) && return pack_format(io, Str16Format(), x)
    n <= typemax(UInt32) && return pack_format(io, Str32Format(), x)
    invalid_pack(io, t, x)
end

function pack_format(io, f::StrFixFormat, x)
    write(io, f.byte)
    write(io, x)
end

function pack_format(io, ::Str8Format, x)
    write(io, magic_byte(Str8Format))
    write(io, UInt8(sizeof(x)))
    write(io, x)
end

function pack_format(io, ::Str16Format, x)
    write(io, magic_byte(Str16Format))
    write(io, hton(UInt16(sizeof(x))))
    write(io, x)
end

function pack_format(io, ::Str32Format, x)
    write(io, magic_byte(Str32Format))
    write(io, hton(UInt32(sizeof(x))))
    write(io, x)
end

#####
##### `BinaryType`
#####

function pack_type(io, t::BinaryType, x)
    x = to_msgpack(t, x)
    n = length(x)
    n <= typemax(UInt8) && return pack_format(io, Bin8Format(), x)
    n <= typemax(UInt16) && return pack_format(io, Bin16Format(), x)
    n <= typemax(UInt32) && return pack_format(io, Bin32Format(), x)
    invalid_pack(io, t, x)
end

function pack_format(io, ::Bin8Format, x)
    write(io, magic_byte(Bin8Format))
    write(io, UInt8(length(x)))
    write(io, x)
end

function pack_format(io, ::Bin16Format, x)
    write(io, magic_byte(Bin16Format))
    write(io, hton(UInt16(length(x))))
    write(io, x)
end

function pack_format(io, ::Bin32Format, x)
    write(io, magic_byte(Bin32Format))
    write(io, hton(UInt32(length(x))))
    write(io, x)
end

#####
##### `ArrayType`
#####

function pack_type(io, t::ArrayType, x)
    x = to_msgpack(t, x)
    n = length(x)
    n <= 15 && return pack_format(io, ArrayFixFormat(magic_byte_min(ArrayFixFormat) | UInt8(n)), x)
    n <= typemax(UInt16) && return pack_format(io, Array16Format(), x)
    n <= typemax(UInt32) && return pack_format(io, Array32Format(), x)
    invalid_pack(io, t, x)
end

function pack_format(io, f::ArrayFixFormat, x)
    write(io, f.byte)
    for i in x
        pack(io, i)
    end
end

function pack_format(io, ::Array16Format, x)
    write(io, magic_byte(Array16Format))
    write(io, hton(UInt16(length(x))))
    for i in x
        pack(io, i)
    end
end

function pack_format(io, ::Array32Format, x)
    write(io, magic_byte(Array32Format))
    write(io, hton(UInt32(length(x))))
    for i in x
        pack(io, i)
    end
end

#####
##### `MapType`
#####

function pack_type(io, t::MapType, x)
    x = to_msgpack(t, x)
    n = length(x)
    n <= 15 && return pack_format(io, MapFixFormat(magic_byte_min(MapFixFormat) | UInt8(n)), x)
    n <= typemax(UInt16) && return pack_format(io, Map16Format(), x)
    n <= typemax(UInt32) && return pack_format(io, Map32Format(), x)
    invalid_pack(io, t, x)
end

function pack_format(io, f::MapFixFormat, x)
    write(io, f.byte)
    for (k, v) in x
        pack(io, k)
        pack(io, v)
    end
end

function pack_format(io, ::Map16Format, x)
    write(io, magic_byte(Map16Format))
    write(io, hton(UInt16(length(x))))
    for (k, v) in x
        pack(io, k)
        pack(io, v)
    end
end

function pack_format(io, ::Map32Format, x)
    write(io, magic_byte(Map32Format))
    write(io, hton(UInt32(length(x))))
    for (k, v) in x
        pack(io, k)
        pack(io, v)
    end
end

#####
##### `ExtensionType`
#####

function pack_type(io, t::ExtensionType, x)
    x = to_msgpack(t, x)::Extension
    n = length(x.data)
    n == 1 && return pack_format(io, ExtFix1Format(), x)
    n == 2 && return pack_format(io, ExtFix2Format(), x)
    n == 4 && return pack_format(io, ExtFix4Format(), x)
    n == 8 && return pack_format(io, ExtFix8Format(), x)
    n == 16 && return pack_format(io, ExtFix16Format(), x)
    n <= typemax(UInt8) && return pack_format(io, Ext8Format(), x)
    n <= typemax(UInt16) && return pack_format(io, Ext16Format(), x)
    n <= typemax(UInt32) && return pack_format(io, Ext32Format(), x)
    invalid_pack(io, t, x)
end

const ExtFixFormat = Union{ExtFix1Format,ExtFix2Format,ExtFix4Format,ExtFix8Format,ExtFix16Format}

function pack_format(io, ::F, x::Extension) where {F<:ExtFixFormat}
    write(io, magic_byte(F))
    write(io, x.type)
    write(io, x.data)
end

function pack_format(io, ::Ext8Format, x::Extension)
    write(io, magic_byte(Ext8Format))
    write(io, UInt8(length(x.data)))
    write(io, x.type)
    write(io, x.data)
end

function pack_format(io, ::Ext16Format, x::Extension)
    write(io, magic_byte(Ext16Format))
    write(io, hton(UInt16(length(x.data))))
    write(io, x.type)
    write(io, x.data)
end

function pack_format(io, ::Ext32Format, x::Extension)
    write(io, magic_byte(Ext32Format))
    write(io, hton(UInt32(length(x.data))))
    write(io, x.type)
    write(io, x.data)
end

#####
##### utilities
#####

@noinline function invalid_pack(io, t, x)
    error("cannot serialize Julia value $(x) as MsgPack type $(t) to $(io)")
end
