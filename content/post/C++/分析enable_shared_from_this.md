
---
title: "分析enable_shared_from_this"
date: 2022-07-14T01:13:26+08:00
draft: false
# tags: [ "" ]
categories: [ "cpp"]
# keywords: [ ""]
# lastmod: 2022-07-14T01:13:26+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "b1767390"
toc: false
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

`std::shared_ptr`在以下情况下会触发未定义行为(double free)

```cpp
//错误用法
struct A
{
    std::shared_ptr<A> GetSharedPtr()
    {
        return std::make_shared<A>();
    }
}
std::shared_ptr<A> ptr1= std::make_shared<A>();
ptr2 = ptr1->GetSharedPtr();

//ptr2 and ptr1 will both free the object
```

由于`shared_ptr`是非侵入式的，所以被管理的对象内部不保存引用计数状态，也无法知道自己正在被`shared_ptr`管理。
这种用法返回的`shared_ptr`并不知道还有另外一个`shared_ptr`正在管理这个对象，导致一个对象关联了多个不同的引用计数器，导致多重释放。
 

要解决这个问题只有侵入对象本身,在对象内部关联引用计数器，使得在调用`GetSharedPtr`函数的时候通知正在管理自身的`SharedPtr`更新引用计数器。

## 源码剖析

代码剖析部分来自`EASTL`，相当干净的实现。

`enable_shared_from_this`相当简单，

```cpp
	template <typename T>
	class enable_shared_from_this
	{
	public: // This is public because the alternative fails on some compilers that we need to support.
		mutable weak_ptr<T> mWeakPtr;
	public:
		shared_ptr<T> shared_from_this()
			{ return shared_ptr<T>(mWeakPtr); }
		weak_ptr<T> weak_from_this()
			{ return mWeakPtr; }
        ...
        //other member functions
	}; // enable_shared_from_this
```
一个最简化的例子可以如下，它要求对象必须继承这个类，并且额外加入一个`mWeakPtr`成员。
这使得对象内部的`weak_ptr`与外部的`shared_ptr`关联上同一个引用计数器，在调用`shared_from_this`的时候能正常给引用计数加一。

使用该类必须有一个前提：
- 对象由`shared_ptr`管理，也就是对于栈上对象调用`shared_from_this`，或者是对裸指针调用`shared_from_this`会抛出异常

这是由于：
- `weak_ptr`单独存在时不能表示所有权，不允许在没有强引用的时候从`weak_ptr`提升到`shared_ptr`(目标可能已被free)
- 由于第一点原因的规定，一般的实现会在`std::shared_ptr`的构造函数利用SFAINE技术探测对象是否继承有`enable_shared_from_this`，只有在继承的时候才会初始化`mWeakPtr`，否则该指针会是一个未初始化的悬空值。


```cpp
    //in shared_ptr.h
	template <typename T, typename U>
	void do_enable_shared_from_this(const ref_count_sp* pRefCount,
	                                const enable_shared_from_this<T>* pEnableSharedFromThis,
	                                const U* pValue)
	{
		if (pEnableSharedFromThis)
			pEnableSharedFromThis->mWeakPtr.assign(const_cast<U*>(pValue), const_cast<ref_count_sp*>(pRefCount));
	}

	inline void do_enable_shared_from_this(const ref_count_sp*, ...) {} // Empty specialization. This no-op version is
	                                                                    // called by shared_ptr when shared_ptr's T type
	                                                                    // is anything but an enabled_shared_from_this
	                                                                    // class.
```

该函数调用时`do_enable_shared_from_this(pRefCount,T*,T*)`，当`T*`是`enable_shared_from_this`的子类时，此时第一个函数匹配上。
第一个参数为引用计数器的指针，此时给`mWeakPtr`复制上引用计数器和`T*`。
否则什么也不做，`mWeakPtr`保持悬空
