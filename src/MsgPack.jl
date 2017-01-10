module MsgPack

const INT_FP   = (0x00, 0x7f)
const MAP_F    = (0x80, 0x8f)
const ARR_F    = (0x90, 0x9f)
const STR_F    = (0xa0, 0xbf)

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

const EXT_F    = (0xd4, 0xd8)

const STR_8    = 0xd9
const STR_16   = 0xda
const STR_32   = 0xdb
const ARR_16   = 0xdc
const ARR_32   = 0xdd
const MAP_16   = 0xde
const MAP_32   = 0xdf

const INT_FN   = (0xe0, 0xff)

const TYPECODE_TO_TYPE = Dict{Int8, DataType}()

# For custom encoding.
function encode(x)::Vector{UInt8}
    tmp = [getfield(x, name) for name in fieldnames(x)]
    MsgPack.pack(tmp)
end

function decode{T}(::Type{T}, x::Vector{UInt8})::T
    args = MsgPack.unpack(x)
    T(args...)
end

"""
- Use function overloadiings instead of dict.
- Because we want to return typecode of the parent type if self is not defined.
- E.g., in parameteric types `A{T}`.
"""
get_typecode(T::DataType) = error("Type $T is not registered with a typecode")

function register{T}(::Type{T}, typecode::Integer)
    if haskey(TYPECODE_TO_TYPE, typecode)
        error("Type Code $typecode was already registered")
    end
    global get_typecode
    get_typecode(x::T)::Int8 = typecode
    TYPECODE_TO_TYPE[typecode] = T
end

immutable Ext
    typecode::Int8
    data::Vector{UInt8}

    function Ext(t::Integer, d::Vector{UInt8}; impltype::Bool=false)
        # -128 to -1 reserved for implementation
        if -128 <= t <= -1
            impltype || error("MsgPack Ext typecode -128 through -1 reserved by implementation")
        elseif !(0 <= t <= 127)
            error("MsgPack Ext typecode must be in the range [-128, 127]")
        end

        new(t, d)
    end
end

Base.:(==)(a::Ext, b::Ext) = a.typecode == b.typecode && a.data == b.data


readn(s::IO, t::DataType) = ntoh(read(s, t))
readi(s::IO, t::DataType) = Int64(readn(s, t))

"""
- Return `Int64` if in range.
- Otherwise fallback to `UInt64`.
"""
function read_u64(s::IO, t::DataType)
    v = UInt64(readn(s, t))
    if v > 2^63 - 1
        v
    else
        Int64(v)
    end
end


const UNPACK_OTHERS = Dict{UInt8, Function}(
    BIN_8  => s -> unpack_bin(s, readn(s, UInt8)),
    BIN_16 => s -> unpack_bin(s, readn(s, UInt16)),
    BIN_32 => s -> unpack_bin(s, readn(s, UInt32)),

    EXT_8  => s -> unpack_ext(s, readn(s, UInt8)),
    EXT_16 => s -> unpack_ext(s, readn(s, UInt16)),
    EXT_32 => s -> unpack_ext(s, readn(s, UInt32)),

    FLOAT_32 => s -> readn(s, Float32),
    FLOAT_64 => s -> readn(s, Float64),

    UINT_8  => s -> readi(s, UInt8),
    UINT_16 => s -> readi(s, UInt16),
    UINT_32 => s -> readi(s, UInt32),
    UINT_64 => s -> read_u64(s, UInt64),

    INT_8  => s -> readi(s, Int8),
    INT_16 => s -> readi(s, Int16),
    INT_32 => s -> readi(s, Int32),
    INT_64 => s -> readi(s, Int64),

    STR_8  => s -> unpack_str(s, readn(s, UInt8)),
    STR_16 => s -> unpack_str(s, readn(s, UInt16)),
    STR_32 => s -> unpack_str(s, readn(s, UInt32)),
    ARR_16 => s -> unpack_arr(s, readn(s, UInt16)),
    ARR_32 => s -> unpack_arr(s, readn(s, UInt32)),
    MAP_16 => s -> unpack_map(s, readn(s, UInt16)),
    MAP_32 => s -> unpack_map(s, readn(s, UInt32))
)


function unpack_others(s::IO, t::UInt8)
    f = try
        UNPACK_OTHERS[t]
    catch
        error("Wrong first byte $t")
    end
    f(s)
end


unpack(s) = unpack(IOBuffer(s))

function unpack(s::IO)
    b = read(s, UInt8)

    if b <= INT_FP[2]
        # positive fixint
        Int64(b)
    elseif b <= MAP_F[2]
        # fixmap
        unpack_map(s, b $ MAP_F[1])
    elseif b <= ARR_F[2]
        # fixarray
        unpack_arr(s, b $ ARR_F[1])
    elseif b <= STR_F[2]
        # fixstr
        unpack_str(s, b $ STR_F[1])
    elseif EXT_F[1] <= b <= EXT_F[2]
        # fixext
        unpack_ext(s, 2^(b - EXT_F[1]))
    elseif b == NIL
        nothing
    elseif b == UNUSED
        error("unused")
    elseif b == FALSE
        false
    elseif b == TRUE
        true
    elseif b <= MAP_32
        unpack_others(s, b)
    else
        # negative fixint
        Int64(reinterpret(Int8, b))
    end
end

# Make sure key is evaluated before value.
unpack_map(s::IO, n::Integer) = Dict(unpack(s) => unpack(s) for _ in 1:n)
unpack_arr(s::IO, n::Integer) = [unpack(s) for _ in 1:n]
unpack_str(s::IO, n::Integer) = String(read(s, n))


function unpack_ext(s::IO, n::Integer)
    typecode = read(s, Int8)
    data = read(s, n)

    T = get(TYPECODE_TO_TYPE, typecode, nothing)
    if T == nothing
        Ext(typecode, data, impltype=true)
    else
        decode(T, data)::T
    end
end

unpack_bin(s::IO, n::Integer) = read(s, n)

function wh(io::IO, head, v)
    write(io, head)
    write(io, hton(v))
end

function pack(v)
    s = IOBuffer()
    pack(s, v)
    takebuf_array(s)
end


pack(s::IO, ::Void) = write(s, NIL)
pack(s::IO, v::Bool) = v ? write(s, TRUE) : write(s, FALSE)

function pack(s::IO, v::Integer)
    if v < 0
        if v >= -32
            write(s, Int8(v))
        elseif v >= -2^7
            wh(s, INT_8, Int8(v))
        elseif v >= -2^15
            wh(s, INT_16, Int16(v))
        elseif v >= -2^31
            wh(s, INT_32, Int32(v))
        elseif v >= -2^63
            wh(s, INT_64, Int64(v))
        else
            error("MsgPack signed int overflow")
        end
    else
        if v <= 127
            write(s, UInt8(v))
        elseif v <= 2^8 - 1
            wh(s, UINT_8, UInt8(v))
        elseif v <= 2^16 - 1
            wh(s, UINT_16, UInt16(v))
        elseif v <= 2^32 - 1
            wh(s, UINT_32, UInt32(v))
        elseif v <= UInt64(2)^64 - 1
            wh(s, UINT_64, UInt64(v))
        else
            error("MsgPack unsigned int overflow")
        end
    end
end

pack(s::IO, v::Float32) = wh(s, FLOAT_32, v)
pack(s::IO, v::Float64) = wh(s, FLOAT_64, v)

# str format
function pack(s::IO, v::AbstractString)
    n = sizeof(v)
    if n < 2^5
        write(s, STR_F[1] | UInt8(n))
    ## Note: with this section commented out, we do not have
    ##       the most compact format for a string.  However,
    ##       the string is still in spec, and some other
    ##       msgpack libaries (*ahem* Python) can't decode
    ##       strings created with this rule.
    #elseif n < 2^8
    #    wh(s, STR_8, UInt8(n))
    elseif n < 2^16
        wh(s, STR_16, UInt16(n))
    elseif n < 2^32
        wh(s, STR_32, UInt32(n))
    else
        error("MsgPack str overflow: ", n)
    end
    write(s, v)
end

# ext format
function pack(s::IO, v::Ext)
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
        wh(s, EXT_8, UInt8(n))
    elseif n < 2^16
        wh(s, EXT_16, UInt16(n))
    elseif n < 2^32
        wh(s, EXT_32, UInt32(n))
    else
        error("MsgPack ext overflow: ", n)
    end
    write(s, v.typecode)
    write(s, v.data)
end

# bin format
function pack(s::IO, v::Vector{UInt8})
    n = length(v)
    if n < 2^8
        wh(s, BIN_8, UInt8(n))
    elseif n < 2^16
        wh(s, BIN_16, UInt16(n))
    elseif n < 2^32
        wh(s, BIN_32, UInt32(n))
    else
        error("MsgPack bin overflow: ", n)
    end
    write(s, v)
end

# Simple arrays
function pack(s::IO, v::Union{Vector, Tuple})
    n = length(v)
    if n < 2^4
        write(s, ARR_F[1] | UInt8(n))
    elseif n < 2^16
        wh(s, ARR_16, UInt16(n))
    elseif n < 2^32
        wh(s, ARR_32, UInt32(n))
    else
        error("MsgPack array overflow: ", n)
    end

    for x in v
        pack(s, x)
    end
end

# Maps
function pack(s::IO, v::Dict)
    n = length(v)
    if n < 2^4
        write(s, MAP_F[1] | UInt8(n))
    elseif n < 2^16
        wh(s, MAP_16, UInt16(n))
    elseif n < 2^32
        wh(s, MAP_32, UInt32(n))
    else
        error("MsgPack map overflow: ", n)
    end

    for (k, x) in v
        pack(s, k)
        pack(s, x)
    end
end


# Custom
function pack{T}(s::IO, v::T)
    typecode = get_typecode(v)
    data = encode(v)::Vector{UInt8}
    pack(s, Ext(typecode, data))
end



end
