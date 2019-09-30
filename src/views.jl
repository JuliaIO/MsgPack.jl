#####
##### `ArrayView`
#####

"""
    ArrayView{T} <: AbstractVector{T}

A Julia struct that wraps a MessagePack byte buffer to provide an immutable
view of the MessagePack Array stored within the wrapped byte buffer.

This type is intended to be utilized via [`unpack`](@ref). For example, a call
to `arr = unpack(bytes, ArrayView{Dict{String,Int32}})` will generally return
a value more quickly than `arr = unpack(bytes, Vector{Dict{String,Int32}})`;
the latter will perform full deserialization immediately while the former will
only scan over `bytes` to tag the positions of `arr`'s elements, deferring the
actual deserialization of these elements to the time of their access via
`arr[index]`.

Note that `ArrayView` does not implement any form of caching - repeat accesses
of the same element will re-deserialize the element upon every access.
"""
struct ArrayView{T,B<:AbstractVector{UInt8},S<:Tuple} <: AbstractVector{T}
    bytes::B
    positions::Vector{UInt64}
    strict::S
    ArrayView{T}(bytes::B, positions, strict::S=()) where {T,B,S} = new{T,B,S}(bytes, positions, strict)
end

Base.IndexStyle(::Type{<:ArrayView}) = Base.IndexLinear()

Base.size(arr::ArrayView) = (length(arr.positions),)

Base.@propagate_inbounds function Base.getindex(arr::ArrayView{T}, i::Int) where {T}
    @boundscheck checkbounds(arr, i)
    @inbounds start = arr.positions[i]
    @inbounds stop = i == length(arr) ? length(arr.bytes) : arr.positions[i + 1]
    @inbounds current_bytes = view(arr.bytes, start:stop)
    return unpack(current_bytes, T; strict=arr.strict)
end

#####
##### `MapView`
#####

"""
    MapView{K,V} <: AbstractDict{K,V}

Similar to [`ArrayView`](@ref), but provides an immutable view to a MessagePack
Map rather than a MessagePack Array.

This type is intended to be utilized via [`unpack`](@ref) in the same manner as
`ArrayView`, and is similarly implements a "delay-deserialization-until-access"
mechanism.
"""
struct MapView{K,V,B<:AbstractVector{UInt8},S<:Tuple} <: AbstractDict{K,V}
    bytes::B
    positions::Dict{K,UnitRange{UInt64}}
    strict::S
    MapView{K,V}(bytes::B, positions, strict::S=()) where {K,V,B,S} = new{K,V,B,S}(bytes, positions, strict)
end

Base.length(m::MapView) = length(m.positions)

function _get_by_position(m::MapView{K,V}, position) where {K,V}
    return unpack(view(m.bytes, position), V; strict=m.strict)
end

Base.get(m::MapView, key) = _get_by_position(m, m.positions[key])

Base.haskey(m::MapView, key) = haskey(m.positions, key)

function Base.get(m::MapView, key, default)
    haskey(m, key) && return get(m, key)
    return default
end

function Base.get(default::Base.Callable, m::MapView, key)
    haskey(m, key) && return get(m, key)
    return default()
end

function Base.iterate(m::MapView, prev...)
    x = iterate(m.positions, prev...)
    x isa Nothing && return nothing
    (key, position), state = x
    return key => _get_by_position(m, position), state
end

Base.keys(m::MapView) = keys(m.positions)

Base.values(m::MapView) = (_get_by_position(m, i) for i in values(m.positions))
