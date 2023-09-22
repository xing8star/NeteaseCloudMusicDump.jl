# using Pkg
# Pkg.activate(".")
using ArgumentProcessor
group = Group(
    "group1",
    flags=[
        Flag("iskeep";outername="keep",abbr="k")
    ])
const input1 = ArgumentProcessor.parse(ARGS, group)
posthandle(x)=if !input1.iskeep
    rm(x)
end
safedecode(x::String)=decode(Val(:safe),x)
using NeteaseCloudMusicDump
for i in ARGS
    # println(i)
    if isdirpath(i)
        files=readdir(i, join=true)
        Threads.@threads :dynamic for z in files
            println(z)
            res=safedecode(z)
            if res isa Bool && res
                continue
            end
            posthandle(i)
        end
    elseif isfile(i)
        res=safedecode(i)
            if res isa Bool && res
                continue
            end
        posthandle(i)
    end
end