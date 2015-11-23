module MsgPack

export pack, unpack, Ext
import Base: == 

const INT_FP   = 0x00 # - 0xf7
const MAP_F    = 0x80 # - 0x8f
const ARR_F    = 0x90 # - 0x9f
const STR_F    = 0xa0 # - 0xbf
const EXT_F    = 0xd4 # - 0xd8

const NIL      = 0xc0
const UNUSED   = 0xc1
const FALSE    = 0xc2
const TRUE     = 0xc3
const BIN_8    = 0xc4
const BIN_16   = 0xc5
const BIN_32   = 0xc6
const EXT_8    = 0xc7
const EXT_16   = 0xc8
const EXT_32   = 0xc9
const FLOAT_32 = 0xca
const FLOAT_64 = 0xcb
const UINT_8   = 0xcc
const UINT_16  = 0xcd
const UINT_32  = 0xce
const UINT_64  = 0xcf
const INT_8    = 0xd0
const INT_16   = 0xd1
const INT_32   = 0xd2
const INT_64   = 0xd3
const STR_8    = 0xd9
const STR_16   = 0xda
const STR_32   = 0xdb
const ARR_16   = 0xdc
const ARR_32   = 0xdd
const MAP_16   = 0xde
const MAP_32   = 0xdf

const INT_FN   = 0xe0 # - 0xff

immutable Ext
    typecode::Int8
    data::Vector{UInt8}

    function Ext(t::Integer, d::Vector{UInt8}; impltype=false)
        # -128 to -1 reserved for implementation
        if -128 <= t <= -1
            impltype || error("MsgPack Ext typecode -128 through -1 reserved by implementation")
        elseif !(0 <= t <= 127)
            error("MsgPack Ext typecode must be in the range [-128, 127]")
        end

        new(t, d)
    end
end
==(a::Ext, b::Ext) = a.typecode == b.typecode && a.data == b.data

# return Ext where Ext.data is a serialized object
function extserialize(t::Integer, d)
    i = IOBuffer()
    serialize(i, d)
    return Ext(t, takebuf_array(i))
end

# return (typecode, object) from an Ext where Ext.data is a serialized object
extdeserialize(e::Ext) = (e.typecode, deserialize(IOBuffer(e.data)))


readn(s, t) = ntoh(read(s, t))
readi(s, t) = int64(readn(s, t))

readu64(s, t) = begin
    v = UInt64(readn(s, t))
    if v > 2^63-1
        v
    else
        int64(v)
    end
end

const DISPATCH =
    Dict( NIL      => s -> nothing
     ,UNUSED   => s -> error("unused")
     ,FALSE    => s -> false
     ,TRUE     => s -> true
     ,BIN_8    => s -> unpack_bin(s, readn(s, UInt8))
     ,BIN_16   => s -> unpack_bin(s, readn(s, UInt16))
     ,BIN_32   => s -> unpack_bin(s, readn(s, UInt32))
     ,EXT_8    => s -> unpack_ext(s, readn(s, UInt8))
     ,EXT_16   => s -> unpack_ext(s, readn(s, UInt16))
     ,EXT_32   => s -> unpack_ext(s, readn(s, UInt32))
     ,FLOAT_32 => s -> readn(s, Float32)
     ,FLOAT_64 => s -> readn(s, Float64)
     ,UINT_8   => s -> readi(s, UInt8)
     ,UINT_16  => s -> readi(s, UInt16)
     ,UINT_32  => s -> readi(s, UInt32)
     ,UINT_64  => s -> readu64(s, UInt64)
     ,INT_8    => s -> readi(s, Int8)
     ,INT_16   => s -> readi(s, Int16)
     ,INT_32   => s -> readi(s, Int32)
     ,INT_64   => s -> readi(s, Int64)
     ,STR_8    => s -> unpack_str(s, readn(s, UInt8))
     ,STR_16   => s -> unpack_str(s, readn(s, UInt16))
     ,STR_32   => s -> unpack_str(s, readn(s, UInt32))
     ,ARR_16   => s -> unpack_arr(s, readn(s, UInt16))
     ,ARR_32   => s -> unpack_arr(s, readn(s, UInt32))
     ,MAP_16   => s -> unpack_map(s, readn(s, UInt16))
     ,MAP_32   => s -> unpack_map(s, readn(s, UInt32))
)

unpack(s) = unpack(IOBuffer(s))
unpack(s::IO) = begin
    b = read(s, UInt8)

    if b <= 0x7f
        # positive fixint
        int64(b)

    elseif b <= 0x8f
        # fixmap
        unpack_map(s, b $ MAP_F)

    elseif b <= 0x9f
        # fixarray
        unpack_arr(s, b $ ARR_F)

    elseif b <= 0xbf
        # fixstr
        unpack_str(s, b $ STR_F)

    elseif 0xd4 <= b <= 0xd8
        # fixext
        unpack_ext(s, 2^(b - EXT_F))

    elseif b <= 0xdf
        DISPATCH[b](s)

    else
        # negative fixint
        int64(reinterpret(Int8, b))
    end
end

unpack_map(s, n) = begin
    out = Dict()
    for i in 1:n
        k = unpack(s)
        v = unpack(s)
        out[k] = v
    end
    out
end

unpack_arr(s, n) = begin
    out = Array(Any, n)
    for i in 1:n
        out[i] = unpack(s)
    end
    out
end

unpack_str(s, n) = utf8(readbytes(s, n))
unpack_ext(s, n) = Ext(read(s, Int8), readbytes(s, n), impltype=true)
unpack_bin(s, n) = readbytes(s, n)

wh(io, head, v) = begin
    write(io, head)
    write(io, hton(v))
end

pack(v) = begin
    s = IOBuffer()
    pack(s, v)
    takebuf_array(s)
end


pack(s, ::Void) = write(s, NIL)
pack(s, v::Bool)   = if v write(s, TRUE) else write(s, FALSE) end

pack(s, v::Integer) = begin
    if v < 0
        if v >= -32
            write(s, int8(v))
        elseif v >= -2^7
            wh(s, INT_8, int8(v))
        elseif v >= -2^15
            wh(s, INT_16, int16(v))
        elseif v >= -2^31
            wh(s, INT_32, int32(v))
        elseif v >= -2^63
            wh(s, INT_64, int64(v))
        else
            error("MsgPack signed int overflow")
        end
    else
        if v <= 127
            write(s, UInt8(v))
        elseif v <= 2^8-1
            wh(s, UINT_8, UInt8(v))
        elseif v <= 2^16-1
            wh(s, UINT_16, UInt16(v))
        elseif v <= 2^32-1
            wh(s, UINT_32, UInt32(v))
        elseif v <= UInt64(2)^64-1
            wh(s, UINT_64, UInt64(v))
        else
            error("MsgPack unsigned int overflow")
        end
    end
end

pack(s, v::Float32) = wh(s, 0xca, v)
pack(s, v::Float64) = wh(s, 0xcb, v)

# str format
pack(s, v::AbstractString) = begin
    n = sizeof(v)
    if n < 2^5
        write(s, STR_F | UInt8(n))
    ## Note: with this section commented out, we do not have 
    ##       the most compact format for a string.  However, 
    ##       the string is still in spec, and some other
    ##       msgpack libaries (*ahem* Python) can't decode
    ##       strings created with this rule.
    #elseif n < 2^8
    #    wh(s, 0xd9, UInt8(n))
    elseif n < 2^16
        wh(s, 0xda, UInt16(n))
    elseif n < 2^32
        wh(s, 0xdb, UInt32(n))
    else
        error("MsgPack str overflow: ", n)
    end
    write(s, v)
end

# ext format
pack(s, v::Ext) = begin
    n = sizeof(v.data)
    if n == 1
        write(s, 0xd4)
    elseif n == 2
        write(s, 0xd5)
    elseif n == 4
        write(s, 0xd6)
    elseif n == 8
        write(s, 0xd7)
    elseif n == 16
        write(s, 0xd8)
    elseif n < 2^8
        wh(s, 0xc7, UInt8(n))
    elseif n < 2^16
        wh(s, 0xc8, UInt16(n))
    elseif n < 2^32
        wh(s, 0xc9, UInt32(n))
    else
        error("MsgPack ext overflow: ", n)
    end
    write(s, v.typecode)
    write(s, v.data)
end

# bin format
pack(s, v::Vector{UInt8}) = begin
    n = length(v)
    if n < 2^8
        wh(s, 0xc4, UInt8(n))
    elseif n < 2^16
        wh(s, 0xc5, UInt16(n))
    elseif n < 2^32
        wh(s, 0xc6, UInt32(n))
    else
        error("MsgPack bin overflow: ", n)
    end
    write(s, v)
end

# Simple arrays
pack(s, v::Union{Vector, Tuple}) = begin
    n = length(v)
    if n < 2^4
        write(s, ARR_F | UInt8(n))
    elseif n < 2^16
        wh(s, 0xdc, UInt16(n))
    elseif n < 2^32
        wh(s, 0xdd, UInt32(n))
    else
        error("MsgPack array overflow: ", n)
    end

    for x in v
        pack(s, x)
    end
end

# Maps
pack(s, v::Dict) = begin
    n = length(v)
    if n < 2^4
        write(s, MAP_F | UInt8(n))
    elseif n < 2^16
        wh(s, 0xde, UInt16(n))
    elseif n < 2^32
        wh(s, 0xdf, UInt32(n))
    else
        error("MsgPack map overflow: ", n)
    end

    for (k, x) in v
        pack(s, k)
        pack(s, x)
    end
end


end # module
