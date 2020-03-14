
---
title: "Pthread指北"
date: 2020-02-25T23:35:58+08:00
draft: false
# tags: [ "" ]
categories: [ "C++","Linux"]
# keywords: [ ""]
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Pthread指北"
toc: true
---

# Pthread简介

  `Pthread`,也即`Posix thread`，顾名思义，是posix的一部分，跨平台的线程库。Linux上的现在的实现是`Native POSIX Threads Library`,也即`NPTL`. Thread是一种并行的机制，在多核处理器上，不同的线程可以被调度到不同的核上运行，从而获得接近线性增长的效率提升。在单核处理器上，使用多线程程序在IO密集型程序上也能获得收益，因为在IO阻塞的时候，切换到其他线程可以继续工作，从而提高程序的有效运行效率（而不是傻傻的阻塞等待IO，在Python中由于GIL的存在，Python的多线程不能调度到其他核运行。所有的线程独享自己的栈空间，共享同一个堆地址空间，这会带来一些变量使用上的便利，避免频繁的IPC通讯，同时也带来了严重的风险：race condition将会导致所有线程工作不正常，或者程序异常终止。

# 线程继承和不继承的属性

当一个线程启动的时候，它会从其他线程中继承一些信息。典型的如:

- 进程有关的信息(pid,ppid,pgid)
- 打开的文件描述符(fd)
- **信号处理方式**
- timer相关信息，对进程的资源限制，nice value以及一些其他的和进程相关的信息

每个信号独立拥有的信息(重要的):

- 线程ID(thread id)
- **信号阻塞集(sigmask)**
- **errno**
- thread-specific data和线程栈上的变量

# 线程管理

## 线程创建
```
#include <pthread.h>
int pthread_create(pthread_t *thread,const pthread_attr_t* attr,void*(*start)(void*),void* arg);
return 0 on sucess
```
`attr`可以传`NULl`,代表属性默认（最通常的情况）。`start`是一个返回`void*`,接受`void*`参数的函数，当线程启动的时候该函数会**立刻**被执行。`arg`是要传进去的参数，如果要传多个参数，可以传一个结构体进去，在`start`函数内部强转类型(没有范型的痛)。
`attr`参数可以用`pthread_attr_init`和`pthread_attr_destroy`来设置，用来设置线程的一些属性。


线程不保证执行顺序，如果线程之间有顺序依赖关系，需要用条件变量、共享变量或者信号等方式来同步。

线程ID,`pthread_t`在Linux的实现是一个unsigned long,但是POSIX规范没有规定pthread_t是什么，任何对它类型的假设都会导致代码不可移植。

## 线程结束

线程内部函数可以有返回值，虽然返回的是个`void*`,需要强转类型，同样，也可以返回一个结构体。线程的结束通常是以下原因:

- `start`函数执行完成并返回
- 线程内部执行了`pthread_exit`
- 其他线程调用了`pthread_cancel`
- 任何线程执行了`exit`，或者`main`函数返回了(相当于执行了exit)，所有线程会被释放。

```
#includee <pthread.h>
void pthread_exit(void* retval);
```

## 线程join与detach

`pthread_join`和进程中的`waitpid`差不多，阻塞等待线程结束。如果线程已经结束了，pthread_join会立刻返回。区别是`waitpid`只能父进程wait子进程，而`pthread`之间是平等的，任何线程都可以join其他线程。共同点是如果不join/wait, 已经执行完的线程/进程不会被操作系统回收，而是等待被收尸。未被收尸的线程/进程都会占用系统资源(在Linux的实现中线程和进程都是`task_struct`结构体)，进程资源泄漏的话会导致操作系统最终无法创建新进程。



