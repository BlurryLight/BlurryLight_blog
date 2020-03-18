
---
title: "Linux的socket指北"
date: 2020-03-16T22:13:26+08:00
draft: true
# tags: [ "" ]
categories: [ "默认分类"]
# keywords: [ ""]
# lastmod: 2020-03-16T22:13:26+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "Linux的socket指北"
toc: false
# latex support
# katex: true
# markup: mmark
---

# socket概览

这是继`signal`, `pthread`后的第三篇，`socket`系列，代表的是进程间通讯和网络通讯。我没有读过`unp`，对网络编程一窍不通(虽然我挺想学的)。 主要着重记录`socket`一些基础概念以便以后翻阅，用途也主要用于IPC。`IPC`(进程间通讯)有很多种方式，`FIFO`,`system V IPC`,`Posix IPC`，`socket`, `signal`,`PIPE`等，各有优劣，都是时代的眼泪，不同的主机(微机，巨型机)，不同的操作系统贡献了不同的方式。我个人比较喜欢用`signal`的方式，因为写起来简单，但是仅限于简单的通知某进程。如果在进程间要传递数据，`socket`是不二之选，因为它很容易被扩展到网络上的不同主机上。`socket`虽然起源于BSD, 但是现在在`SUSv3`标准里，所以不用担心移植性。

提到`socket`就不能不提到**IO复用**的概念，主要指`select`,`poll`以及Linux的`epoll`，BSD的`kqueue`系列函数。这允许我们同时对许多许多个IO进行监控(`socket`也是一种IO操作)，现代高性能网络库的基石。不过这篇文章里不会讲`epoll`的概念。

一个socket通讯建立的基本流程[^1]:
- 客户端(client)
  - 创建一个socket (socket())
  - 把socket连接到server的地址上(也许是IP，也许是本地的一个文件) ( connect())
  - 接收/写数据 (read/write) 

- 服务端(server)
  - 创建一个socket
  - 把socket绑定到某个地址上，互联网的socket是ip地址加端口号，本地socket是一个文件地址
  - 监听socket上的连接(listen)
  - 监听到连接后，接收连接(accept())
  - 接受/写数据
  

[^1]: [Sockets Tutorial](http://www.cs.rpi.edu/~moorthy/Courses/os98/Pgms/socket.html)
