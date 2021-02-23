
---
title: "Linux的signal指北"
date: 2020-02-19T17:53:26+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp","Linux"]
# keywords: [ ""]
lastmod: 2020-02-19T17:53:26+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Linux的signal指北"
toc: true
---
预计此系列有三篇文章，分别记录*信号(signal)*, *线程(pthread)* 和 *套接字(socket)* 方面的内容，作为学习知识的整理记录。只讨论**Linux**下面的API和表现。

# 信号简介
信号是一种通知进程的手段，源头可能是从kernel递送到进程，可能是自己给自己信号，也有可能是由其他进程发送过来(kill -9). 不同信号是通过不同的魔数区分开的(SIGTERM 15号信号，SIGKILL 9号信号)，不同的信号有不同默认的含义。信号还可以用来传递一些信息(很少用)。

信号通常是异步的，程序可能在任何代码段接受到递送过来的信号，部分代码可能会被打断，当被打断的时候，部分操作(比如`sleep`)会失败，并且`errno`会被置为`EINTR`，比如在阻塞等待socket的时候就可能会被信号打断。

默认下，多数信号的响应操作是终止(可能会导出core dump),所以发信号前一定要注意不要有竞争(race condition).如果在一个程序注册好handler之前就发起了信号，可能会导致程序直接终止。

传统程序使用`signal`函数(Linux也可以)，但是现在更推荐使用`sigaction`函数，拥有更灵活的操作，以及一个最主要的优点:`sigaction`可以在不改变handler的情况下获取当前的handler。

当进程阻塞某信号的时候，被阻塞的信号将会被挂起，直到进程解除阻塞。这里也要注意竞争条件，当在阻塞信号之前，信号就已经被递送到的时候，可能导致意料之外的情况(程序终止)。在阻塞期间重复多次信号，解除阻塞后，不可靠信号`[1,31]`，内核只会递送**一次**，而可靠信号`[SIGTMIN,SIGTMAX]`会被**有序**递送多次。

最后，`signal`是一个比`pthread`早出现的概念，在`signal`被发明的年代，多进程是主流。因此`signal`在多线程程序中应该极端小心，推荐的做法是主线程在启动的时候阻塞所有信号，派生出来的所有线程也会继承主线程的阻塞信号。单独拉起来一个线程，解除阻塞信号，处理事件。否则，在多线程程序中内核会随机挑选线程进行递送信号，可能会导致意料之外的程序执行。


# signal(),sigprocmask()和sigaction()
没什么好说的，`signal`API简单好用，就是功能少。`sigaction`罗嗦。`signal`和`sigaction`都会在handler里阻塞信号，比如注册了`SIGINT`的hanler以后，不可以再发送一个`SIGINT`打断该handler。区别的是`sigaction`还可以阻塞其他信号，比如收到一个信号以后，阻塞所有信号以防止重要的操作被打断。

## signal
signal:
```cpp
//函数签名
void handler(int sig)
{
    /* some handler code here*/
    //注意，stdio系列的函数都是异步不安全的
    //这里只是举个例子
    printf("received %d signal\n",sig);
}

// 接收一个handler参数，返回值是之前的handler或者SIG_ERR
void (*signal(int sig,void(*handler)(int))) (int);
```

有两个宏定义，`SIG_DFL`和`SIG_IGN`,代表默认处理和忽略该信号，很有用。

## sigset_t

提到`sigaction`之前先要提到`sigset_t`,一串掩码，可以想象成一排开关，每个掩码代表一个信号，0/1代表操作是否对该信号起效。
`sigset_t`不会默认初始化，所以一定要**手动**初始化,否则是未定义行为(什么情况都可能发生)。主要包括以下函数:

```cpp
int sigemptyset(sigset_t *set);
int sigfillset(sigset_t *set);
int sigaddset(sigset_t *set, int sig);
int sigdelset(sigset_t *set, int sig);
int sigismember(const sigset_t *set, int sig);
```

简单明了。还有一些辅助函数(GLIBC提供)

```cpp
//bit 类型嘛，和操作 / 或操作
int sigandset(sigset_t* set,sigset_t* left,sigset_t* right);
int sigorset(sigset_t* set,sigset_t* left,sigset_t* right);

//以及
int sigisemptyset(const sigset_t *set);
```

## sigprocmask

有了`sigset_t`以后，可以对整个集合做一些操作了。对一个进程而言，内核会记录一个信号掩码，记录哪些信号当前被阻塞(在线程模型中,kernel记录的信号掩码是对每个线程的，意味着每个线程可以单独阻塞不同的信号)。当一个handler被调用的时候，引起这个handler被调用的信号会被自动阻塞，直到handler被执行完。

手动调整阻塞掩码，需要使用函数`sigprocmask`

```cpp
int sigprocmask(int how,const sigset_t *newset,sigset_t *oldset);
```

`how`可以有`SIG_BLOCK`(阻塞当前的set和newset里面的所有信号)，`SIG_UNBLOCK`(在当前被阻塞的信号里，解锁newset里面的信号),以及`SIG_SETMASK`(替换阻塞信号为newset).当`oldset`不为`nullptr`的时候，返回旧的sigset. 当newset为nullptr的时候，只会返回旧的sigset。
阻塞所有信号的例子(`SIGKILL`和`SIGSTOP`不可阻塞)

```cpp
//没有做错误检查
sigset_t fullset;
sigfillset(&fullset);
sigprocmask(SIG_BLOCK,&fullset,NULL);
```

## sigaction

`sigaction`是更好的处理信号的方式，有很多额外的选项可以选。

sigaction:
```cpp
struct sigaction
{
    void (*sa_handler)(int); //handler
    sigset_t sa_mask;       //在handler执行期间要阻塞的信号(会自动阻塞引起handler调用时的信号)
    int sa_flags;           //一些flags选项
    void (*sa_restorer)(void); //application不应该使用这个参数,记录进入handler前的context
};

int sigaction(int sig,const struct sigaction* act,struct sigaction *oldact);

```
`flags`是一串比特，需要用或操作来添加。操作比较多，挑点重要的。

- `SA_NODEFER` 在handler执行期间不阻塞引起handler调用的信号，即允许handler重入。
- `SA_RESETHAND` 模拟`signal`的操作，当信号递送到的时候，重置它的hander为`SIG_DFL`.

# sigqueue，sigsuspend以及可靠信号

传统的unix信号是不可靠的，意味着他们不会排队，多次发送的信号可能只会被递送一次。实时信号和Linux扩展的，位于[32,63]之间的信号是可靠的。常用的可靠信号只有`SIGUSR1`和`SIGUSR2`.

发送可靠信号可以使用`sigqueue`:

```cpp
int sigqueue(pid_t pid,int sig,const union sigval value);
//可以传送一个额外的value结构，然而其实并没有什么用,能想到的好处大概是知道到底是谁在给这个进程发信号把
```

当我们在执行一些关键代码不想被打断时候，通常的选项是阻塞所有的信号，执行完成后，解除阻塞，然后`pause`等待信号到来。但是在解除阻塞和pause期间不是原子操作，有竞争风险。当信号在pause执行前到来，那么程序可能会永远睡死。为了解决这个问题，有了sigsuspend:

```cpp
//比较特殊的函数，当sigsuspend唤醒的时候，返回-1并且把errno置为EINTR
int sigsuspend(const sigset_t *mask);
//等价于(以下原子操作)
sigprocmask(SIG_SETMASK,&mask,&oldset);
pause()
sigprocmask(SIG_SETMASK,&oldset,NULL);
```
`sigsuspend`会用mask替换当前的阻塞mask，如果使用一个空集，那么任何信号都能唤醒`sigsuspend`.


# 同步信号
常用的信号处理都是异步处理，但是也可以像socket一样，同步阻塞等待一个信号到来，可以使用`sigwaitinfo`之类的api来*accept*信号，
