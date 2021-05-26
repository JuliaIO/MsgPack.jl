abstract type AbstractMsgPackFormat end

#####
##### `int` family
#####

# `fixint`

struct IntFixPositiveFormat <: AbstractMsgPackFormat
    byte::UInt8
end

struct IntFixNegativeFormat <: AbstractMsgPackFormat
    byte::Int8
end

Base.@pure magic_byte_min(::Type{IntFixPositiveFormat}) = 0x00
Base.@pure magic_byte_max(::Type{IntFixPositiveFormat}) = 0x7f
Base.@pure magic_byte_min(::Type{IntFixNegativeFormat}) = 0xe0
Base.@pure magic_byte_max(::Type{IntFixNegativeFormat}) = 0xff

# `uint`

struct UInt8Format <: AbstractMsgPackFormat end
struct UInt16Format <: AbstractMsgPackFormat end
struct UInt32Format <: AbstractMsgPackFormat end
struct UInt64Format <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{UInt8Format}) = 0xcc
Base.@pure magic_byte(::Type{UInt16Format}) = 0xcd
Base.@pure magic_byte(::Type{UInt32Format}) = 0xce
Base.@pure magic_byte(::Type{UInt64Format}) = 0xcf

# `int`

struct Int8Format <: AbstractMsgPackFormat end
struct Int16Format <: AbstractMsgPackFormat end
struct Int32Format <: AbstractMsgPackFormat end
struct Int64Format <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{Int64Format}) = 0xd3
Base.@pure magic_byte(::Type{Int32Format}) = 0xd2
Base.@pure magic_byte(::Type{Int16Format}) = 0xd1
Base.@pure magic_byte(::Type{Int8Format}) = 0xd0

#####
##### `nil` family
#####

struct NilFormat <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{NilFormat}) = 0xc0

#####
##### `bool` family
#####

struct FalseFormat <: AbstractMsgPackFormat end
struct TrueFormat <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{FalseFormat}) = 0xc2
Base.@pure magic_byte(::Type{TrueFormat}) = 0xc3

#####
##### `float` family
#####

struct Float32Format <: AbstractMsgPackFormat end
struct Float64Format <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{Float32Format}) = 0xca
Base.@pure magic_byte(::Type{Float64Format}) = 0xcb

#####
##### `Cfloat` family (unsupported by the conventional MsgPack spec)
#####

struct ComplexF32Format <: AbstractMsgPackFormat end
struct ComplexF64Format <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{ComplexF32Format}) = 0x28
Base.@pure magic_byte(::Type{ComplexF64Format}) = 0x29

#####
##### `str` family
#####

struct StrFixFormat <: AbstractMsgPackFormat
    byte::UInt8
end

struct Str8Format <: AbstractMsgPackFormat end
struct Str16Format <: AbstractMsgPackFormat end
struct Str32Format <: AbstractMsgPackFormat end

Base.@pure magic_byte_min(::Type{StrFixFormat}) = 0xa0
Base.@pure magic_byte_max(::Type{StrFixFormat}) = 0xbf
Base.@pure magic_byte(::Type{Str8Format}) = 0xd9
Base.@pure magic_byte(::Type{Str16Format}) = 0xda
Base.@pure magic_byte(::Type{Str32Format}) = 0xdb

#####
##### `bin` family
#####

struct Bin8Format <: AbstractMsgPackFormat end
struct Bin16Format <: AbstractMsgPackFormat end
struct Bin32Format <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{Bin8Format}) = 0xc4
Base.@pure magic_byte(::Type{Bin16Format}) = 0xc5
Base.@pure magic_byte(::Type{Bin32Format}) = 0xc6

#####
##### `array` family
#####

struct ArrayFixFormat <: AbstractMsgPackFormat
    byte::UInt8
end

struct Array16Format <: AbstractMsgPackFormat end
struct Array32Format <: AbstractMsgPackFormat end

Base.@pure magic_byte_min(::Type{ArrayFixFormat}) = 0x90
Base.@pure magic_byte_max(::Type{ArrayFixFormat}) = 0x9f
Base.@pure magic_byte(::Type{Array16Format}) = 0xdc
Base.@pure magic_byte(::Type{Array32Format}) = 0xdd

#####
##### `map` family
#####

struct MapFixFormat <: AbstractMsgPackFormat
    byte::UInt8
end

struct Map16Format <: AbstractMsgPackFormat end
struct Map32Format <: AbstractMsgPackFormat end

Base.@pure magic_byte_min(::Type{MapFixFormat}) = 0x80
Base.@pure magic_byte_max(::Type{MapFixFormat}) = 0x8f
Base.@pure magic_byte(::Type{Map16Format}) = 0xde
Base.@pure magic_byte(::Type{Map32Format}) = 0xdf

#####
##### `ext` family
#####

struct ExtFix1Format <: AbstractMsgPackFormat end
struct ExtFix2Format <: AbstractMsgPackFormat end
struct ExtFix4Format <: AbstractMsgPackFormat end
struct ExtFix8Format <: AbstractMsgPackFormat end
struct ExtFix16Format <: AbstractMsgPackFormat end
struct Ext8Format <: AbstractMsgPackFormat end
struct Ext16Format <: AbstractMsgPackFormat end
struct Ext32Format <: AbstractMsgPackFormat end

Base.@pure magic_byte(::Type{ExtFix1Format}) = 0xd4
Base.@pure magic_byte(::Type{ExtFix2Format}) = 0xd5
Base.@pure magic_byte(::Type{ExtFix4Format}) = 0xd6
Base.@pure magic_byte(::Type{ExtFix8Format}) = 0xd7
Base.@pure magic_byte(::Type{ExtFix16Format}) = 0xd8
Base.@pure magic_byte(::Type{Ext8Format}) = 0xc7
Base.@pure magic_byte(::Type{Ext16Format}) = 0xc8
Base.@pure magic_byte(::Type{Ext32Format}) = 0xc9
