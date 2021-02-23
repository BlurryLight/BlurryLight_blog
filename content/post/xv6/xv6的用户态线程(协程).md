
---
title: "xv6的用户态线程(协程)"
date: 2021-02-23T20:22:46+08:00
draft: false
# tags: [ "" ]
categories: [ "xv6"]
# keywords: [ ""]
lastmod: 2021-02-23T20:22:46+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "98bbdc4e"
toc: true
# latex support
# katex: true
# markup: mmark
---

来自MIT6S081的[多线程lab](https://pdos.csail.mit.edu/6.828/2020/labs/thread.html), 需要在用户态实现一个“多线程”，实际上是一个简单的协程的实现。其实这个lab挺容易的，因为只需要弄懂保存上下文就可以很容易的解决整个问题。

在协程切换之间，我们需要保存不同协程的运行上下文，其中需要保存的包括
- 所有`callee-saved`的寄存器，`caller-saved`的寄存器不用保存，编译器会帮我们生成相关的代码，注意，以下代码是平台相关的(risc-v)。
- `ra`寄存器，当指令`ret`被调用的时候，指令寄存器`pc`会被重置到`ra`所保存的地址。
- `sp`寄存器，也就是栈寄存器。这里的实现是有栈协程，所以每个协程拥有独立的栈区。这里很容易犯错，如果我们开辟一个`char stack[SIZE]`,那么`sp`寄存器应该被设置为`stack + SIZE`, 也就是数组的末端，地址的高位。因为对栈内存的使用都是从高位向地位地址。
  
## 结构体
由此我们可以写出协程的定义
```c
struct context {
uint64 ra;
uint64 sp;

// callee-saved
uint64 s0;
uint64 s1;
uint64 s2;
uint64 s3;
uint64 s4;
uint64 s5;
uint64 s6;
uint64 s7;
uint64 s8;
uint64 s9;
uint64 s10;
uint64 s11;
};

struct uthread {
  char       stack[STACK_SIZE]; /* the uthread's stack */
  int        state;             /* FREE, RUNNING, RUNNABLE */
  struct context context;
};

```
## 初始化
当我们初始化一个协程的时候，简化后的代码应该类似如下
```c
void uthread_create( void(*func) ())
{
 //find some slot in uthread[SIZE]
 
 t->state = RUNNABEL;
 t->context.sp = (uint64)t->stack + STACK_SIZE;
 t->context.ra = (uint64)func;
 //为什么设置ra在这里，因为当协程第一次被调度的时候，ret指令会返回到ra所指的地址，也就是传入的函数指针开始的地方。

}
```
## 协程调度
协程调度和进程调度的一大区别就是，协程的调度是靠主动出让cpu,而进程的调度是由时间中断控制。由此协程必须在控制流中手动让出cpu,以使得其他协程运行。
```c
void uthread_yield()
{
    current_thread->state = RUNNABLE; //stop current uthread
    shed(); // tell scheduler to find next one
}
```

另外一个比较特殊的一点是，在xv6的进程调度中，有一个特殊的进程被绑定在cpu的核上，这个进程就是`scheduler`。这个进程的作用主要是在进程的结构体内保存进程调度的状态。进程A到进程B的切换需要经过`A -> scheduler -> B`的过程，这个过程中`scheduler`需要记录当前的进程变成了`B`。 在这个协程的实现中没整这么复杂的东西，用了一个全局变量的指针`uthread*`来记录当前在运行的协程。

## 保存和切换上下文
最后到了保存和切换上下文。听说`setjmp`和`longjmp`能够实现协程的切换，不过我自己没实现过，这里采用的是手动编写汇编来切换，和内核里的进程切换差不太多，复制过来就行。

```asm
	.text

	/*
         * save the old thread's registers,
         * restore the new thread's registers.
         */

	.globl thread_switch
thread_switch:
	/* YOUR CODE HERE */
        sd ra, 0(a0)
        sd sp, 8(a0)
        sd s0, 16(a0)
        sd s1, 24(a0)
        sd s2, 32(a0)
        sd s3, 40(a0)
        sd s4, 48(a0)
        sd s5, 56(a0)
        sd s6, 64(a0)
        sd s7, 72(a0)
        sd s8, 80(a0)
        sd s9, 88(a0)
        sd s10, 96(a0)
        sd s11, 104(a0)

        ld ra, 0(a1)
        ld sp, 8(a1)
        ld s0, 16(a1)
        ld s1, 24(a1)
        ld s2, 32(a1)
        ld s3, 40(a1)
        ld s4, 48(a1)
        ld s5, 56(a1)
        ld s6, 64(a1)
        ld s7, 72(a1)
        ld s8, 80(a1)
        ld s9, 88(a1)
        ld s10, 96(a1)
        ld s11, 104(a1)
	ret    /* return to ra */

```

## 思考题

这个lab还留了两个思考题。
- 协程切换的时候只需要保存callee-save的寄存器，为什么？
因为协程切换的过程类似
```c
//1. do some work
yield();
//2. do some work again
```
在1和2两步的之间穿插有函数调用，被调用的函数有义务保存callee-saved寄存器，用以确保在1和2两步的时候，所有callee-saved寄存器都是一样的。caller-saved的寄存器不关被调函数的事情。

- This sets a breakpoint at line 60 of uthread.c. The breakpoint may (or may not) be triggered before you even run uthread. How could that happen? 。使用gdb在`uthread.c`上打一个断点，可能在uthread被调用之前就被触发，为什么？
  
因为gdb的实现依赖于监视`pc`寄存器，我们在`b some_func`的时候实际上是记录的某个地址。如果`uthread`内的指令地址与内核的指令地址有重复，那么当内核运行到这个地址的时候就会触发本应该在`uthread`内的断点。此外，很容易验证不同的用户态程序也会干扰。比如在`uthread`内部的`0x3b`之类的地址打下个断点，再运行`ls`或者其他用户态程序，如果在`0x3b`地址的指令是合法的，那么也会触发本应该在`uthread`程序内部的断点。