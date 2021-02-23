
---
title: "Linux的socket指北"
date: 2020-03-16T22:13:26+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp","Linux"]
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
  
# socket的创建

 ```cpp
 #include <sys/socket.h>
 int socket(int domain, int type, int protocol);
 //return fd of socket
 ```
 第一个参数`domain`决定了socket是网络socket还是本地socket，这影响了socket addr结构体的选择。
 
 domain可以选择的参数包括:
 
 | domain   | socket_addr结构体 | 途径     |
 | -------- | ----------------- | -------- |
 | AF_UNIX  | `sockaddr_un`     | kernel   |
 | AF_INET  | `sockaddr_in`     | via IPv4 |
 | AF_INET6 | `sockaddr_in6`    | via IPv6 |

 第二个参数`type`指socket底层通讯的类型。至少可选的是`SOCK_STREAM`和`SOCK_DGRAM`两种类型，分别对应`tcp/udp`两种协议。(tcp需要建立连接，信息可以信赖; udp不需要建立连接，但是信息可能会丢失或者乱序)。

 **注意**：Linux 2.6内核以后，type参数可以通过**OR操作**传额外的flag到socket类型中。典型的是传`SOCK_NONBLOCK`,这个socket的读写操作不允许阻塞。

# TCP socket
先贴一张TCP socket的流程图[^2]。

![TCP socket](/image/stream_socket.png)
## socket的绑定

 ```cpp
 #include <sys/socket.h>
 int bind(int sockfd, const struct sockaddr* addr, socklen_t addrlen);
 //return 0 or -1
 ```
C语言没有多态和函数重载的阵痛: 每种socket对应不同的sockaddr_xx类型,但是在调用bind的时候必须要强转类型到sockaddr上，并传入正确的长度。

## listen和accept

```cpp
#include <sys/socket.h>
int listen(int sockfd, int backlog);
int accept(int sockfd,struct sockaddr* addr,socklen_t *addrlen); //return new sockfd when success
```
`listen`会将指定的sockfd标为被动模式，被标记的sockfd会用来接受其他socket的连接。backlog参数是指在server accept客户端的connect请求之前，最大排队请求连接的数量。

`accept`会创建一个新的socket,而这个新的socket会和请求`connect`的客户端socket连接在一起。一个服务器应用一般创建一个监听socket，绑定到一个公开的地址上(ip+port),客户端与这个公开地址请求连接(connect),但是连接成对的socket将会是一个新的socket，而不是这个正在listen的socket。accept还会返回客户端的地址和结构体长度。

## connect
```cpp
int connect(int sockfd,const struct sockaddr* addr,socklen_t addrlen);
```
没什么好说的，把客户端的sockfd连接到addr所指定的位置上。


# UDP socket
流程图[^2]

![UDP socket](/image/udp_socket.png)

## recvfrom & sento
udp socket名义上是connect-less的，但是实际上也可以使用connect. 把udp socket连接起来依然可以获得像tcp socket那样的伙伴关系(pair socket),意味着可以使用`read/write`统一IO操作。
udp socket也可以向任意socket发送数据。
```cpp
sszie_t recvfrom(int sockfd, void* buffer,size_t length, int flags, struct sockaddr* src_addr, socklen_t * addrlen);
sszie_t sendto(int sockfd, const void* buffer,size_t length, int flags,const  struct sockaddr* src_addr, socklen_t * addrlen);
//return bytes sent/received or -1 on error
```
API都比较直观。recvfrom指定从sockfd中接收数据，并指定缓存区的大小，还会记录数据的来源地址。sendto需要指定要使用的socket以及目标地址。不管是recvfrom/sendto,超出length的数据会被直接截断。

[^1]: [Sockets Tutorial](http://www.cs.rpi.edu/~moorthy/Courses/os98/Pgms/socket.html)
[^2]: The Linux Programming Interface
