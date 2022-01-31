
---
title: "Windows上CMake+Lua编译和luarocks环境配置"
date: 2022-01-31T14:30:13+08:00
draft: false
# tags: [ "" ]
categories: [ "Lua"]
# keywords: [ ""]
# lastmod: 2022-01-31T14:30:13+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "5455335f"
toc: True
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

# Windows10

珍爱生命，远离预编译的包。编译`Lua`环境相对容易，只需要一个支持`ANSI C`的编译器环境，所以推荐自己编译，否则可能由于预编译的包的工具链和本机上的工具链版本不一样导致奇奇怪怪的问题。
- 预编译的包可能会出现`Luarocks`不识别`Lua5x.dll`的情况
- `luarocks`的许多包安装时需要`C`工具链参与，并且要和`Lua5x.dll`链接。


## Lua + CMake编译
Lua原生只提供`makefile`，而且是Linux下的`makefile`,有人提供了MSVC工具链可以调用的[NMAKE工程文件](https://github.com/vtudorache/lua-msvc),没有尝试，可以试试。

因为我想要自动化下载源代码，编译和打包这个流程，所以干脆就用`cmake`搞了一下。
Lua的源代码里不考虑MSVC的私货`dllexport`那一坨，所以在Win下编译要格外注意符号导出，或者就别搞动态链接库，直接打包成静态库(有个坑就是`luac`必须静态链接`lualib`，用动态链接找不到符号)。

自己fork了一份代码改了下cmake,工程在[`https://github.com/BlurryLight/Lua-with-cmake`](https://github.com/BlurryLight/Lua-with-cmake)，支持从环境变量`LUA_VERSION`导入想要的版本号,pwsh中可以使用`$env:LUA_VERSION = "5.3.5"`, `bash`直接用`export`就完事。
`install`部分参照着`5.3.6`的源码结构编写的，编译低版本(`5.1.x`)的话,由于部分头文件位置不一样所以install的时候可能会出错，需要手动复制一下`lua.hpp`这个头文件。

```
git clone git@github.com:BlurryLight/Lua-with-cmake.git
```

lua53编译出来的组织结构应该是

```
.
├── [4.0K]  bin
│   ├── [205K]  lua53.dll
│   ├── [ 18K]  lua53.exe
│   ├── [117K]  luac.exe
│   └── [205K]  luad.dll
├── [4.0K]  include
│   ├── [8.4K]  lauxlib.h
│   ├── [ 21K]  luaconf.h
│   ├── [ 14K]  lua.h
│   ├── [ 191]  lua.hpp
│   └── [1.3K]  lualib.h
├── [4.0K]  lib
│   ├── [ 57K]  lua53.lib
│   ├── [ 57K]  luad.lib
│   └── [922K]  luas.lib


3 directories, 12 files

```

lua51编译出来的结构应该是
```
.
├── [4.0K]  bin
│   ├── [168K]  lua51.dll
│   ├── [160K]  lua51.exe
│   └── [ 96K]  luac.exe
├── [4.0K]  include
│   ├── [5.6K]  lauxlib.h
│   ├── [ 22K]  luaconf.h
│   ├── [ 11K]  lua.h
│   ├── [ 191]  lua.hpp
│   └── [1.0K]  lualib.h
├── [4.0K]  lib
│   ├── [ 48K]  lua51.lib
│   └── [723K]  lua51s.lib

3 directories, 10 files

```

注意`lua53.exe`,`lua51.dll`等库和exe都要带版本号，如果格式不对的话需要手动重命名一下，以方便`luarocks`识别。

## Luarocks安装

Luarocks官方提供的那个二进制浪费了我2小时，不如自己编译5分钟搞定。去这里下载源码包`https://github.com/luarocks/luarocks/releases/tag/`，下下来后解压，编译。

windows下的编译命令为

```bat
install.bat /F /LUA LUA_INSTALL_PATH /P LUAROCKS_INSTALL_DIR /SELFCONTAINED /Q
```


第一个参数`LUA_INSTALL_PATH`要指向lua编译出来的路径，第二个路径`LUAROCKS_INSTALL_DIR`指向`luarocks`将要安装的路径。
`/SELFCONTAINED`比较重要，把各种目录收拢在安装目录，方便安装多个版本的`luarocks`。

5.1版本的安装
`install.bat /F /LUA D:\opt\lua-5.1.5-build-Release /P D:\opt\Luarocks51 /SELFCONTAINED /Q /LV 5.1`

5.3版本的安装
`install.bat /F /LUA D:\opt\lua-5.3.5-build-Release /P D:\opt\Luarocks53 /SELFCONTAINED /Q /LV 5.3`

## 多版本Lua环境和Luarocks
由于加了`/SELFCONTAINED`的标志后，lua安装的包都在luarocks的目录下。
luarocks提供了一个命令来设置环境变量, 不过也挺sb的，比bash的`eval`要难受多了。

```bat
  luarocks path > "%temp%\_lrp.bat" && call "%temp%\_lrp.bat" && del "%temp%\_lrp.bat
```

通过`install.bat`安装的目录下都包含`luarocks.bat`，这样如果都加到环境变量里会有冲突，可以酌情改成`luarocks51.bat`和`luarocks53.bat`。
### Powershell设置(可选)

具体可以看powershell的配置文件[Microsoft.PowerShell_profile.ps1](https://github.com/BlurryLight/dotfiles/blob/master/Microsoft.PowerShell_profile.ps1)
我从[posh的脚本库](https://github.com/majkinetor/posh/blob/master/MM_Admin/Invoke-Environment.ps1)拿了个脚本，可以从`powershell`里调用`bat`从而设置环境变量。
通过设置`alias`，注意要设置`Scope`以使得alias在函数外生效，以使得`lua`和`luarocks`指向不同版本的lua。
注意不同lua的`bin`目录下也要加入到环境变量下，不然可能会找不到对应的`lua.exe`。

```powershell
function set_lua_51
{
    Set-Alias -name 'lua' -Value 'lua51.exe' -Scope GLobal
    Set-Alias -name 'luarocks' -Value 'luarocks51.bat' -Scope GLobal
    luarocks path > $env:TEMP\_lrp.bat
    Invoke-Environment $env:TEMP\_lrp.bat
}

function set_lua_53
{
    Set-Alias -name 'lua' -Value 'lua53.exe' -Scope GLobal
    Set-Alias -name 'luarocks' -Value 'luarocks53.bat' -Scope GLobal
    luarocks path > $env:TEMP\_lrp.bat
    Invoke-Environment $env:TEMP\_lrp.bat
}
```

`luarocks`安装包的时候可以要注意设置编译器路径，也是利用同样的手法`Invoke-Environment`来调用`visual studio`提供的设置环境变量的`bat`文件。

当然也可以简单一点，用VS提供的![x64toolchains](https://img.blurredcode.com/img/202201310126223.png?x-oss-process=style/compress)
设置好编译器的路径，然后`cd`到不同lua版本的`luarocks`下装包也不是不行，本身装包也是个低频操作，不需要特地在`powershell`里折腾半天。

## 测试

安装完成后可以用`luarocks install luasocket`测试一下，这个库需要编译C库，可以检验环境是否配置对。

```powershell
#.1 激活lua53环境,设置lua53和luarocks53的环境变量
set_lua_53
#.2 安装luasocket
luarocks53.bat install luasocket
#.3 正常情况下应该看见编译和安装成功的提示
# luasocket 3.0rc1-2 is now installed in D:\opt\Luarocks53\systree (license: MIT)
```
调用`require('socket')`检查

![luasocket](https://img.blurredcode.com/img/202201311455165.png?x-oss-process=style/compress)