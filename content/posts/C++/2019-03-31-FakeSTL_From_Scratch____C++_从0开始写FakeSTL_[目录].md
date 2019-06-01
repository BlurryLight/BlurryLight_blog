---
layout: post
cid: 443
title: "FakeSTL From Scratch  | C++ 从0开始写FakeSTL [目录]"
slug: 443
date: 2019-03-31
updated: 2019-04-13
status: publish
author: panda
categories: 
  - C++
  - STL
tags: 
  - cpp
---


## 引言
我的项目地址 ： [BlurryLight/PDSTL][1]
目前处于边学边写（半抄半写）状态。
我的知识水平：cpp beginner


<!--more-->


## STL
我先推荐一本《C++标准库 第二版》，第二版包含了C11的内容，对右值，shared_ptr,Lambda等内容都进行了详尽的阐述。这是一本介于字典(`cppreference`)和教学书籍（`cpp primer`），感觉更贴近于effective系列，包含了许多标准库的惯用法。
STL主要由六个部分组成，主要是`allocator`,`container`,`algorithm`,`iterator`,`functors`,`adapters`。和常见的OO编程范式差别较大，对容器操作主要通过`algorithm + iterator + container`的组合来完成。
如果你对我上面讲的六个组件比较陌生，建议买一本介绍标准库的书读。

## 需要的能力
1. 基本的数据结构（红黑树，跳表这种少见的数据结构可以边学边写，本身写FakeSTL的最大收货也集中在数据结构这一块）
2. 基本掌握C++模版 （最好能理解C++的类型推导原则，知道模版的引用折叠规则）
3. 知道STL的大概实现 （至少要知道`deque`,`vector`,`list`下面是数据结构，`stack`，`queue`是配接器）
4. 良好的代码规范（驼峰命名，匈牙利之类的这些都可以不纠结，但是风格要统一，代码划分要清晰。容器之间不应该相互依赖）

## 实现顺序和目标
我推荐[陈硕的回答][2]（他的回答总是很有干货），实现STL最难的就是定目标。现在是2019年了，modern C++已经出台8年了。C14，C17的部分可以先放一放，但是C11引入的新特性应该尽量使用，写的container的接口也要尽量满足C11的标准。除了陈硕所提到的5点外，还要注意工程管理的，`fakeSTL`也不算一个小项目，而且属于底层基本类库，**单元测试**是一定要加上的。尤其是对`allocator`和`container`的增删查改，单元测试没做好浪费在debug的时间上会增加很多。

### 实现顺序
我个人是推荐按照`allocator,iterator，vector + list`,前三个实现了后面的`algorithm,functors,containers`都是混杂在一块写。`algorithm`也可以放在很后面，因为通常来说，高频使用的函数实现通常都很简单，可以先用`std`代替着，这样也可以保证在单元测试里你的`containers`能在`std::algorithm`正常工作。

#### Allocator
`Allocator`的实现可简单可复杂，作为一个练手项目我推荐按复杂的写。简单的就是一层对`operator new`,`placement new`的封装，由系统来接手内存分配的问题，这样的代码很简单，只要照着`cppreference`满足对应的`traits`和接口，返回正确的指针，就能正常工作，通常来说工作的也很好，多数情况下应该比自己实现的内存池要好。中等难度的建议实现`memorypool`，`allocator`能正确的在内存池里分配和销毁内存，但是不用管回收内存碎片的问题。高难度就是元素销毁后能正确回收内存，在`list`这种内存不连续的情况下，能够重新分配回收的内存块，实现销毁后内存的复用。

####  iterator
`iterator`的`traits`和五种类型以及他们的派生关系要搞清楚，这个更多是概念性的问题，实现起来反而很简单，这里应该算比较难理解的部分。

#### vector & list
建议先写一个`vector`和`list`练练手，`vector`下面是一片连续的内存空间，`list`是一个链表，结构简单，代码码起来也快，这里是对之前码的`allocator`的一种检验，也是熟悉模版编程的一种方法。接口抄`cppreference`的就好,注意细读，主要是读哪些是**未定义行为**。不同编译器对未定义行为有不同的实现方式，在自己实现容器的过程中可以参照，也可以自己省事。实现起来有困难的时候，建议读`STLPort`和`libcxx`的代码，`gcc`和`msvc`的不推荐，不容易看懂。

#### smart_pointers
这个我单独拎出来讲，是因为智能指针是C11的最重要部分之一，所以至少要实现`shared_ptr`,`unique_ptr`和`weak_ptr`。智能指针的实现和容器的实现又差别较大，泛型的思维较少，主要要建立资源所有权的概念。

## 目录
我会不断的更新此页面，用来整理各个部件的实现过程和笔记。
[FakeSTL From Scratch | 编写Allocator][3]
[FakeSTL From Scratch | Iterator and Traits(迭代器与类型萃取)][4]
## 其他
学写STL不要怕抄，大胆的抄，看不懂`libcxx`还可以看`STLPort`，看不懂`STLPort`还可以看`EASTL`(代码风格非常好，注释完整，命名规范）,再看不懂也可以在github上搜索`Tiny STL`或者单独的`vector`,`map`等部件来学习。有不少的优秀实现，而且通常注释完善，单元测试覆盖优秀。能从0开始从`ISO标准`实现完整STL的是神人。半抄半理解，再到自己重现，是一个效率很高的学习过程。
STL的标准繁多，细节林林总总，一个不注意，很容易落入细节之中耗费大量时间。作为初学者，应该以正确实现目标功能为首要目标，其次是代码可读性好，训练自己写文档和写注释的能力。`FakeSTL`代码量视实现的规模，通常在万行以上，实现的比较完备（容器和算法对各种内建类型都实现偏特化）可能能达到几万行。如何掌握，管理这样的代码规模，也是一个初学者必须要注意的事情。更深入的讲，实现的STL也要能满足`clang`,`MSVC`,`gcc`的编译，尽量不用和少用编译器自带的`feature`。符合标准是最末的目标，为了符合标准可能要做大量的体力活，不划算。


  [1]: https://github.com/BlurryLight/PDSTL
  [2]: https://www.zhihu.com/question/53085291/answer/133458242
  [3]: https://www.blurredcode.com/2019/04/445.html
  [4]: https://www.blurredcode.com/2019/04/452.html