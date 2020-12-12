
---
title: "xv6 fork的实现"
date: 2020-11-23T14:20:32+08:00
draft: false
# tags: [ "" ]
categories: [ "xv6","Linux"]
# keywords: [ ""]
lastmod: 2020-11-23T14:20:32+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "xv6fork的实现"
toc: false
# latex support
# katex: true
# markup: mmark
---

`Posix`中规定的`fork`的签名很简单，这个函数的作用是复制一个新的进程，子进程和父进程被复制出来是一样的，Linux的实现还会采用`cow`复制，也就是共享一份物理地址空间，直到有写入发生的时候才实际上复制被污染的页。`xv6`的一个lab也是要实现`cow`复制。这个函数最有意思的一个特点是，该函数会返回两个值，对父进程返回子进程的`pid`,而对子进程返回`0`，所以常见的fork的编程范式是

```cpp
//pid_t fork(void);
pid_t pid = fork();
if(pid) // parent process
{
    //do something in parent process
} else
{
    //do something in child process
}
```

简单的函数签名下蕴含了相当深入的知识———进程调度，不妨问一个问题：为什么fork函数能够返回"两个值"？

# xv6的进程调度
## 进程调度的时机
在xv6中，进程调度由时间中断(timer interrupt)控制，时间中断发生后，内核在`usertrap`函数中捕获该中断，然后跳转到`yield`函数，`yield`的函数主要作用是把进程的状态从`running`设置到`runable`，代表进程让出此`cpu`,并且跳跃到`sched`函数，`sched`函数是实际进行上下文切换的函数。

```cpp
//usertrap
if(which_dev == 2) yield(); //如果是时间中断，yield

//proc.c
void yield(void)
{
    //...
    p->state = RUNNABLE;
    sched();
    //...
}
```

## 上下文切换
所谓上下文切换其实在xv6中我们已经见过很多了，从用户态进入到内核态需要保护所有用户态的寄存器，从内核态恢复到用户态需要恢复所有的寄存器。进程切换也是一样，从A进程切换到B进程需要保护A进程的现场，从其他进程切换回A进程的时候需要恢复A进程的寄存器，并且从切换走的地方继续执行。

在xv6中，保护进程切换寄存器的位置位于内核的进程结构体`proc`中，有一个专门的`proc->context`结构。
![](/image/context_swtch.png)

在xv6中，内核初始化的时候会给每一个核心绑定一个程序`scheduler`，该程序的内容很简单，死循环所有的进程列表，找到`runnable`的进程，切换过去。
由此xv6的进程切换可以实现成如下，

假设只有A，B两个进程，单个核心，当前A进程在运行
- 时间中断发生，A进程的state被设置成RUNNABLE
- 保存A进程的所有寄存器，恢复sheduler循环的所有寄存器，寻找到B进程的状态为RUNNABLE
- 保存sheduler的所有寄存器，恢复B进程的所有寄存器，然后把B进程的状态设置成RUNNING，完成进程切换
- 时间中断发生，B进程让出CPU，切换到sheduler的状态中
- 由于之前sheduler保存了状态，所以B进程已经被循环过了，此时循环到了结束，重头开始，回到了A进程
- 恢复A进程的寄存器，A进程上下文恢复，继续执行，中间被切换掉的过程对A进程是无感知的

# fork的实现

在xv6中的fork的实现是
```cpp
int fork(void)
{
    int child_pid = allocpid();
    // copy memory page table...
    // copy fp and other properties
    child_process->state = RUNNABLE;
    child_process->trapframe->a0 = 0;//return value is 0 for child_process fork()
    return child_pid;
}
```
而父进程的`a0`寄存器是
```cpp
void syscall(void)
{
    //...
    p->trapframe->a0 = fork(); //return value for parent is child_pid
    //...
}
```

`fork`的实现并没有违反c语言的基本规律，在调用fork()函数的父进程中确实返回子进程的pid，那么子进程的返回值0是从哪里冒出来的呢？玄机在于`child_process->state = RUNNABLE`。这里把创建出来的子进程的状态设置成可以被调度的子进程，可以理解，因为创建子进程本来就是为了运行。

玄妙之处在于，在创建子进程的`proc`结构体的时候，其`p->context.ra`，也就是`context`结构体中的一个寄存器被设置为`forkret`函数。forkret函数的唯一作用调用`usertrapret`从内核态返回用户态。

当子进程被创建的时候，它把context的返回地址设置为forkret函数。而当scheduler切换到这个进程的时候，自然会跳转到`forkret`函数，而`forkret`函数什么也没有做，直接从内核态返回到了用户态。
我们之前在fork函数中修改了子进程的`a0`寄存器，也就是用户态看到的返回值。由此，父进程看到的返回值是pid，子进程看到的返回值是0。

由此我们可以回答为什么fork进程会返回"两个值",因为在调用这个函数的会触发系统调用，进入内核以后进程分裂成了两个，并且从内核态返回的时候父进程和子进程携带不同的返回值。