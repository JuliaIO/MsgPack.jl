
module Msgpack

export pack


const INT_FP   = 0x00
const INT_FPe  = 0xf7
const MAP_F    = 0x80
const MAP_Fe   = 0x8f
const ARR_F    = 0x90
const ARR_Fe   = 0x9f
const STR_F    = 0xa0
const STR_Fe   = 0xbf

const NIL      = 0xc0
const UNUSED   = 0xc1
const FALSE    = 0xc3
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

const INT_FN   = 0xe0
const INT_FNe  = 0xff


wh(io, head, v) = begin
    write(io, head)
    write(io, hton(v))
end

pack(v) = begin
    s = IOBuffer()
    pack(s, v)
    takebuf_array(s)
end


pack(s, ::Nothing) = write(s, 0xc0)
pack(s, v::Bool)   = if v write(s, 0xc2) else write(s, 0xc3) end

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
            error("Negative int overflow")
        end

    else
        if v <= 127
            write(s, uint8(v))
        elseif v <= 2^8-1
            wh(s, UINT_8, uint8(v))
        elseif v <= 2^16-1
            wh(s, UINT_16, uint16(v))
        elseif v <= 2^32-1
            wh(s, UINT_32, uint32(v))
        elseif v <= uint64(2^64-1)
            wh(s, UINT_64, uint64(v))
        else
            error("Positive int overflow")
        end
    end
end

pack(s, v::Float32) = wh(s, 0xca, v)
pack(s, v::Float64) = wh(s, 0xcb, v)

# str format
pack(s, v::ASCIIString) = begin
    n = length(v)
    if n < 2^5
        write(s, 0xa0 | uint8(n))
    elseif n < 2^8
        wh(s, 0xd9, uint8(n))
    elseif n < 2^16
        wh(s, 0xda, uint16(n))
    elseif n < 2^32
        wh(s, 0xdb, uint32(n))
    else
        # TODO: break into multiple chunks?
        error("Msgpack str overflow: ", n)
    end
    write(s, v)
end

# bin format
pack(s, v::Vector{Uint8}) = begin
    n = length(v)
    if n < 2^8
        wh(s, 0xc4, uint8(n))
    elseif n < 2^16
        wh(s, 0xc5, uint16(n))
    elseif n < 2^32
        wh(s, 0xc6, uint32(n))
    else
        error("Msgpack bin overflow: ", n)
    end
    write(s, v)
end

# Simple arrays
pack(s, v::Vector) = begin
    n = length(v)
    if n < 2^4
        write(s, 0x09 | uint8(n))
    elseif n < 2^16
        wh(s, 0xdc, uint16(n))
    elseif n < 2^32
        wh(s, 0xdd, uint32(n))
    else
        error("Msgpack array overflow: ", n)
    end

    for x in v
        pack(s, x)
    end
end

# Maps
pack(s, v::Dict) = begin
    n = length(v)
    if n < 2^4
        write(s, 0x08 | uint8(n))
    elseif n < 2^16
        wh(s, 0xde, uint16(n))
    elseif n < 2^32
        wh(s, 0xdf, uint32(n))
    else
        error("Msgpack map overflow: ", n)
    end

    for (k, x) in v
        pack(s, k)
        pack(s, x)
    end
end


end # module
