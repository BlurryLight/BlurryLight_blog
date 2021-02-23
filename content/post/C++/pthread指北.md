
---
title: "Pthread指北"
date: 2020-02-25T23:35:58+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp","Linux"]
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

```cpp
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

```cpp
#include <pthread.h>
int pthread_join(pthread_t thread_id, void** retval); //成功返回0
int pthread_detach(pthread_t thread_id);
```

`pthread_join`和进程中的`waitpid`差不多，阻塞等待线程结束。如果线程已经结束了，pthread_join会立刻返回。区别是`waitpid`只能父进程wait子进程，而`pthread`之间是平等的，任何线程都可以join其他线程。共同点是如果不join/wait, 已经执行完的线程/进程不会被操作系统回收，而是等待被收尸。未被收尸的线程/进程都会占用系统资源(在Linux的实现中线程和进程都是`task_struct`结构体)，进程资源泄漏的话会导致操作系统最终无法创建新进程。

`pthread_join`有一些注意点:

1. 线程之间是平等的，任何线程都可以join其他线程。然而一般的良好实践是由主线程来负责收尸
2. join线程必须显式指定需要join的线程。不存在`join`任意线程的选项，也不存在**尝试**join这一选项。`join`一个还未完成的线程，一定阻塞。

有的时候我们并不关心线程的返回值，也不关心线程是否结束(一个典型的例子是拉起一个专门负责IO的线程,这个线程的唯一任务就是在后台进行IO,直到程序运行结束)。这种线程称为`detached`线程,可以在线程被拉起时`pthread_detach(pthread_self())`,也可以由主线程来`detach`，甚至可以在创建线程中传入`attr`中指定`detach`属性。

**warning:**

- `join`同一个线程两次，或者`join`一个已经被detach的线程是错误行为,在C++中会抛异常，没有被catch住的话，会自动调用`terminate`结束程序。

## 线程安全的变量和函数

线程之间共享堆空间、地址空间和全局变量，不同线程对同一变量的操作会导致race-condition. 因此，对于临界区(critical section)的访问需要保证原子操作，常用的手段是互斥锁。
```cpp
#静态初始化
pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;
#动态初始化一个锁
int pthread_mutex_init(pthread_mutex_t* mutex,const pthread_mutexattr_t * attr);
int pthread_mutex_destroy(pthread_mutex_t* mutex);

#上锁解锁
int pthread_mutex_lock(pthread_mutex_t* mutex);
int pthread_mutex_unlock(pthread_mutex_t* mutex);
```

**warning**: 

- 在C中由于没有RAII，mutex的上锁和解锁必须小心，在上锁和解锁中间应该确保没有任何可以跳出这段代码的方式(GOTO,RETURN)，否则会导致永远锁死。
- 有多个`mutex`变量的时候，一定要确保不同线程上锁和解锁的顺序是一样的，否则会造成死锁。
- 对同一个*平凡的*mutex加锁两次,解锁不是本线程加锁的锁，解锁没有上锁的锁都是未定义行为
- 复制一个Mutex变量是未定义行为

Mutex可以在attr中设置成引用计数锁，可以重复加锁，然而这个功能并没有看出来有什么用。

一个函数如果是线程安全的，也即可重入(Reentrancy)的。`Posix`指定了一大票函数是必须可重入的(实际上常用的不多。凡是**有状态**的函数基本都是不可重入的。典型的如`malloc`,在内核里它会记录已经分配的内存，显然是不可重入的，凡是能返回指针的函数一般也是不可重入的，因为内部一般有`malloc`。和IO有关的函数也是不可重入的，典型的`printf,std::cout`。除了posix规定的函数外，glibc提供了额外的可重入函数，函数为`_r`结尾的代表可重入。不可重入的函数在调用的时候应该用mutex加锁保护。

## 条件变量

条件变量和进程模型中的signal有相似用途。一个线程在完成了某件事后，可以使用条件变量通知其他线程进行其他工作,(生产者消费者模型中，生产者生产信息后，通知消费者线程来取走)。条件变量的好处是节约资源，它允许正在等待的线程睡眠(而不是死循环来浪费cpu)。
```
int pthread_cond_signal(pthread_cond_t* cond);
int pthread_cond_brodcast(pthread_cond_t* cond);
int pthread_cond_wait(pthread_cond_t* cond,pthread_mutex_t* mutex);
```
为什么cond_wait需要条件变量和mutex?
因为条件变量只起一个通知的作用，往往还需要检查一个共享变量。比如生产者模型生产了5份信息，通知消费者线程，消费者需要检测信息的数量。因此在pthread_cond_wait被调用的时候，它会
1. 解开mutex, 让生产者可以访问共享变量
2. 自身睡眠，等待条件变量
3. 条件变量到来，给mutex上锁，确保自己在检查共享变量的时候，共享变量只有自己能访问。

## 线程取消

GUI场景和计算密集型应用可能用的比较多，取消某个线程的执行。线程自身在启动的时候，可以把自己设定成不可取消。取消只会在固定的`cancellation points`被执行，一般是某些函数，posix标准里规定了一大批函数必须是取消点。简单的概括，凡是有可能阻塞线程的函数，都可能是取消点。

当一个线程被取消的时候，没有被detach的线程也必须被join, 否则会变成僵尸线程。被取消的线程被join的时候，返回值会是一个特殊的正数(定义在PTHREAD_CANCELED)里面。

```cpp
#include <pthread.h>
int pthread_cancel(pthread_t thread);
```



