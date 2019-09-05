using MsgPack2
using Documenter

makedocs(modules=[MsgPack2],
         sitename="MsgPack2",
         authors="Jarrett Revels and other contributors",
         pages=["API Documentation" => "index.md"])

deploydocs(repo="github.com/beacon-biosignals/MsgPack2.jl.git")
