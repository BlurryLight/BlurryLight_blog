
---
title: "关于C++的命名约定"
date: 2019-07-30T18:59:25+08:00
draft: false
# tags: [ "" ]
categories: [ "C++"]
# keywords: [ ""]
lastmod: 2019-07-30T18:59:25+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "关于C++的命名约定"
---

# 谷歌命名约定

本篇文章几乎照搬于谷歌命名约定，部分根据个人习惯有所改动，可供参考。

## 文件名
文件名全部小写,采用`_`连接单词。如`my_useful_tools.cc`是一个可以接受的命名。头文件一律采用`h`结尾，包含有内联函数，或者模板实现的头文件可以采用`hpp`结尾，实现文件一律采用`cc`后缀。

## 类型命名

类，结构体，类型别名(`typedef`),枚举(`enum`)采用驼峰命名法。如`MyExcitingClass`，不允许下划线。

## 变量命名

所有变量，包括函数参数，全部采用小写字母+下划线。
类的成员变量使用下划线`_`结尾。如

```cpp
class MyExcitingClass
{
    public:
    ....
    private:
    std::mutex lock_;
    std::string char_buffer_;  //good.  Don't use charbuffer_ or CharBuffer_
}
```

谷歌建议结构体变量像正常变量一样命名，但是我认为应该同类等同，因为大量的C++代码不加区分的使用类与结构体。

## 常量

用`static const`，`#define`,`const`和`constexpr`以及确定有常量语义的变量，命名时都以小写字母`k`开头，并采用驼峰命名法。
如`constexpr int kBufferSize = 1024`。

## 函数命名

谷歌推荐采用`AddTableEntry()`的驼峰命名法，但是考虑到`STL`大量函数（如`std::to_string`,`std::vector::push_back`等）采用`_`连接法，还是推荐使用小写字母+`_`命名。

## 命名空间

命名空间主要用小写字母来命名，避免无意义的命名空间，如`namespace foo{}`。
命名空间的标志可以设置的更加清楚，以避免出现以下情况

```cpp
namespace logging
{
    ....   // tons of code
            }
        }
    }   //嵌套括号
}
```

大量的嵌套括号，即使在有IDE或者带有括号匹配的编辑器的辅助下，仍然可能出现括号数目不匹配的情况。
可以建立明确的标志，代表命名空间结束

```cpp
namespace logging
{
    ....   // tons of code
            }
        }
    }   //嵌套括号
} //namespace logging
```

也可以定义一个命名空间宏

```cpp

#if !defined(NAMESPACE_BEGIN)
#define NAMESPACE_BEGIN(name) namespace name {
#endif
#if !defined(NAMESPACE_END)
#define NAMESPACE_END(name) }
#endif

#NAMESPACE_BEGIN(logging)
{
    //tons of code
}
#NAMESPACE_END(logging)

```

## 枚举命名

`enum`类型往往带有常量的性质。因此谷歌推荐使用常量命名法来命名。如

```cpp
enum class LogLevel
{
    kTrace = 0,
    kInfo = 1,
    ...
}
```

## 宏命名

宏命名建议采用全大写字母与下划线的方法，这也是C中常用的标志宏的方法。

```c
#define MY_EXCITING_MACRO(x) ...
```