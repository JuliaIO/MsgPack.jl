
module Msgpack

export pack


wh(io, head, v) = begin
    write(io, head)
    write(io, hton(v))
end

pack(v) = begin
    s = IOBuffer()
    pack(s, v)
    takebuf_array(s)
end

pack(s, nothing) = write(s, 0xc0)
pack(s, v::Bool) = if v write(s, 0xc2) else write(s, 0xc3) end

pack(s, v::Uint8)  = wh(s, 0xcc, v)
pack(s, v::Uint16) = wh(s, 0xcd, v)
pack(s, v::Uint32) = wh(s, 0xce, v)
pack(s, v::Uint64) = wh(s, 0xcf, v)

pack(s, v::Int8)  = wh(s, 0xd0, v)
pack(s, v::Int16) = wh(s, 0xd1, v)
pack(s, v::Int32) = wh(s, 0xd2, v)
pack(s, v::Int64) = wh(s, 0xd3, v)

pack(s, v::Float32) = wh(s, 0xca, v)
pack(s, v::Float64) = wh(s, 0xcb, v)

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
        error("Msgpack str format overflow: ", n)
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
        # TODO: break into multiple chunks?
        error("Msgpack bin format overflow: ", n)
    end
    write(s, v)
end


end # module
