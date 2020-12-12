
---
title: "xv6的内核态与用户态的切换"
date: 2020-11-17T15:00:03+08:00
draft: false
# tags: [ "" ]
categories: [ "xv6","Linux"]
# keywords: [ ""]
lastmod: 2020-11-17T15:00:03+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Xv6内核态与用户态的切换"
toc: True
# latex support
# katex: true
# markup: mmark
---
当一个进程需要调用kernel提供的服务的时候，他们调用一个`system call`， 在x86上一个system call大概类似于`int 0x80`的一条指令，而在RSIC-V的xv6调用syscall的方式是通过`ecall`指令, 并把进行的系统调用的编号放到a7寄存器。`ecall`会修改特权等级，并且进入到由内核控制的某个函数入口。
```asm
.global fork
fork:
 li a7, SYS_fork
 ecall
 ret
```
![xv6kernel](/image/xv6kernel_user.png)

## 从User进入Kernel
当一个ecall指令被调用，首先跳到`uservec`的函数。
这个函数具有两个特征
- 必须由汇编编写，因为它需要直接操作寄存器。从用户态进入到内核态，需要在进程内部保存所有用户态的寄存器，否则进入内核以后没办法再返回来。
- 这个函数必须位于一个内核的页表和用户的页表相同的虚拟地址，因为这个函数需要切换用户页表到内核页表，切换完了以后要能继续工作。

因此内核和每一个用户进程的页表都拥有一个叫做`TRAMPOLINE`的映射，他们的虚拟地址和物理地址是一样的，在这一页里包含了`uservec`和`userret`函数。
每一个进程的`proc`结构体内，有一个`trapframe`的页面，这一个页面的地址会被放置到`sscratch`寄存器，而这一个页面的主要用途是用于保存所有寄存器。
当`uservec`发生的时候，`uservec`先找到进程`trapframe`(此时还是用户态的页表)，然后依次在trapframe保存所有的寄存器,保存完所有寄存器以后，切换到内核页表，跳转到`usertrap`函数，此时已经完全进入内核，在`usertrap`函数里面判断所有的trap来源。

![trapframe](/image/xv6_trapframe.png)


## SIGNAL的实现

在xv6的一个lab实验中要求实现sigalarm，需要实现定时器，当定时器事件发生的时候需要进入到用户态去调用`signal_handler`，其实从内核返回到用户态的时候，需要设置`epc`的寄存器，确定回到进程以后从哪里执行，默认是从进入内核的指令的下一条指令。修改`p->trapframe->epc`到`signal_handler`的地址跳转到`signal_handler`。
还有更难的要实现`sigreturn`，就是`signal_handler`执行完成以后返回到执行前的指令，这需要在进程内部再开辟空间，在跳转到`signal_handler`之前保存所有的寄存器，这样从`signal_handler`返回以后可以恢复所有的寄存器，从而在下次回到用户态的时候，恢复到信号发生之前的状态。