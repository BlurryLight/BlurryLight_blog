
---
title: "C++跨平台新体验: Vcpkg Manifest与Github Actions"
date: 2021-05-05T16:36:54+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp"]
# keywords: [ ""]
lastmod: 2021-05-05T16:36:54+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "4756a873"
toc: true
# latex support
# katex: true
# markup: mmark
---

C++的跨平台体验一直比较糟糕，尤其是涉及到需要链接大量的第三方库的时候，整个项目的依赖管理变得相当复杂。

究其根本，问题的源头是C++一直未在ABI的问题上统一，导致在不同系统，不同编译器，不同编译器版本，以及不同的编译设置上编译出来的东西，彼此ABI不兼容以至于不能链接或者链接后运行报错，这消耗了大量的C++开发者的时间。即使是富有经验的CPP老手，在处理编译、链接的问题上也得小心翼翼。

由此C++的第三方库的管理也就成了悬而未决的疑难问题，自C++发明40年来，这些书本上不会告诉你的知识会让一代又一代的初学者不断的趟坑。

常见的C++第三方库的管理包含如下方式：
- `git submodules`
- `CMake ExternalProject`
- 开发者自行写`prebuild.sh/cmd/py`
- 将子模块的源码放在`third_party`文件夹下
- 利用系统的包管理器(`apt/pacman/dnf`)

以上方案均不能让人满意，1-4方法需要开发者对每一个子模块的编译过程都要掌握，这个过程是你现在想要引入A你得先要学会编译A（需要对A库的所有options，flags都弄清楚），然后A又依赖B，C，D于是目标转变为编译成B，C，D，这个过程需要进一步循环下去（如果你还不明白这个过程的痛苦，那么试着建立一个依赖chromium的工程试试吧）。
方法5是稍微现代一点的方法，只需要执行一条命令`pacman -S boost`就可以在项目里愉快的使用`boost`了，至于`boost`怎么编译的根本不用开发者去操心。这个方案的缺点是:
1. Windows上没有此类基建设施
2. apt/pacman/dnf此类设施在Linux上需要root权限
3. 难以解决A工程依赖`boost1.5`，B工程依赖`boost1.7`的这类问题。
4. 即使在Linux上不同发行版的包管理器也不统一，最后仍然会退化成`install-deps.sh`这类形式。


# vcpkg manifest

vcpkg是微软推出的一款跨平台包管理器，有关它的classic模式的博客相当多，官方文档也比较好，简单得说，它把引入第三方包的问题简化成了两步。
```
#1. 安装包 
vcpkg install eigen3:x64-windows
#2. 在CMakeLists.txt中引入包
find_package(eigen3)
target_link_libraries(${project_name} PRIVATE eigen3)
```
有关vcpkg的使用，主要包括`${VCPKG_ROOT}`环境变量，`triplet`的概念以及`CMake toolchain file`的概念，这部分[官网文档](https://github.com/microsoft/vcpkg/blob/master/README_zh_CN.md)介绍的很详细。

以上介绍的叫做`classic`模式，也即经典模式，包括安装包和在`CMakeLists.txt`引入这两部分。
这个模式下，vcpkg安装的库是全局的，任何引用`vcpkg`提供的`toolchain file`的工程都能看到安装的包。

随后，vcpkg提供了一种叫做`manifest`的模式。该模式下，每一个工程应该提供一个`vcpkg.json`文件，用于描述该工程依赖哪些库。
对于`vcpkg`而言，在manifest模式下，它所安装的库位于project的目录之下，不会污染其他工程的依赖。

一个典型的manifest模式:
```json
## vcpkg.json
{
  "name": "my-application",
  "version": "0.0.1",
  "dependencies": [
    "boost-system",
    {
        "name": "fmt",
    "version>=": "7.1.3"
    }
  ],
  "builtin-baseline": "b60f003ccf5fe8613d029f49f835c8929a66eb61"
}
```

该manifest文件描述了，vcpkg应该在`vcpkg`的`b60f003ccf5fe8613d029f49f835c8929a66eb61`hash的commit记录里，寻找`fmt`和`boost-system`的编译脚本。
其中`fmt`的版本需要大于等于`7.1.3`。

在检测到项目的根目录下有`vcpkg.json`后，vcpkg会自动切换到`manifest`模式。
在`classic`模式下，vcpkg所安装的包位于`${VCPKG_ROOT}/installed`目录，而在`manifest`模式下，vcpkg安装的包，**据观察**，位于`${build-dir}/vcpkg_installed`的目录下,也就是编译目录下。


# Github Actions

在github上我们经常用github actions来执行自动编译流程，在引入vcpkg以后，我们有了统一的方式用于在Windows/Linux/MacOS上安装依赖库。
但是vcpkg是源码级的包管理器，意味着每次在新的action环境下安装依赖包都需要编译，倘若依赖Qt5这种重型库，编译1-2小时是常有的。
我们可以引入github的缓存机制。 该机制可以保存已经被安装的包,供下次action执行使用。
注意，在manifest模式下，单纯的只保存vcpkg的目录是不够的，因为manifest模式安装的包位于工程目录下，我们还需要保存`build/vcpkg_installed`目录。
vcpkg的`buildtrees`,`packages`和`downloads`都是缓存目录，在空间不够的时候可以删除，在github action中我们为了节约缓存空间也可以把这些文件夹剔除掉。
```yaml
- name: Restore vcpkg and its artifacts.
  uses: actions/cache@v2
  id: vcpkg-cache
  with:
    path: |
      ${{ env.VCPKG_ROOT }}
      ${{ github.workspace }}/build/vcpkg_installed
      !${{ env.VCPKG_ROOT }}/.git
      !${{ env.VCPKG_ROOT }}/buildtrees
      !${{ env.VCPKG_ROOT }}/packages
      !${{ env.VCPKG_ROOT }}/downloads
    key: |
      ${{ hashFiles( 'vcpkg.json' ) }}-${{ runner.os }}-cache-key-v1
```

一个简单的example可以见[build.yaml](https://github.com/BlurryLight/DiRenderLab/blob/main/.github/workflows/build.yml)。

# 附录
- CMake + vcpkg 调用MSVC Amd64编译
```bash
cmake -A x64 .. "-DCMAKE_TOOLCHAIN_FILE=D:\vcpkg\scripts\buildsystems\vcpkg.cmake" #生成msbuild工程
cmake --build . --config Release  # 并行编译Release版本
```

- CMake + vcpkg 调用Clang-cl编译。
注意，clang-cl前端默认关闭异常，需要在CMakeLists.txt里做额外的判断，检测到clang-cl以后打开异常。
```cmake
if ((${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" AND "x${CMAKE_CXX_SIMULATE_ID}" STREQUAL "xMSVC"))
    # clang-cl
    message("clang-cl detected!")
    add_compile_options(/EHa /EHs) # 打开异常
endif ()
```
```bash
cmake -DCMAKE_TOOLCHAIN_FILE=D:\vcpkg\scripts\buildsystems\vcpkg.cmake -T clangcl -G"Visual Studio 16 2019" -A x64 .. #生成msbuild工程
cmake --build . --config Release  # 并行编译Release版本
```

- CMake + vcpkg 在Linux上调用gcc编译
```bash
export CC=gcc
export CXX=g++
cmake .. -DCMAKE_TOOLCHAIN_FILE=${VCPKG_ROOT}/vcpkg/scripts/buildsystems/vcpkg.cmake -DCMAKE_BUILD_TYPE=Release
cmake --build . --parallel
```