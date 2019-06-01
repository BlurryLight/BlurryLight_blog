---
layout: post
cid: 450
title: "FakeSTL From Scratch | 编写Allocator"
slug: 450
date: 2019-04-05
updated: 2019-04-06
status: publish
author: panda
categories: 
  - C++
  - STL
tags: 
---


`Allocator`模版是所有 标准库容器里默认的内存分配器。在实现容器前，首先要实现`Allocator`以管理容器的内存。文中涉及到的函数标准一律以`C11`为准。


<!--more-->


### Allocator的要求
根据[cppreference :: std::Allocator](https://en.cppreference.com/w/cpp/memory/allocator)，一个最简单的`Allocator`应当具备如下成员。  

|类型                                    |定义|
|--|--|
|value_type  |T  |
|pointer  |T*  |
|const_pointer  |const T*  |
|reference  |T&  |
|const_reference  |const T&  |
|difference_type  |std::ptrdiff_t  |
|size_type  |std::size_t  |

同时具备以下的成员函数
```cpp
template<  class U > 
struct rebind {  typedef allocator<U> other;  }

Allocator() = default;
Allocator(const Allocator& other);
template <typename U>
Allocator(const Allocator<U> &d);
~Allocator();
pointer allocate( size_type n, const  void  * hint =  0  );
void deallocate( T* p, std::size_t n); //n必须等于allocate的n
void construct( pointer p, const_reference val );
void destroy( pointer p );
```

### 一个简单的Allocator的实现（通过调用`operator new`和`operator delete`）

这里主要是调用了`operator new`和`operator delete`。关于具体的解释可以查看`cpp primer`第五版的第19.1节<控制内存分配>。简单的说，cpp里的`new`操作符包含两步，第一步被称为`operator new`，向系统申请一块内存，类似于`malloc`，第二步是`placement new`，调用对象的构造函数并将对象放置在申请的内存上。与之对应的逆过程，就是`delete`的析构，并销毁内存。
可以清楚的看到，`new`和`delete`的行为，恰好对应着`Allocator`类的`allocate`,`construct`,`deallocate`,`destroy`的四个函数，因此一个最简单的`Allocator`可以由`new`和`delete`封装而成。如果有更高级的需求，`CPP`也提供了重载`operator new`和`operator delete`的方法，可以通过重载函数来满足需求，但是我们只能对`operator new`和`operator delete`进行重载，而不能重载`new`和`delete`的行为。

```cpp
template <typename _T> 
class Allocator
{

public:
    typedef _T              value_type;
    typedef _T*             pointer;
    typedef const _T*       const_pointer;
    typedef _T&             reference;
    typedef const _T&       const_reference;
    typedef std::size_t     size_type; //<cstddef>
    typedef std::ptrdiff_t  difference_type;
    Allocator() = default;
    //rebind和copy constrcutor必须存在。
    //显式禁用移动构造函数，因为Allocator不存在移动构造这种操作
    Allocator (Allocator&& other) = delete;
    Allocator( const Allocator& other) : Allocator(){}
    template <typename _U>
    Allocator(const Allocator<_U> &d) : Allocator() {}

	//rebind主要用于派生出其他类型的Allocator.
	//比如从LinkedList<T,Allocator<T>>从，派生出Allocator<Node<T>>来分配内存
    template <typename _U>
    struct rebind
    {
        typedef Allocator<_U> other;
    };

    template <typename _U>
    bool operator==(const Allocator<_U>&) const
    {
        return true;
    }
    template <typename _U>
    bool operator!=(const Allocator<_U>&) const
    {
        return false;
    }

    pointer allocate()
    {
        return static_cast<_T*>(::operator new(sizeof (_T)));
    }
    pointer allocate(size_type n ,const void* hint = 0) //hint is just a flag,useless
    {
        if( hint || n <= 0)
//            throw std::bad_alloc();
            return nullptr;
        return static_cast<_T*>(::operator new(n * sizeof (_T)));
    }

    void deallocate(pointer p)
    {
        if( p == nullptr)
            return;
        ::operator delete(p);
    }
    void deallocate(pointer p,size_type /*flag*/)
    {
        if( p == nullptr)
            return;
        ::operator delete(p);
    }

    void construct(pointer p,const_reference val)
    {
        new(p)_T(val);
    }
    void destroy(pointer p)
    {
        p->~_T();
    }
};
```

### 一个带链表回收的Allocator
这个版本不是我写的，来源[plalloc: A simple stateful allocator for node based containers](https://probablydance.com/2014/11/09/plalloc-a-simple-stateful-allocator-for-node-based-containers/)。`License`允许`copy`，所以我把他的代码贴在下面，进行分析。
```cpp
#pragma once
 
#include <memory>
#include <vector>
 
template<typename T>
struct plalloc
{
    typedef T value_type;
 
    plalloc() = default;
    template<typename U>
    plalloc(const plalloc<U> &) {}
    plalloc(const plalloc &) {}
    plalloc & operator=(const plalloc &) { return *this; }
    plalloc(plalloc &&) = default;
    plalloc & operator=(plalloc &&) = default;
 
    typedef std::true_type propagate_on_container_copy_assignment;
    typedef std::true_type propagate_on_container_move_assignment;
    typedef std::true_type propagate_on_container_swap;
 
    bool operator==(const plalloc & other) const
    {
        return this == &other;
    }
    bool operator!=(const plalloc & other) const
    {
        return !(*this == other);
    }
 
    T * allocate(size_t num_to_allocate)
    {
        if (num_to_allocate != 1)
        {
            return static_cast<T *>(::operator new(sizeof(T) * num_to_allocate));
        }
        else if (available.empty())
        {
            // first allocate 8, then double whenever
            // we run out of memory
            size_t to_allocate = 8 << memory.size();
            available.reserve(to_allocate);
            std::unique_ptr<value_holder[]> allocated(new value_holder[to_allocate]);
            value_holder * first_new = allocated.get();
            memory.emplace_back(std::move(allocated));
            size_t to_return = to_allocate - 1;
            for (size_t i = 0; i < to_return; ++i)
            {
                available.push_back(std::addressof(first_new[i].value));
            }
            return std::addressof(first_new[to_return].value);
        }
        else
        {
            T * result = available.back();
            available.pop_back();
            return result;
        }
    }
    void deallocate(T * ptr, size_t num_to_free)
    {
        if (num_to_free == 1)
        {
            available.push_back(ptr);
        }
        else
        {
            ::operator delete(ptr);
        }
    }
 
    // boilerplate that shouldn't be needed, except
    // libstdc++ doesn't use allocator_traits yet
    template<typename U>
    struct rebind
    {
        typedef plalloc<U> other;
    };
    typedef T * pointer;
    typedef const T * const_pointer;
    typedef T & reference;
    typedef const T & const_reference;
    template<typename U, typename... Args>
    void construct(U * object, Args &&... args)
    {
        new (object) U(std::forward<Args>(args)...);
    }
    template<typename U, typename... Args>
    void construct(const U * object, Args &&... args) = delete;
    template<typename U>
    void destroy(U * object)
    {
        object->~U();
    }
 
private:
    union value_holder
    {
        value_holder() {}
        ~value_holder() {}
        T value;
    };
 
    std::vector<std::unique_ptr<value_holder[]>> memory;
    std::vector<T *> available;
};
```

(吐槽一下他在`Allocator`里调用`std::vector`，不过提高了代码可读性。）
核心的变动在于
1. 分配成块内存时，和前述`Allocator`表现一致，通过`new`和`delete`分配和销毁内存，不复用。
2. 在Allocate函数分配单个元素时，利用`std::vector<std::unique_ptr> `来掌握分配的内存，避免了手动调用`new`和`delete`，`Allocator`析构时，会自动析构`unique_ptr`掌握的内存。
3. 在`deallocate`的函数销毁单个元素时候，不`delete`内存，而是将地址回收到`std::vector<T*> avaliable`里，这里是一个用`vector`形式表示的链表，下一次分配单个元素时，可以直接覆盖元素。

### 内存池版本带回收的Allocator
我的`FakeSTL`里带一个内存池版本的[PDSTL/src/allocator_mempool.h](https://github.com/BlurryLight/PDSTL/blob/master/src/allocator_mempool.h)。

内存池分配一般通过先分配一段内存，称为`buffer`。在`buffer`中记载指向下一段`buffer`的指针，然后将`buffer`所占用的内存，划分成一个一个的`block`，每一个`block`可以存放一个元素，还需要记载一个序号，记录已经使用了多少个`block`。

与上一个带回收的`Allocator`相比，我在`deallocate`的时候不论是单个元素还是整块内存，都回收到`blockfree`链表里，在分配的时候，同时分配多个元素时不从链表分配而是从池子分配，因为同时分配多个元素时通常要求元素连续，而通过链表回收的内存通常不满足这个要求。而在分配单个元素时优先从链表分配，最大实现对内存的复用。
