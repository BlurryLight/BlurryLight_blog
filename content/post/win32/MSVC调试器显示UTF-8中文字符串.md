
---
title: "MSVC调试器显示UTF 8中文字符串"
date: 2022-04-12T22:16:17+08:00
draft: false
# tags: [ "" ]
categories: ["win32"]
# keywords: [ ""]
# lastmod: 2022-04-12T22:16:17+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "8a85b633"
toc: false
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


C++20以前没有`std::u8string`，虽然msvc有一个扩展(`/Zc:char8_t-`)可以用，但是最好别碰(https://docs.microsoft.com/en-us/cpp/build/reference/zc-char8-t?view=msvc-170)。
那个扩展允许写出这种代码，第一条是扩展的内容，这个扩展和c++二十加进来的`u8`符号是不兼容的，会导致升级编译器的时候出现break change。
```cpp
const char* str = u8"hello中国"; // error in cpp20
const char8_t* str = u8"hello中国"; //valid in cpp20
```

目前最好的方案还是通过`/utf-8`标志指定MSVC编译器把代码里的字符串都当做`utf-8`处理，并且代码都保存在`utf-8`格式。

但是`std::string`并不包含encoding信息，所以MSVC的debugger不知道`std::string`里的编码文字，其会把里面的文字尝试用`locale`所在的编码解释，中文的话会是GBK编码。

![edit-260f74663c9242eca6771776420b4205-2022-04-12-22-09-55](https://img.blurredcode.com/img/edit-260f74663c9242eca6771776420b4205-2022-04-12-22-09-55.png?x-oss-process=style/compress)

如果想要在调试器里看到`UTF-8`编码的中文的中文字符串，可以在`Variables`面板右键点击字符串添加到`watch`面板，并且在`watch`面板的变量后面加上`s8`标志，指示这是一个`u8string`。UTF16字符串可以用`su`标志，不过应该用的比较少，在Windows平台用宽字符串`std::wstring`存储`utf-16`的字符串的话调试器应该能正确识别。

所有调试器可以用的格式化标志可以见(https://docs.microsoft.com/en-us/visualstudio/debugger/format-specifiers-in-cpp?view=vs-2022)，包含很多高级的格式化标记。

以上操作在Windows平台上可以对`Visual Studio`和`Visual Studio Code`起效。
