module NeteaseCloudMusicDump
using Base64:base64decode
import JSON3
using AES
using ID3v2
using ID3v2:TextFrame,APIC

export NeteaseCloudMusic,
decode
const core_key = hex2bytes("687A4852416D736F356B496E62617857")
const meta_key = hex2bytes("2331346C6A6B5F215C5D2630553C2728")
const MAGIC_HEADER=hex2bytes("4354454e4644414d")
const core_cryptor = AESCipher(;key_length=128, mode=AES.ECB, key=AES128Key(core_key))
const meta_cryptor = AESCipher(;key_length=128, mode=AES.ECB, key=AES128Key(meta_key))

unpack(data::Vector{UInt8})=parse(Int,bytes2hex(reverse(data)),base=16)

function _NeteaseCloudMusic(io::IO)
    skip(io,2)
    key_data = read(io,unpack(read(io,4)))
    key_data.⊻= 0x64
    ct=AES.CipherText(key_data,nothing,128,AES.ECB)
    key_data =decrypt(ct, core_cryptor)[18:end]
    key_box=decode_keybox(key_data)
    meta_length = unpack(read(io,4))
    meta_data = read(io,meta_length)
    meta_data.⊻= 0x63
    meta_data = base64decode(meta_data[22:end])
    ct=AES.CipherText(meta_data,nothing,128,AES.ECB)
    meta_data= String(decrypt(ct, meta_cryptor)[7:end])
    meta_data = JSON3.read(meta_data)
    crc32 = read(io,4)
    # crc32 = unpack(crc32)
    skip(io,5)
    image_data = read(io,unpack(read(io,4)))
    # file_upper_path,_=splitext(file_path)
    key_box,meta_data,image_data
end
struct NeteaseCloudMusic
    filenamepath::String
    key_box::Vector{UInt8}
    meta::JSON3.Object{Base.CodeUnits{UInt8, String}, Vector{UInt64}}
    image::Vector{UInt8}
    io::IO
    function NeteaseCloudMusic(file_path::AbstractString)
        f = open(file_path)
        @assert read(f,8) == MAGIC_HEADER error("not is a ncm file")
        file_upper_path,_=splitext(file_path)
        new(file_upper_path,_NeteaseCloudMusic(f)...,f)
    end
    function NeteaseCloudMusic(::Val{:safe},file_path::AbstractString)
        f = open(file_path)
        if read(f,8) != MAGIC_HEADER 
            return new(),true
        end
        file_upper_path,_=splitext(file_path)
        new(file_upper_path,_NeteaseCloudMusic(f)...,f),false
    end
end
function decode_keybox(key_data::Vector{UInt8})
    key_box = UInt8.(0:255)
    key_length=length(key_data)
    c = 0
    last_byte = 0
    key_offset = 1
    for i in 1:256
        swap = key_box[i]
        c = (swap + last_byte + key_data[key_offset]) & 0xff
        key_offset += 1
        if key_offset > key_length
            key_offset = 1
        end
        key_box[i] = key_box[c+1]
        key_box[c+1] = swap
        last_byte = c
    end
    key_box
end

function ID3v2.ID3(x::NeteaseCloudMusic)
    header=ID3Header(v"2.3.0",0x0,0)
    tags=(TIT2=TextFrame(ID3v2.UTF8,x.meta.musicName),
    APIC=APIC(ID3v2.LATIN1,"image/jpg",ID3v2.COVER_FRONT,"",x.image),
    TALB=TextFrame(ID3v2.UTF8,x.meta.album),
    TPE2=TextFrame(ID3v2.UTF8,x.meta.artist[1][1]))
    ID3(header,tags)
end
# function Base.write(io::IO,x::NeteaseCloudMusic)
#     header,tags=ID3(x)
#     write(io,header(x))
#     write(io,zeros(UInt8,4))
#     writeID3Tags(io,tags)
#     _size=position(io)-10
#     seek(io,6)
#     write(io,BitPaddedInt2bytes(_size))
#     seekend(io)
# end
function Base.read(x::NeteaseCloudMusic,_lenght::Int)
    chunk = read(x.io,_lenght)
    key_box=x.key_box
    for i in eachindex(chunk)
        j = i & 0xff
        index=(key_box[j+1] + key_box[((key_box[j+1] + j) & 0xff) + 1]) & 0xff
        chunk[i] ⊻= key_box[index+1]
    end
    chunk
end
Base.read(x::NeteaseCloudMusic,_lenght::Int,::Val{:normal})=read(x,_lenght)
function Base.read(x::NeteaseCloudMusic,_lenght::Int,::Val{:threads})
    chunk = read(x.io,_lenght)
    key_box=x.key_box
    Threads.@threads :dynamic for i in eachindex(chunk)
        j = i & 0xff
        index=(key_box[j+1] + key_box[((key_box[j+1] + j) & 0xff) + 1]) & 0xff
        chunk[i] ⊻= key_box[index+1]
    end
    chunk
end
function decode(x::NeteaseCloudMusic,out::IO=IOBuffer(),buffer::Int=typemax(Int);use_threads::Bool=true)
    if eof(x.io) error("Already decode") end
    write(out,ID3(x))
    flag=if use_threads Val(:threads) else Val(:normal) end
    while !eof(x.io)
        audio=read(x,buffer,flag)
        write(out,audio)
    end
    close(x.io)
    out
end
function decode(x::String,outname::Union{Nothing,String}=nothing)
    music=NeteaseCloudMusic(x)
    outname=isnothing(outname) ? music.filenamepath : outname
    file_name = joinpath(outname* '.' * music.meta["format"])
    io = open(file_name, "w")
    decode(music,io)
    close(io)
end
function decode(::Val{:safe},x::String,outname::Union{Nothing,String}=nothing)
    music,nil=NeteaseCloudMusic(Val(:safe),x)
    if nil return true end
    outname=isnothing(outname) ? music.filenamepath : outname
    file_name = joinpath(outname* '.' * music.meta["format"])
    io = open(file_name, "w")
    decode(music,io)
    close(io)
end
end # module NeteaseMusicDump