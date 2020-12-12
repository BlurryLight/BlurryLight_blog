
---
title: "xv6的lock,sleep,wakeup的实现"
date: 2020-12-12T14:37:26+08:00
draft: false
# tags: [ "" ]
categories: [ "xv6"]
# keywords: [ ""]
lastmod: 2020-12-12T14:37:26+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "xv6_lock_sleep_wakeup_implement"
toc: false
# latex support
# katex: true
# markup: mmark
---

# 自旋锁的实现
在xv6中实现有两种锁，自旋锁和睡眠锁，其中睡眠锁的实现是依靠自旋锁来实现的。自旋锁的实现相当的简单，我们首先考虑一个**错误的**锁的实现。
```cpp
struct spinlock
{
    uint locked;
};
```
错误的加锁实现:
```cpp
void acquire_lock(struct spinlock *lk)
{
    for(;;)
    {
        if(lk->locked == 0)
        //<--------------- potential race condition
        {
            lk->locked = 1;
            break;
        }
    }
}
```
这个实现的问题在于，检测`locked`和`lk->locked=1`这两个操作之间不是原子的，导致可能出现竞态条件。如果有两个CPU同时看到`lk->locked==0`,那么会有两个cpu同时加锁，违反了锁的独占性。

许多硬件的实现提供了一些原子指令来帮助我们实现锁，这些指令在不同的指令集上虽然长得不一样。`gcc`帮我们实现了一个函数`__sync_lock_test_and_set`, 使得我们无需为每个架构都编写一次汇编。
因此正确的锁实现应该是
```cpp
void acquire(struct spinlock *lk)
{
    push_off(); //关闭所有中断
    //... 做一些assert

    while(__sync_lock_test_and_set(&lk->locked,1) != 0) 
        ;
    __sync_synchronize();//Barrier
    pop_off(); //恢复中断
}
```
`__sync_lock_test_and_set`函数的作用很简单，**原子地**将`lk->locked`的值替换为期望的值，并返回旧的值。当锁被其他cpu加锁的时候，该循环因为返回旧值为`1`而一直自旋。`__sync_synchronize()`是屏障，确保所有的CPU都能看到这个更新。

# sleep和wakeup

xv6实现`sleep`就是把进程的状态调整为`sleeping`，并且让出CPU的过程。这个过程和`Linux`里的`conditional variable`比较接近。考虑一个竞态条件
```cpp
int count = 0;

void foo()
{
    while(count == 0)
    //potential race condition
      sleep();
}

void bar()
{
    count+=1;
    wakeup();
}
```
在`while`和`sleep`之间存在竞态条件，如果`wakeup`在`while`和`sleep`之间发生，那么这个`sleep`永远不会醒来。
另外一个错误的实现是试图用一把锁来保护这个静态条件。
```cpp
int count = 0;
struct spinlock lock;

void foo()
{
    acquire(&lock);
    while(count == 0)
    //potential race condition
      sleep();
    release(&lock);
}

void bar()
{
    acquire(&lock);
    count+=1;
    wakeup();
    release(&lock);
}
```
在foo睡眠以后，它带着已经被加锁的锁睡眠了，那么当`bar`发生的时候，会陷入死锁状态，因为持有这个锁的进程正在睡眠，而唤醒它的操作需要这把锁。

一个正确的实现需要确保`while和sleep`之间被锁保护，但是在`sleep`之前，需要释放这把锁，这暗示我们需要用两把锁。
```cpp
void sleep(strcut spinlock *lk)
{
    struct proc* p = myproc();
    if(p->lk != lk)
    {
        acquire(&p->lk);//先加锁进程的内部的锁，确保在解锁lk到陷入睡眠期间，不会有wakeup发生
        release(lk); //然后释放保护count的锁
    }
    //do something , change p->state
    //...
    sched();//让出cpu,进入该函数前必须持有p->lock,在调度过程中会释放掉p->lock

    //被唤醒，释放进程锁，恢复原来的锁
    if(p->lk != lk)
    {
        release(&p->lk);
        acquire(lk); 
    }
}
void wakeup()
{
    struct proc* p;
    //find sleeping p
    acqurie(&p->lock);
    //if p is sleeping
    p->state = RUNNABLE;
    release(&p->lock);
}
```

以上的实现中，我们用在释放掉保护`count`的锁之前，先加锁了进程内部的锁`proc->lk`，而`wakeup`也需要这把锁。进程内部的锁会在调度器中被释放掉，这确保了我们在`sleep`实际发生之前，`wakeup`不可能发生。

# Linux中的conditonal variable

如果我们去查看Linux的API`pthread_cond_wait(pthread_cond_t *cv,pthread_mutex_t *mutex)`，会发现参数里同样传了一个`mutex`进去，并且在调用这个函数之前一定要是加锁状态。
其内部实现大约是（猜测的：
```cpp
auto pthread_cond_wait(&cv,&mutex)
{
    LOCK_ACQUIRE(&another lock);
    //主要是保护以下两句是原子的
    release(mutex);
    wait_for_cv();//sleep
    //wakeup
    lock(mutex);
    LOCK_RELEASE(&another lock);
}
```

