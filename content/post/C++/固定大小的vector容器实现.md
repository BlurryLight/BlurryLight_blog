
---
title: "限定长度的vector容器实现"
date: 2023-06-26T23:03:43+08:00
draft: false
categories: [ "cpp"]
isCJKLanguage: true
slug: "676d5850"
toc: true 
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

标准库一直缺少限定上限的vector实现，但是在实际一些场景里也还是有用的。
比如在图形API里，一些API能够绑定的数量是有上限的。

比如DX11的`OMSetRenderTargets`,

```cpp
void OMSetRenderTargets(
  [in]           UINT                   NumViews,
  [in, optional] ID3D11RenderTargetView * const *ppRenderTargetViews,
  [in, optional] ID3D11DepthStencilView *pDepthStencilView
);
```
其`NumViews`必须小于等于 `D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT`，一般而言等于8。
一个朴素的容器结构是

```cpp
template <typename T, size_t N>
struct limited_vector{
    T data[N];
    size_t Num;
};

limited_vector<ComPtr<ID3D11RenderTargetView>,D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT> rtvs;

// push rtvs into vector...

context->OmSetRenderTargets(rtvs.Num,rtvs.data,...);
```

然而，这样简单的容器无法限制`Num`必须小于`N`，这样当push超过`N`个元素时，`OMSetRenderTargets`就会超过限制。

# 现有的实现

这种能够限定长度的线性容器具有广泛的应用，所以也有充分的实现，包括一些提案也提议了这种容器。
- [static_vector 提案](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2018/p0843r2.html)
- [gnzlbg/static_vector,上面提案的实现](https://github.com/gnzlbg/static_vector)
- [boost static_vector](https://beta.boost.org/doc/libs/1_58_0/doc/html/boost/container/static_vector.html)

本质上来说这个容器并不复杂，想写的话基础功能百来行也写完了。它大概具有以下特点:

- 内存连续
- 有一个最大的上限
- 变长，需要有一个size()接口返回实际的长度
- 可以随机访问

引用一下boost的描述吧:

> A static_vector is a sequence that supports random access to elements, constant time insertion and removal of elements at the end, and linear time insertion and removal of elements at the beginning or in the middle. The number of elements in a static_vector may vary dynamically up to a fixed capacity because elements are stored within the object itself similarly to an array. However, objects are initialized as they are inserted into static_vector unlike C arrays or std::array which must construct all elements on instantiation. The behavior of static_vector enables the use of statically allocated elements in cases with complex object lifetime requirements that would otherwise not be trivially possible.

# 一些(我认为)不太好的实现方案

由于这个容器比较简单，所以打算自己动手写一下，不想引入第三方的代码(更别说boost了)。
所以也思考了几个方向去实现。

## 从0实现static_vector

类似于`gnzlbg/static_vector`的方案，重新仿造`vector`的接口重新造一个容器。

优点:
- 实现完全可控

缺点:
- 要达到stl-like的话，需要读很多遍cppreference，包括每个接口的异常处理，constexpr，以及allocator和iterator的处理

## 继承std::array / std::vector

继承自`std::array`的可以见[nvrhi/common/containers.h](https://github.com/NVIDIAGameWorks/nvrhi/blob/main/include/nvrhi/common/containers.h)。
继承自`vector`的可以见[EASTL/fixed_vector.h](https://github.com/electronicarts/EASTL/blob/master/include/EASTL/fixed_vector.h)

这个方案实现差不多，继承`std::array`的话，需要添加`push_back`方法，以及重写迭代器。
而继承`std::vector`的话，需要在`push_back/emplace_back`，以及`copy`等一堆方法里检查上限。

优点:
- 工作量小
- 继承自`std::array`可以用栈的内存
- 用私有继承的话可以控制暴露哪些接口

缺点:
- 要实现完整的特性，也要做一些脏活累活。比如[nvrhi/common/containers.h](https://github.com/NVIDIAGameWorks/nvrhi/blob/main/include/nvrhi/common/containers.h)继承自`std::array`，但是没有实现`reverse iterator`


# 从Allocator着手

这个思路是从UE里来的。

```cpp
TArray<T, TFixedAllocator<12> > Items;
```

把主意打到了`std::pmr::mononic_buffer_resource`上,大概想这样


```cpp
std::array<std::byte, sizeof(int) * 32> buffer; // fixed 32 int
std::pmr::monotonic_buffer_resource mbr{buffer.data(), buffer.size(),std::null_memory_resource()};
std::pmr::polymorphic_allocator<int> pa{&mbr};
std::pmr::vector<int> vector{pa};
```
当`mbr`分配超过其容量的内存时，会走到`null_memory_resource`，而`null_memory_resource`会抛出`bad_alloc`异常。
但是很快我就意识到这个思路不对，因为`vector`本身也要占据一定的内存空间(需要存储指针，allocator以及size)。
并且vector的扩容算法是实现定义的，没法精确计算出一个`pmr::vector`真正占用多少空间。


回过头来，发现`vector`的长度受`vector.max_size()`限制，而`vector.max_size()`会受到`Allocator`的限制(具体和Allocator_traits有关，不仔细讲了)。



```cpp
template <class T, size_t N> struct limited_allocator : std::allocator<T> {
  using value_type = typename std::allocator<T>::value_type;
  using size_type = typename std::allocator<T>::size_type;
  size_type max_size() const noexcept { return N; }
  template <class Other> struct rebind {
    typedef limited_allocator<Other, N> other;
  };

  // make msvc happy
  template <class Other, size_t M> constexpr operator limited_allocator<Other, M>() const noexcept {
    return limited_allocator<Other, M>();
  }
};

template <class T, size_t N> using limited_vector = std::vector<T, limited_allocator<T, N>>;


limited_vector<int,1> vec{};
vec.push_back(1);
vec.push_back(2); // throw std::length_error
```

测试可以见 https://godbolt.org/z/84GGaeoWq


这个方法的特点是:

优点:
- 对代码的改动量比较小
- 越界抛异常，不会像UE一样直接把栈踩坏
- 拥有vector的全部特性

缺点:
- 分配在堆上(想要在栈上可以靠自己实现Allocator，或者用pmr容器+`memory_resource`，但是有点麻烦)


# Reference

如果想要分配在栈上可以使用pmr版本的实现，但是需要自己管理`memory_resource`

<script src="https://gist.github.com/BlurryLight/393c07f8c5965ccd31014b2f36e9da57.js"></script>