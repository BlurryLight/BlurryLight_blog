
---
title: "CMake Snippets"
date: 2023-07-28T05:05:12Z
draft: false
categories: [ "CMake"]
isCJKLanguage: true
slug: "ae3cb50c"
toc: true
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


{{% spoiler "笔记栏文章声明"%}} 
    {{% notice warning %}}
    笔记栏所记录文章往往未经校对，或包含错误认识或偏颇观点，亦或采用只有自身能够理解的记录。
    {{% /notice %}}
{{% /spoiler %}}

# 跨平台创建类似于Symlink

take from [cmake - replacement of create_symlink in windows - Stack Overflow](https://stackoverflow.com/questions/61243174/replacement-of-create-symlink-in-windows)

在Windows上有一个替代品 `Directory Junction`。
对于单机用户基本上没区别。
区别在于
- 对于一个`Remote Directory`里的路径，symlink会解析到本地，junction会在server解析
- symlink可以指向文件，junction只能指向目录

see: https://superuser.com/a/343079


```cmake
if(NOT EXISTS ${CMAKE_BINARY_DIR}/bin/media)
    if (UNIX)
        execute_process(COMMAND "${CMAKE_COMMAND}" -E create_symlink ${CMAKE_SOURCE_DIR}/media ${CMAKE_BINARY_DIR}/bin/media)
    else()
        # also there is symlink/hardlink on windows, it requires admin permission
        file(TO_NATIVE_PATH "${CMAKE_BINARY_DIR}/bin/media" _dstDir)
        file(TO_NATIVE_PATH "${CMAKE_SOURCE_DIR}/media" _srcDir)
        execute_process(COMMAND cmd.exe /c mklink /J "${_dstDir}" "${_srcDir}")
    endif()
endif()
```