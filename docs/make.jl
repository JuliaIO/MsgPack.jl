using MsgPack
using Documenter

makedocs(modules=[MsgPack],
         sitename="MsgPack",
         authors="Jarrett Revels and other contributors",
         pages=["API Documentation" => "index.md"])

deploydocs(repo="github.com/JuliaIO/MsgPack.jl.git")
