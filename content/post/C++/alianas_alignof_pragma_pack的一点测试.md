
---
title: "alianas/alignof/#pragma pack的一点测试"
date: 2023-05-22T00:08:05+08:00
draft: false
categories: [ "cpp"]
isCJKLanguage: true
slug: "9da9c22d"
toc: false
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


# pragma pack

在x64下其对齐标准为
```c
struct Test
{
    char a; // offset 0
    int b; // offset 4
    char c; // offset 8
    double d;  // offset 16
};
sizeof(Test) == 24;
```
![edit-ae5c309b2f644d179e4b2271cbda0860-2023-05-18-11-39-25](https://img.blurredcode.com/img/edit-ae5c309b2f644d179e4b2271cbda0860-2023-05-18-11-39-25.png?x-oss-process=style/compress)


`#pragma pack` 主要控制类内元素间的对齐。
这是个非标语法，但是主流的编译器都支持。

```c
#pragma pack(push,1)
struct Test
{
    char a; // offset 0
    int b; // offset 1
    char c; // offset 5
    double d;  // offset 6
};
#pragma pack(pop)
static_assert(sizeof(Test) == 14);
static_assert(offsetof(Test,a) == 0);
static_assert(offsetof(Test,b) == 1);
static_assert(offsetof(Test,c) == 5);
static_assert(offsetof(Test,d) == 6);
```

# alianas / alignof

C++对于所有的结构体、基本类型有自己的对齐规则，可以通过`alinas`指定新的对齐规则。
在没有`alignas`之前，需要编译器扩展来手动指定。

msvc 通过`__declspec(align(#))`, gcc通过 `__attribute__ ((aligned(x)))`

```c
#if defined(_MSC_VER)
#define ALIGNED_(x) __declspec(align(x))
#else
#if defined(__GNUC__)
#define ALIGNED_(x) __attribute__ ((aligned(x)))
#endif
#endif
```

所以 `#pragma pack`相当于对每个类内的成员应用了一条`__declspec(align(#))`规则。

另外，指定了`alignas`的结构体，也会影响sizeof的结果(大概是编译器会插入padding吧)

```c
struct alignas(32) Test
{
    char a;
};

static_assert(sizeof(Test) == 32)
```

## alianas 和pragma pack联用

这两个标识符连用在不同的编译器有不同的表现。

MSVC会遵循`alianas`, 而gcc的`#pragma pack`会覆盖`alianas`的规则。测试代码见
https://godbolt.org/z/osod9YbPK

这个代码在MSVC能编译过，而在gcc/clang不行


```c
#pragma pack(push, 1)
struct S0 {
   char a;
   short b;
   double c;
   alignas(32) double d;
   char e;
   double f;
};
#pragma pack(pop)

static_assert(offsetof(S0,d) == 32); // gcc/clang fails because they ignore alignas(32)
static_assert(sizeof(S0) == 64);
static_assert(alignof(S0) == 32);
```