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
# safedecode(x::String)=decode(Val(:safe),x)
function decode_delete(x::String)
    isncm(x) || return -1
    # res=
    decode(x)
        # if !(res isa Bool && res)
            posthandle(x)
        # end
end 
using NeteaseCloudMusicDump
for i in ARGS
    # println(i)
    if isdirpath(i)
        files=readdir(i, join=true)
        Threads.@threads :dynamic for z in files
            println(z)
            decode_delete(z)
        end
    elseif isfile(i)
        decode_delete(i)
    end
end