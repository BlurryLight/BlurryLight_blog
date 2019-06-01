---
layout: post
cid: 459
title: "谈谈observer_ptr"
slug: 459
date: 2019-05-25
updated: 2019-05-25
status: publish
author: panda
categories: 
  - C++
  - STL
tags: 
---



`observer_ptr`是于14年的提案N4282[^1]提出的一种“世界上最蠢的智能指针"，现在的`observer_ptr`在`std::experimental::memory`里，当然也可以自己写一个，`observer_ptr`的代码简单到”代码即文档“的级别了，但是目前来看`observer_ptr`应该是进不了标准库了，因为Bjarne Stroustrup在提案P1408R0[^2]:里有力的驳斥了`observer_ptr`。


<!--more-->


## What is observer_ptr
和智能指针家族的其他兄弟们一样(`weak_ptr`,`shared_ptr`,`unique_ptr`)，`observer_ptr`也是为了处理资源管理问题而诞生的。`C++`在语言层面上没有提供一种**只读指针**，当我们需要用指针来指代某个数据而使用`raw_pointer`，也即`T*`时，我们需要时刻紧绷心弦，一旦对本意为只读的指针错误的使用了`delete`，就会造成意料之外的资源释放。

一种可行的方案是采用自定义删除器的`unique_ptr`，如
```cpp
template <typename T>
	using read_only_ptr = unique_ptr<T，[](){/*do nothing*/};
```
这样通过取消`unique_ptr`的删除操作，可以避免被观察的对象被意外释放。然而`unique_ptr`的拷贝操作是被禁用的，一个用于只读某个对象的指针却不能被拷贝，这很让人迷惑。所以改进后的`observer_ptr`应该是这样：
```cpp
tempate <typename T>
	class observer_ptr
	{
		private:
			T* ptr;
		public:
		observer_ptr(T* pt):ptr(pt){}
		~observer_ptr(){/*do nothing*/}
		T* get(){return ptr;}
		//other codes to work with STL......
	}
```
`observer_ptr`应该可以正确访问所指代的对象，表现的类似`T*`，拥有`dereference`和`->`操作，它析构的时候应该无任何副作用，不对指针指向的区域造成任何影响。

### Problems
`observer_ptr`看起来解决了一个关于只读指针的痛点，为C++彻底删除原始指针的宏大目标又前进了一步，然而比起`observer_ptr`所解决的问题，它带来了更多的麻烦。
- `observer_ptr<T>`和`T*`是不同类型，无法隐式转换,这意味着它严重破坏了C兼容性，当然也可以使用`get()`来获取原始指针，但是这样`observer_ptr`等于没有使用。
- `const iterator`是另外一种`observer_ptr`，而且工作的很好，在功能上有重复之处。
Bjarne还指出，`T*`在代码中非常常用。如果都要替换成`observer_ptr`，模板展开的时间会拖慢编译速度。
Bjarne提出的替代方案是
```cpp
	template <typename T>
		using observer_ptr = T*;
```
通过模板别名来表示**非拥有指针**，而拥有资源的指针一律使用`unique_ptr`和`shared_ptr`，但是不从代码上对`delete`进行禁用。错误使用应该由错误的程序员负责，这很cpp。
[^1]:[A Proposal for the World's Dumbest Smart Pointer, v4](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2014/n4282.pdf)
[^2]:[Abandon observer_ptr](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1408r0.pdf)

