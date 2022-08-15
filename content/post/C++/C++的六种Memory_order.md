
---
title: "C++的六种Memory_order"
date: 2020-11-21T20:59:04+08:00
draft: true
# tags: [ "" ]
categories: [ "cpp"]
# keywords: [ ""]
lastmod: 2020-11-21T20:59:04+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "C++的六种Memory_order"
toc: false
# latex support
# katex: true
# markup: mmark
---

C++11中引入了六种Memory Order,但是这个不是C++的首创，主要用途是应用于原子操作。
```cpp
enum memory_order{
  memory_order_relaxed, //允许任意重排
  memory_order_consume, //别用
  memory_order_acquire,
  memory_order_release,
  memory_order_acq_rel, 
  memory_order_seq_cst //默认
}
```

一个简单的导致`race condition`的例子
```cpp
int x = 0;
//thread 1
x = 100;
//thread 2
std::cout<<x<<std::endl; //what is x ?
```
这个条件中可能x是0，可能是100。
可能的原因有多个：
- `thread1`落后于`thread2`执行，`thread2`看到的`x=0`.
- `thread1`在`cpu0`上先于`thread2`执行，`thread2`在cpu1上执行，虽然它比thread1慢，但是直接从缓存里取了`x=0`.

# Relax mode
`std::memory_order_relaxed`是最宽松的内存模型，无任何同步要求，只保证对原子变量的修改是原子的，允许编译器任意重排指令。
```cpp
// 线程 1 ：
r1 = y.load(std::memory_order_relaxed); // A
x.store(r1, std::memory_order_relaxed); // B
// 线程 2 ：
r2 = x.load(std::memory_order_relaxed); // C 
y.store(42, std::memory_order_relaxed); // D
```
允许出现`r1 == r2 == 42`,因为在编译器和CPU的乱序执行的共同作用下，可能执行的顺序为`D->A->B->C`。
Relax约束最少，适合作为无依赖的原子变量使用，比如单独的引用计数。

# Acquire-Release
对同一原子变量的`Acquire-Release`操作，将会影响到修改原子变量之前和之后的读写顺序。简单地说，在线程1中`Release`操作之前发生的所有`store`操作，在线程2`Acquire`之后都保证可见。
还是拿cppreference里例子。

```cpp
std::atomic<std::string*> ptr;
int data;
void producer()
{
    std::string* p  = new std::string("Hello");
    data = 42;
    ptr.store(p, std::memory_order_release);
}
 
void consumer()
{
    std::string* p2;
    while (!(p2 = ptr.load(std::memory_order_acquire)))
        ;
    assert(*p2 == "Hello"); // 绝无问题
    assert(data == 42); // 绝无问题
}
```
虽然这里的原子变量只有`ptr`,但是在`ptr`的release操作之前，对`int data`的写入操作， 对于`consumer`  acquire后的两个assert一定是可见的。

`Acquire-Release`还具有传递性，比如来自`cppreefrence`的另外一个例子.

```cpp
void thread_1()
{
    data.push_back(42);
    flag.store(1, std::memory_order_release);
}
 
void thread_2()
{
    int expected=1;
    while (!flag.compare_exchange_strong(expected, 2, std::memory_order_acq_rel)) {
        expected = 1;
    }
}
 
void thread_3()
{
    while (flag.load(std::memory_order_acquire) < 2)
        ;
    assert(data.at(0) == 42); // 决不出错
}
```

这里的关键在于`thread2`中的`acq_rel`操作，它确保了`data.push_back(42)`一定发生在`compare_exchange_strong`之前。


# Release-Consumer

简单的说，只确保原子变量及其依赖的读写是可见的，`Release-Acquire`中举的第一个例子，可能会出错，因为不保证data的读写一定能看到。
根据cppreference, The specification of release-consume ordering is being revised, and the use of memory_order_consume is temporarily discouraged. 
请直接忽视这个语义。

# Sequentially-consistent order

加强版的Acq-Rel，要求所有线程的指令都按照源代码的书写顺序来执行，不允许重排，`Acq-Rel`有的性质它都有。

# Reference
https://en.cppreference.com/w/cpp/atomic/memory_order