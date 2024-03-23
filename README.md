## Overview
解密网易云加密的音乐(ncm)
## Installation

```julia-repl
(@v1.10) pkg> add https://github.com/xing8star/ID3v2.jl
(@v1.10) pkg> add https://github.com/xing8star/FLACMetadatas.jl
(@v1.10) pkg> add https://github.com/xing8star/NeteaseCloudMusicDump.jl
```

## Example
```julia
using NeteaseCloudMusicDump
decode("yourkugoumusic.ncm")
```

## Script
Firstly need to instantiate the 'script' project
```bash
julia --project=script script/dump.jl --keep "yourmusic.ncm" directory
```