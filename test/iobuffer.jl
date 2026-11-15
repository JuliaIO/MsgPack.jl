@testset "IOBuffer primitive writes" begin
    # Independent wire bytes, including floating-point payload bits.
    network_bytes(x) = UInt8[
        parse(UInt8, bitstring(x)[i:i+7]; base=2) for i in 1:8:8sizeof(x)
    ]
    values = (
        UInt16(0x0102), UInt32(0x01020304), UInt64(0x0102030405060708),
        UInt128(0x0102030405060708090a0b0c0d0e0f10),
        typemin(Int16), typemin(Int32), typemin(Int64), typemin(Int128),
        Float16(1.5), Float32(-0.0), Float64(1.5),
        reinterpret(Float64, UInt64(0x7ff8000000000001)),
    )

    @testset "maxsize and short writes" begin
        # Oversized physical storage exposes the logical-limit bug without an
        # out-of-allocation write; small storage also exercises safe growth.
        for x in values, capacity in (0, 1, 64), append in (false, true)
            bytes = network_bytes(x)
            for limit in unique((0, 1, length(bytes) - 1, length(bytes)))
                io = IOBuffer(zeros(UInt8, capacity);
                              read=true, write=true, truncate=true, maxsize=limit, append)
                @test MsgPack.write_be(io, x) === nothing
                @test position(io) == (append ? 0 : limit)
                @test take!(io) == bytes[1:limit]
            end
        end
    end

    @testset "shifted backing storage grows without dropping bytes" begin
        for x in values, append in (false, true)
            storage = fill(0x55, 4096)
            deleteat!(storage, 1:77)
            io = IOBuffer(storage; read=true, write=true, append)
            seekend(io)
            MsgPack.write_be(io, x)
            @test position(io) == 4019 + (append ? 0 : sizeof(x))
            @test take!(io) == vcat(fill(0x55, 4019), network_bytes(x))
        end
    end

    @testset "shifted backing storage with finite maxsize" begin
        # On Julia 1.11+, deleting a vector prefix can leave a nonzero Memory
        # offset. maxsize limits the logical buffer, not its absolute indices.
        for x in values, append in (false, true), limit in (0, 1, sizeof(x), 32)
            storage = fill(0x55, 4096)
            deleteat!(storage, 1:4076)
            io = IOBuffer(storage; read=true, write=true, truncate=true, maxsize=limit, append)
            MsgPack.write_be(io, x)
            written = min(limit, sizeof(x))
            @test position(io) == (append ? 0 : written)
            @test take!(io) == network_bytes(x)[1:written]
        end
    end

    @testset "overwrite, append, growth and reuse" begin
        for x in values
            bytes = network_bytes(x)
            io = IOBuffer(sizehint=1)
            MsgPack.write_be(io, x)
            @test take!(io) == bytes
            # take! may leave the buffer needing reinitialization.
            MsgPack.write_be(io, x)
            @test take!(io) == bytes

            io = IOBuffer(fill(0x55, 64); read=true, write=true)
            seek(io, 3)
            MsgPack.write_be(io, x)
            expected = fill(0x55, 64)
            expected[4:3+sizeof(x)] = bytes
            @test position(io) == 3 + sizeof(x)
            @test take!(io) == expected

            io = IOBuffer(fill(0x55, 3); read=true, write=true, append=true)
            seek(io, 1)
            MsgPack.write_be(io, x)
            @test position(io) == 1
            @test take!(io) == vcat(fill(0x55, 3), bytes)

            io = IOBuffer(sizehint=128)
            write(io, fill(0x55, 64))
            truncate(io, 3)
            seekend(io)
            MsgPack.write_be(io, x)
            @test take!(io) == vcat(fill(0x55, 3), bytes)
        end
        @test_throws ArgumentError MsgPack.write_be(IOBuffer(UInt8[0x55]), UInt64(1))
    end

    @testset "PipeBuffer compaction" begin
        for marked in (false, true)
            io = PipeBuffer(maxsize=8192)
            write(io, fill(0x55, 8192))
            read(io, 6000)
            marked && mark(io)
            read(io, 1000)
            x = UInt64(0x0102030405060708)
            MsgPack.write_be(io, x)
            @test read(io) == vcat(fill(0x55, 1192), network_bytes(x))
        end
    end

    @testset "pack respects the remaining buffer space" begin
        for x in (UInt64(0x0102030405060708), -123456789, 1.5)
            bytes = pack(x)
            for limit in 0:length(bytes), append in (false, true)
                io = IOBuffer(zeros(UInt8, 64);
                              read=true, write=true, truncate=true, maxsize=limit, append)
                pack(io, x)
                @test take!(io) == bytes[1:limit]
            end
        end
    end
end
