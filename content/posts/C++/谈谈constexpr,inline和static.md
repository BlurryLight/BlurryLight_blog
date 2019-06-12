
---
title: "谈谈constexpr,inline和static"
date: 2019-06-08T16:16:18+08:00
draft: false
tags: [ "cpp" ]
categories: [ "cpp"]
# keywords: [ ""]
lastmod: 2019-06-08T16:16:18+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "谈谈constexpr,inline和static"
---

`constexpr`，`inline`和`static`可能是C++里最让人迷惑的几个关键词了，如同`vector<bool>`既不是一个`vector`，里面也不存放`bool`一样。
当出现组合`static constexpr`,`static inline`等这种组合的时候，更是让人摸不着头脑。

### constexpr和const的区别

简单来说，`const`的含义是`readonly variable`，`constexpr`代表的是真的`constant`，用法如同纯C里的`#define A 100`一样。
如果你想要真正的**常量**,那就请使用`constexpr`。
考虑如下代码

```cpp
#code 1
    volatile constexpr int a = 5;
    int *p = (int *)&a;
    *p = 100;
    printf("a = %d, *p = %d\n", a, *p);

#code 2

    volatile const int a = 5;
    int *p = (int *)&a;
    *p = 100;
    printf("a = %d, *p = %d\n", a, *p);
```

`gcc-8`编译,结果会是

```cpp
a = 5, p = 100
a = 100 p = 100
```

`constexpr`也可以用来修饰函数，表示函数会在编译器被计算，然而`constexpr`并不一定保证函数会在编译期被计算。这个设计是为了
避免仅仅因为编译期计算和运行期计算的细微差别的函数重载。但是这个特性可能会对导致一点编译错误，幸运的是这点错误会在编译期就被编译器拒绝接受
如下
考虑以下代码

```cpp
#include <array>

constexpr int foo(int i)
{
    return i + 1;
}
int main()
{
    int i = 5;
    std::array<int,6> bar1;
    std::array<int,foo(5)> bar2;
    // std::array<int,foo(i)> bar3; // error
#define N 6
    std::array<int,N> bar4;
    return 0;
}
```

`foo(i)`传入了一个非`const`变量，所以它的`constexpr`标识符失效，从而导致`std::array<>`不能编译。

### static
`static`的毛病在于，它可以用用的范围太广以至于它在修饰不同的东西的时候，带有不同的含义。
它主要有几个用处

1. 当`static`用于面向对象中，即类里面修饰变量和成员函数时，它代表所有对象都共用同一个成员函数和静态数据成员。从这个含义上来讲`static`和`inline`有相似之处。
在`C++11`里加入的`constexpr`加强了`static`对静态数据成员的功能，现在可以在类内直接初始化`constexpr static`成员了。

2. 当`static`被用于全局变量的时候，又分为两种情况。如果是在`cpp`文件内声明一个`static`全局变量，那么该变量只在该cpp文件内可见，其他cpp无法访问该变量。
当在头文件里定义`static`全局变量时，每一个包含了该头文件的`cpp`都会维持一份该全局变量的**拷贝**，这里和`inline`完全相反。如果你在头文件里实现了某个函数，
并标注为`static`，那么每一个包含该头文件的`cpp`都会复制一份该函数。

3. 当`static`用于函数内部的局部变量时，表示延长该局部变量的生命周期，延长到程序结束为止，但是访问域限制在函数以内，只有函数内部可以修改该变量。

### inline
`inline`的问题在于，它的含义在`c++`的发展历程中，发生了转变。早期的`inline`表示建议编译器在这里进行优化，现在编译器基本都会忽略`inline`，自己选择优化。
现在`inline`的意思已经变成了：在头文件中修饰的变量和函数(包含实现)的时候，每一个引用头文件的`cpp`文件所持有的该函数/变量，都是同一个函数/变量。

`inline`现在最大的用处在，如果想要非模板函数在头文件内**实现和定义不分离**，则必须加上`inline`，这样在多个引用该函数的`cpp`文件内，持有的函数都是同一个函数。


`static inline` 这种把人往死里坑的声明，实际上就等于`static`，`inline`会被忽略掉。

下面上一段简单的测试代码

```cpp
// static.h
#pragma once
inline int i = 5; //result 1
//static int i = 5; //result 2
//static inline i = 5; //result 3 和static相同

// static_test1.h
#pragma once
#include "static.h"

void print_i();

// static_test2.h
#pragma once
#include "static.h"

void print2_i();

// static_test1.cpp

#include <iostream>
#include "static_test1.h"

void print_i()
{
    std::cout<< &i <<"i="<<i<<std::endl;
}

// static_test2.cpp

#include <iostream>
#include "static_test2.h"

void print2_i()
{
    std::cout<< &i <<"i="<<i<<std::endl;
}

// main.cpp

#include <iostream>
#include "static_test1.h"
#include "static_test2.h"

int main()
{
    print_i();
    print2_i();
}

```

用`std=gnu++17`编译如下(`inline variable`是`cpp17`的规范)

```cpp
//result
0x55f7d853a070i=5
0x55f7d853a070i=5


//result 2
0x563bd8c61070i=5
0x563bd8c61074i=5

//result 3
0x56270bb4f070i=5
0x56270bb4f074i=5

```












