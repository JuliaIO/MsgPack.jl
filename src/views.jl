#####
##### `ArrayView`
#####

struct ArrayView{T,B<:AbstractVector{UInt8}} <: AbstractVector{T}
    bytes::B
    positions::Vector{UInt64}
    ArrayView{T}(bytes::B, positions) where {T,B} = new{T,B}(bytes, positions)
end

Base.IndexStyle(::Type{<:ArrayView}) = Base.IndexLinear()

Base.size(arr::ArrayView) = (length(arr.positions),)

Base.@propagate_inbounds function Base.getindex(arr::ArrayView{T}, i::Int) where {T}
    @boundscheck checkbounds(arr, i)
    @inbounds start = arr.positions[i]
    @inbounds stop = i == length(arr) ? length(arr.bytes) : arr.positions[i + 1]
    @inbounds current_bytes = view(arr.bytes, start:stop)
    return unpack(current_bytes, T)
end

#####
##### `MapView`
#####

struct MapView{K,V,B<:AbstractVector{UInt8}} <: AbstractDict{K,V}
    bytes::B
    positions::Vector{Pair{UInt64,UInt64}}
    MapView{K,V}(bytes::B, positions) where {K,V,B} = new{K,V,B}(bytes, positions)
end

Base.length(m::MapView) = length(m.positions)

function _get(m::MapView, i, j, ::Type{T}) where {T}
    start = m.positions[i][j]
    stop = i == length(m) ? length(m.bytes) : m.positions[i + 1][j]
    current_bytes = view(m.bytes, start:stop)
    return unpack(current_bytes, T)
end

_get_key(m::MapView, i) = _get(m, i, 1, keytype(m))

_get_value(m::MapView, i) = _get(m, i, 2, valtype(m))

function Base.get(m::MapView, key)
    for i in 1:length(m)
        _get_key(m, i) == key && return _get_value(m, i)
    end
    throw(KeyError(key))
end

function Base.get(m::MapView, key, default)
    for i in 1:length(m)
        _get_key(m, i) == key && return _get_value(m, i)
    end
    return default
end

function Base.get(default::Base.Callable, m::MapView, key)
    for i in 1:length(m)
        _get_key(m, i) == key && return _get_value(m, i)
    end
    return default()
end

Base.iterate(m::MapView) = iterate(m, 1)

function Base.iterate(m::MapView, i)
    i > length(m) && return nothing
    result = _get_key(m, i) => _get_value(m, i)
    return result, i + 1
end

Base.keys(m::MapView) = (_get_key(m, i) for i in 1:length(m))

Base.values(m::MapView) = (_get_value(m, i) for i in 1:length(m))
