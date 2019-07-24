module MsgPack

import Compat: take!, xor

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

struct Ext
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
    return Ext(t, take!(i))
end

# return (typecode, object) from an Ext where Ext.data is a serialized object
extdeserialize(e::Ext) = (e.typecode, deserialize(IOBuffer(e.data)))


readn(s, t) = ntoh(read(s, t))
readi(s, t) = Int64(readn(s, t))

function readu64(s, t)
    v = UInt64(readn(s, t))
    if v > 2^63-1
        v
    else
        Int64(v)
    end
end

unpack(s) = unpack(IOBuffer(s))
unpack(bytes::Vector) = unpack(IOBuffer(bytes))
unpack(io::IO) = unpack_buffer(io)

function unpack_buffer(s::IO)
    b = read(s, UInt8)

    if b <= 0x7f
        # positive fixint
        Int64(b)

    elseif b <= 0x8f
        # fixmap
        unpack_map(s, xor(b, MAP_F))

    elseif b <= 0x9f
        # fixarray
        unpack_arr(s, xor(b, ARR_F))

    elseif b <= 0xbf
        # fixstr
        unpack_str(s, xor(b, STR_F))

    elseif 0xd4 <= b <= 0xd8
        # fixext
        unpack_ext(s, 2^(b - EXT_F))
    elseif b == NIL
        nothing
    elseif b == UNUSED
        error("unused")
    elseif b == FALSE
        false
    elseif b == TRUE
        true
    elseif b == BIN_8
        unpack_bin(s, readn(s, UInt8))
    elseif b == BIN_16
        unpack_bin(s, readn(s, UInt16))
    elseif b == BIN_32
        unpack_bin(s, readn(s, UInt32))
    elseif b == EXT_8
        unpack_ext(s, readn(s, UInt8))
    elseif b == EXT_16
        unpack_ext(s, readn(s, UInt16))
    elseif b == EXT_32
        unpack_ext(s, readn(s, UInt32))
    elseif b == FLOAT_32
        readn(s, Float32)
    elseif b == FLOAT_64
        readn(s, Float64)
    elseif b == UINT_8
        readi(s, UInt8)
    elseif b == UINT_16
        readi(s, UInt16)
    elseif b == UINT_32
        readi(s, UInt32)
    elseif b == UINT_64
        readu64(s, UInt64)
    elseif b == INT_8
        readi(s, Int8)
    elseif b == INT_16
        readi(s, Int16)
    elseif b == INT_32
        readi(s, Int32)
    elseif b == INT_64
        readi(s, Int64)
    elseif b == STR_8
        unpack_str(s, readn(s, UInt8))
    elseif b == STR_16
        unpack_str(s, readn(s, UInt16))
    elseif b == STR_32
        unpack_str(s, readn(s, UInt32))
    elseif b == ARR_16
        unpack_arr(s, readn(s, UInt16))
    elseif b == ARR_32
        unpack_arr(s, readn(s, UInt32))
    elseif b == MAP_16
        unpack_map(s, readn(s, UInt16))
    elseif b == MAP_32
        unpack_map(s, readn(s, UInt32))
    else
        # negative fixint
        Int64(reinterpret(Int8, b))
    end
end

function unpack_map(s, n)
    out = Dict()
    for i in 1:n
        k = unpack_buffer(s)
        v = unpack_buffer(s)
        out[k] = v
    end
    out
end

function unpack_arr(s, n)
    Any[unpack_buffer(s) for i in 1:n]
end

unpack_str(s, n) = String(read(s, n))
unpack_ext(s, n) = Ext(read(s, Int8), read(s, n), impltype=true)
unpack_bin(s, n) = read(s, n)

function wh(io, head, v)
    write(io, head)
    write(io, hton(v))
end

function pack(v)
    s = IOBuffer()
    pack(s, v)
    take!(s)
end


pack(s, ::Nothing) = write(s, NIL)
pack(s, v::Bool)   = if v write(s, TRUE) else write(s, FALSE) end

function pack(s, v::Integer)
    if v < 0
        if v >= -32
            write(s, Int8(v))
        elseif v >= -2^7
            wh(s, INT_8, Int8(v))
        elseif v >= -2^15
            wh(s, INT_16, Int16(v))
        elseif v >= -2^31
            wh(s, INT_32, Int32(v))
        elseif v >= -Int64(2)^63
            wh(s, INT_64, Int64(v))
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
        elseif v <= UInt64(2)^32-1
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
function pack(s, v::AbstractString)
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
    elseif n < UInt64(2)^32
        wh(s, 0xdb, UInt32(n))
    else
        error("MsgPack str overflow: ", n)
    end
    write(s, v)
end

# ext format
function pack(s, v::Ext)
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
    elseif n < UInt64(2)^32
        wh(s, 0xc9, UInt32(n))
    else
        error("MsgPack ext overflow: ", n)
    end
    write(s, v.typecode)
    write(s, v.data)
end

# bin format
function pack(s, v::Vector{UInt8})
    n = length(v)
    if n < 2^8
        wh(s, 0xc4, UInt8(n))
    elseif n < 2^16
        wh(s, 0xc5, UInt16(n))
    elseif n < UInt64(2)^32
        wh(s, 0xc6, UInt32(n))
    else
        error("MsgPack bin overflow: ", n)
    end
    write(s, v)
end

# Simple arrays
function pack(s, v::Union{Vector, Tuple})
    n = length(v)
    if n < 2^4
        write(s, ARR_F | UInt8(n))
    elseif n < 2^16
        wh(s, 0xdc, UInt16(n))
    elseif n < UInt64(2)^32
        wh(s, 0xdd, UInt32(n))
    else
        error("MsgPack array overflow: ", n)
    end

    for x in v
        pack(s, x)
    end
end

# Maps
function pack(s, v::Dict)
    n = length(v)
    if n < 2^4
        write(s, MAP_F | UInt8(n))
    elseif n < 2^16
        wh(s, 0xde, UInt16(n))
    elseif n < UInt64(2)^32
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
