---
layout: post
cid: 422
title: " 陷阱！如何实现Vector作为Class成员的初始化"
slug: 422
date: 2017-08-05
updated: 2017-08-05
status: publish
draft: true
author: panda
categories: 
  - cpp
tags: 
---


C++真是巨坑满地跑，稍不注意就掉坑里了。
先来看一段代码
```cpp
#include <vector>
using namespace std;

class test{
private:
 char str[10];\\this is OK
 //vector<int> a1(10);\\not OK
};
```


<!--more-->


原因是
> Knowing that the class has a vector member is important, but at compile time, there are no members. A "vector" class member is just a pointer in the object, whereas an "array" class member actually has that storage in the object itself.

翻译：在编译的时候Vector是一个指向对象的指针，而array却是有实际的大小。所以在类未完成构造前vector不允许初始化。

那么**陷阱**来了（花了2个小时debug)
```cpp
#include <vector>
using namespace std;

class test{
private:
 char str[10];\\this is OK
 vector<int> a1;
public:
 test()
{
  vector<int> a1(10);//在构造函数里面对vector a1进行初始化
}
};
```
猜一猜会发生啥？
事实上：
**a1在构造函数中无法完成初始化，其vector仍然是一个空的。**

真正Nice的写法，正确的写法（可以使用一个循环外加push_back，但是总觉得怪怪的）
```cpp
#include <vector>
using namespace std;

class test{
private:
 char str[10];\\this is OK
 vector<int> a1;
public:
 test():a1(vector<int> (10)) {};
};
```
在类的构造函数后使用冒号对成员列表进行赋值，这才是正确的进行初始化的方法,其赋值的成员可以是一个对象，也可以是一个变量。
形如对一个矩形进行赋值，默认为 1*2,也可以接受两个int变量来赋值，可以写作
```cpp
retangle():length(1),width(2){};
retangle(int len,int wid):length(len),width(wid){};

```





参考于[ Why you can't initilize a vector in a class?][1]


  [1]: https://www.gidforums.com/t-13851.html