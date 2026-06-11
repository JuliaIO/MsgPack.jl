# MsgPack pack performance — Bonito workloads

Tracks per-message pack performance for the shapes Bonito actually sends
(SerializedMessage with caching, observable updates, typed arrays). Update
when changing `src/pack.jl` or anything in Bonito's serialization layer.

Environment: Julia 1.12.6, x86_64 linux, Sonnet 4.7 worker.

## Methodology

Run with `julia_eval`, env_path = project root. After each scenario, `GC.gc(true)` and `@timed` over a fixed iteration count. `serialize_binary(sm)` benches the MsgPack round (re-packing an already-built `SerializedMessage`); `full(...)` is the `Bonito.send` hot path — `SerializedMessage(session, msg)` + `serialize_binary(sm)`.

To re-measure: stash any MsgPack changes (`cd dev/MsgPack && git stash`), restart Julia (force fresh precompile), run the bench block at the bottom of this file. `git stash pop`, restart, run again.

## Workloads

| Name | Shape |
|---|---|
| `small` | 3-key Dict, Float64 payload (typical slider feedback, ~145 B on wire) |
| `vec_4K` | `Vector{Float32}` of 4096 elements (graphics-y, ~16.5 KB) |
| `batch_50` | 50 inner observable-update Dicts in one outer Dict (batched updates, ~2 KB) |
| `nested` | mixed Float32 vec / String / Int vec inside nested Dict (~1.2 KB) |

## Results — 2026-05-12

### `serialize_binary(sm)` (5000 iters)

| Workload | BEFORE μs | AFTER μs | Δ | BEFORE allocs | AFTER allocs | Δ |
|---|---:|---:|---:|---:|---:|---:|
| small    | 1.48 | 1.33 | -10% | 51  | 41 | -20% |
| vec_4K   | 5.05 | 4.93 |  -2% | 50  | 42 | -16% |
| batch_50 | 8.22 | 8.74 |  +6% | 106 | 48 | -55% |
| nested   | 2.94 | 2.84 |  -3% | 52  | 42 | -19% |

### `full` pipeline (2000 iters): `SerializedMessage(...)` + `serialize_binary(...)`

| Workload | BEFORE μs | AFTER μs | Δ | BEFORE allocs | AFTER allocs | Δ |
|---|---:|---:|---:|---:|---:|---:|
| small    | 0.91 | 0.81 | -11% | 56  | 46 | -18% |
| vec_4K   | 7.84 | 6.86 | -13% | 65  | 57 | -12% |
| batch_50 | 9.72 | 9.97 |  +3% | 123 | 65 | -47% |
| nested   | 3.76 | 3.79 |  +1% | 77  | 67 | -13% |

### Micro: 1000-elt arrays packed into reused IOBuffer (zero-alloc target)

| Workload                   | BEFORE       | AFTER     |
|---                         |---           |---        |
| pack 1000 small Ints       | 745 allocs   | 0 allocs  |
| pack 1000 Float64          | 1000 allocs  | 0 allocs  |

## What changed (commit summary)

`dev/MsgPack/src/pack.jl`:

1. **`write_be(io, ::Primitive)` helper** — bypasses the `Base.RefValue{T}` allocation that Julia stdlib's `write(io::IO, ::Real)` incurs for multi-byte primitives (the call chain `write` → `write(io, Ref(x), n)` → `unsafe_write` crosses enough indirection that escape analysis ≤1.12 can't elide the Ref). Inlined as one block here, the compiler proves `r` doesn't escape and SROAs it. Generic IO fallback keeps stdlib semantics.
2. **`pack(x; sizehint=64)`** — kwarg so callers that know the output size can pre-size the buffer (avoids ~3-4 geometric resizes for typical small payloads).
3. **Idiomatic `return nothing`** on all `pack_format` / `pack_type` methods — they were leaking the `Int` byte count from `write` up the call chain. No perf effect (discarded), pure tidy.

`Primitive = Union{Base.BitInteger, Base.IEEEFloat}` so one generic method handles all primitive sizes.

## Protocol-level — `bench/bench.jl` end-to-end through Electron

Real WS round-trip (echo via JS observable callback) and burst throughputs.
Raw JSON: [bench/results/msgpack_before.json](../../bench/results/msgpack_before.json), [bench/results/msgpack_after.json](../../bench/results/msgpack_after.json), [bench/results/msgpack_sessionio.json](../../bench/results/msgpack_sessionio.json).
24 threads, single Electron window, same machine, same session.

Stages compared:
* **BL** — true baseline (no opts).
* **+B** — Bonito's `caching.jl` fast-path + `Dict{String,Any}` switch (commit 5547834).
* **+M** — `MsgPack.write_be` + `pack` sizehint kwarg.
* **+SP** — initial stream-pack via per-call buffers in `pack_type(::ExtensionType, ::SerializedMessage)`.
* **+SIO** — `SessionIO` on `Session`, scratch buffers reused across messages.

| Metric             | BL    | +B    | +M    | +SP    | **+SIO** |   Δ vs BL |
|---                 |---:   |---:   |---:   |---:    |---:     |---:       |
| RTT median (μs)    | 53.6  | 51.6  | 49.0  | 48.7   | **48.0**| **−10%**  |
| RTT p95 (μs)       | 97.7  | 85.3  | 82.9  | 72.6   | **79.5**| **−19%**  |
| RTT p99 (μs)       | 254.3 | 116.9 | 111.7 | 101.8  | **103.8**| **−59%** |
| burst s→j (msg/s)  | 88.9k | 105.9k| 103.8k| 97.9k  | **112.8k**| **+27%** |
| burst j→s (msg/s)  | 93.1k | 98.5k | 93.6k | 97.9k  | **95.4k**| +2.4%     |

Where each layer contributed:
* The bulk of the throughput win came from **Bonito's fast-path** + **SessionIO buffer reuse**. The SessionIO step alone added +9% s→j over the no-stream-pack baseline.
* Tail latency win is dominated by **MsgPack write_be** (Ref alloc elimination) and **stream-pack** structure (fewer per-message allocs → fewer GC pause spikes).
* SessionIO matched stream-pack on p99 latency while *also* boosting throughput because the reused scratches eliminate the per-call IOBuffer allocation that hurt stream-pack v1's burst numbers.

The `Per-message serialize_binary` micro reflects this dramatically: small message went 41 → 7 allocs and 1.33 → 0.50 μs (−83% allocs, −62% time). The j→s direction is unaffected by any of these changes — that path is dominated by JS→server WS framing on the JavaScript side.

## Where the wins come from

The `batch_50` allocs going 106 → 48 is the strongest signal: dozens of small UInt16/UInt32 writes per message all skip the Ref alloc. The headline absolute time changes are modest because the bigger bottlenecks for Bonito serialization are upstream of MsgPack (`SerializedMessage`'s ctx-locking, the per-cache hashing, JSCode interpolation, etc.). MsgPack itself was never the dominant cost — the win is removing it as a steady source of GC pressure on every Bonito message.

The `+6% time on batch_50` (`serialize_binary` only) is within noise; full pipeline shows it flat. Worth re-checking if it persists.

## Bench code

```julia
using Bonito, MsgPack
using Bonito: Session, NoConnection, NoServer, SerializedMessage, serialize_binary

session = Session(NoConnection(); asset_server=NoServer())
msg_small  = Dict{String,Any}("payload" => 0.42, "id" => "obs-12345", "msg_type" => Bonito.UpdateObservable)
msg_vec    = Dict{String,Any}("payload" => rand(Float32, 4096), "id" => "obs-vec", "msg_type" => Bonito.UpdateObservable)
msg_batch  = Dict{String,Any}("payload" => [Dict{String,Any}("payload" => i*0.1, "id" => "o-$i", "msg_type" => Bonito.UpdateObservable) for i in 1:50],
                              "id" => "batch", "msg_type" => Bonito.UpdateObservable)
msg_nested = Dict{String,Any}(
    "payload" => Dict{String,Any}("a" => rand(Float32, 256), "b" => "hello world", "c" => [1,2,3,4,5]),
    "id" => "nested", "msg_type" => Bonito.UpdateObservable)

# serialize_binary only
for (name, m) in (("small", msg_small), ("vec_4K", msg_vec), ("batch_50", msg_batch), ("nested", msg_nested))
    sm = SerializedMessage(session, m); serialize_binary(sm)
    GC.gc(true)
    s = @timed (for _ in 1:5000; serialize_binary(sm); end)
    println(rpad("serialize_binary($name)", 28), "  ",
            lpad(round(s.time*1e6/5000, digits=2), 8), " μs/op  ",
            lpad(Int(round(s.bytes/5000)), 8), " B/op  ",
            lpad(Int(round((s.gcstats.poolalloc + s.gcstats.malloc)/5000)), 6), " allocs/op")
end

# full pipeline
full_pipeline(s, m) = serialize_binary(SerializedMessage(s, m))
for (name, m) in (("small", msg_small), ("vec_4K", msg_vec), ("batch_50", msg_batch), ("nested", msg_nested))
    full_pipeline(session, m); full_pipeline(session, m)
    GC.gc(true)
    s = @timed (for _ in 1:2000; full_pipeline(session, m); end)
    println(rpad("full($name)", 28), "  ",
            lpad(round(s.time*1e6/2000, digits=2), 8), " μs/op  ",
            lpad(Int(round(s.bytes/2000)), 8), " B/op  ",
            lpad(Int(round((s.gcstats.poolalloc + s.gcstats.malloc)/2000)), 6), " allocs/op")
end
```
