module MsgPack

using Compat

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
readi(s, t) = @compat Int64(readn(s, t))

readu64(s, t) = begin
    v = @compat UInt64(readn(s, t))
    if v > 2^63-1
        v
    else
        @compat Int64(v)
    end
end


function dispatch_fb(t::UInt8; ext_hook=nothing)
    if t == NIL
        s -> nothing
    elseif t == UNUSED
        error("unused")
    elseif t == FALSE
        s -> false  
    elseif t == TRUE
        s -> true  
    elseif t == BIN_8
        s -> unpack_bin(s, readn(s, UInt8))   
    elseif t == BIN_16
        s -> unpack_bin(s, readn(s, UInt16)) 
    elseif t == BIN_32
        s -> unpack_bin(s, readn(s, UInt32))   
    elseif t == EXT_8
        s -> unpack_ext(s, readn(s, UInt8), ext_hook=ext_hook) 
    elseif t == EXT_16
        s -> unpack_ext(s, readn(s, UInt16), ext_hook=ext_hook)
    elseif t == EXT_32
        s -> unpack_ext(s, readn(s, UInt32), ext_hook=ext_hook)
    elseif t == FLOAT_32
        s -> readn(s, Float32) 
    elseif t == FLOAT_64
        s -> readn(s, Float64)  
    elseif t == UINT_8
        s -> readi(s, UInt8)  
    elseif t == UINT_16 
        s -> readi(s, UInt16)  
    elseif t == UINT_32 
        s -> readi(s, UInt32)  
    elseif t == UINT_64 
        s -> readu64(s, UInt64) 
    elseif t == INT_8
        s -> readi(s, Int8)  
    elseif t == INT_16  
        s -> readi(s, Int16)  
    elseif t == INT_32 
        s -> readi(s, Int32)  
    elseif t == INT_64  
        s -> readi(s, Int64) 
    elseif t == STR_8
        s -> unpack_str(s, readn(s, UInt8))    
    elseif t == STR_16
        s -> unpack_str(s, readn(s, UInt16)) 
    elseif t == STR_32
        s -> unpack_str(s, readn(s, UInt32))  
    elseif t == ARR_16
        s -> unpack_arr(s, readn(s, UInt16), ext_hook=ext_hook) 
    elseif t == ARR_32
        s -> unpack_arr(s, readn(s, UInt32), ext_hook=ext_hook)   
    elseif t == MAP_16
        s -> unpack_map(s, readn(s, UInt16), ext_hook=ext_hook)  
    elseif t == MAP_32
        s -> unpack_map(s, readn(s, UInt32), ext_hook=ext_hook) 
    else
        error("Wrong first byte $t")
    end
end


unpack(s; ext_hook=nothing) = unpack(IOBuffer(s), ext_hook=ext_hook)

function unpack(s::IO; ext_hook=nothing)

    b = read(s, UInt8)

    if b <= 0x7f
        # positive fixint
        @compat Int64(b)

    elseif b <= 0x8f
        # fixmap
        unpack_map(s, b $ MAP_F, ext_hook=ext_hook)

    elseif b <= 0x9f
        # fixarray
        unpack_arr(s, b $ ARR_F, ext_hook=ext_hook)

    elseif b <= 0xbf
        # fixstr
        unpack_str(s, b $ STR_F)

    elseif 0xd4 <= b <= 0xd8
        # fixext
        unpack_ext(s, 2^(b - EXT_F), ext_hook=ext_hook)

    elseif b <= 0xdf
        dispatch_fb(b, ext_hook=ext_hook)(s)

    else
        # negative fixint
        @compat Int64(reinterpret(Int8, b))
    end
end

unpack_map(s, n; ext_hook=nothing) = begin
    out = Dict()
    for i in 1:n
        k = unpack(s, ext_hook=ext_hook)
        v = unpack(s, ext_hook=ext_hook)
        out[k] = v
    end
    out
end

unpack_arr(s, n; ext_hook=nothing) = begin
    out = Array(Any, n)
    for i in 1:n
        out[i] = unpack(s, ext_hook=ext_hook)
    end
    out
end

unpack_str(s, n) = utf8(readbytes(s, n))

function unpack_ext(s, n; ext_hook=nothing)
    raw_ext = Ext(read(s, Int8), readbytes(s, n), impltype=true)
    if ext_hook == nothing
        raw_ext
    else
        ext_hook(raw_ext)
    end
end
 
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


@compat pack(s, ::Void) = write(s, NIL)
pack(s, v::Bool)   = if v write(s, TRUE) else write(s, FALSE) end

pack(s, v::Integer) = begin
    if v < 0
        if v >= -32
            write(s, @compat Int8(v))
        elseif v >= -2^7
            wh(s, INT_8, @compat Int8(v))
        elseif v >= -2^15
            wh(s, INT_16, @compat Int16(v))
        elseif v >= -2^31
            wh(s, INT_32, @compat Int32(v))
        elseif v >= -2^63
            wh(s, INT_64, @compat Int64(v))
        else
            error("MsgPack signed int overflow")
        end
    else
        if v <= 127
            write(s, @compat UInt8(v))
        elseif v <= 2^8-1
            wh(s, UINT_8, @compat UInt8(v))
        elseif v <= 2^16-1
            wh(s, UINT_16, @compat UInt16(v))
        elseif v <= 2^32-1
            wh(s, UINT_32, @compat UInt32(v))
        elseif v <= @compat UInt64(2)^64-1
            wh(s, UINT_64, @compat UInt64(v))
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
        write(s, STR_F | @compat UInt8(n))
    ## Note: with this section commented out, we do not have
    ##       the most compact format for a string.  However,
    ##       the string is still in spec, and some other
    ##       msgpack libaries (*ahem* Python) can't decode
    ##       strings created with this rule.
    #elseif n < 2^8
    #    wh(s, 0xd9, @compat UInt8(n))
    elseif n < 2^16
        wh(s, 0xda, @compat UInt16(n))
    elseif n < 2^32
        wh(s, 0xdb, @compat UInt32(n))
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
        wh(s, 0xc7, @compat UInt8(n))
    elseif n < 2^16
        wh(s, 0xc8, @compat UInt16(n))
    elseif n < 2^32
        wh(s, 0xc9, @compat UInt32(n))
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
        wh(s, 0xc4, @compat UInt8(n))
    elseif n < 2^16
        wh(s, 0xc5, @compat UInt16(n))
    elseif n < 2^32
        wh(s, 0xc6, @compat UInt32(n))
    else
        error("MsgPack bin overflow: ", n)
    end
    write(s, v)
end

# Simple arrays
pack(s, @compat v::Union{Vector, Tuple}) = begin
    n = length(v)
    if n < 2^4
        write(s, ARR_F | @compat UInt8(n))
    elseif n < 2^16
        wh(s, 0xdc, @compat UInt16(n))
    elseif n < 2^32
        wh(s, 0xdd, @compat UInt32(n))
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
        write(s, MAP_F | @compat UInt8(n))
    elseif n < 2^16
        wh(s, 0xde, @compat UInt16(n))
    elseif n < 2^32
        wh(s, 0xdf, @compat UInt32(n))
    else
        error("MsgPack map overflow: ", n)
    end

    for (k, x) in v
        pack(s, k)
        pack(s, x)
    end
end


end # module
