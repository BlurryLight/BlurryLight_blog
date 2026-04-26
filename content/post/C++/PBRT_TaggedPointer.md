
---
title: "PBRT: Tagged Pointer模拟多态"
date: 2026-04-26T15:06:04+08:00
draft: false
categories: [ "cpp"]
isCJKLanguage: true
slug: "d900c760"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


[TOC]

# 必要性

在GPU Kernel上要支持虚函数有若干限制：
1. 对象必须构造到GPU上，不能跨越host/device边界调用函数（在global/device scope内通过new构造，不能在host构造然后cudamemcpy上去）
2. 链接的时候跨cu链接虚函数很麻烦

Tagged Pointer：现代体系架构里，指针只用了48位，5级页表只能用40位

目前的体系架构里，高7位是空着的（但可能被其他硬件功能占用，比如HWASAN）。这些空着的比特位可以用来标记类型信息，但支持的类型数量有限制。

![PBRT_TaggedPointer-2026-04-26-15-07-13](https://img.blurredcode.com/img/PBRT_TaggedPointer-2026-04-26-15-07-13.png?x-oss-process=style/compress)

# 用法

```cpp

// Primitive Definition
class Primitive
    : public TaggedPointer<SimplePrimitive, GeometricPrimitive, TransformedPrimitive,
                           AnimatedPrimitive, BVHAggregate, KdTreeAggregate> {
  public:
    // 继承TaggedPointer的默认构造函数
    using TaggedPointer::TaggedPointer;

    Bounds3f Bounds() const;

    pstd::optional<ShapeIntersection> Intersect(const Ray &r,
                                                Float tMax = Infinity) const;
    bool IntersectP(const Ray &r, Float tMax = Infinity) const;
};

Bounds3f Primitive::Bounds() const {
    auto bounds = [&](auto ptr) { return ptr->Bounds(); };
    return DispatchCPU(bounds);
}

Primitive Handle(new Sphere());
Primitive.Bounds(); // dispatch to Spherer::Bounds()
```



缺点：
- 仅支持64位系统，借用了指针的高7位，最多支持127种类型（0被nullptr占用，tagged pointer未初始化占用1个）
- 不允许动态扩展类型，每次添加新的子类型都需要更新父类型的tag列表


## 实现

PBRT内的实现略复杂一些：
- 需要同时兼容CPU / CUDA（__device/__host__/__global__），GPU分支的返回值需要从类型模板指定，CPU的返回值类型可以直接用decltype(auto)推导
- 另外出于编译性能考虑，采用了一些优化技巧（每层模板可用switch匹配8个类型，如果未匹配到则递归匹配下一个8个类型）

实际上单独将代码抽出来、不考虑GPU的情况下，用`if constexpr`来写其实是相当简洁易懂的。

详细的测试代码可参见 https://github.com/BlurryLight/recipe/blob/master/cpp_examples/tagged_pointer/main.cc

```cpp
template <typename>
inline constexpr bool always_false_v = false;

template <typename T, typename First, typename... Rest>
constexpr int TypeIndex() {
    if constexpr (std::is_same_v<T, First>) {
        return 0;
    } else if constexpr (sizeof...(Rest) > 0) {
        return 1 + TypeIndex<T, Rest...>();
    } else {
        static_assert(always_false_v<T>, "Type is not in TaggedPointer type list");
    }
}

template <typename F, typename T, typename... Rest>
decltype(auto) DispatchCPU(F &&func, void *ptr, int index) {
    if (index == 0)
        return std::forward<F>(func)(static_cast<T *>(ptr));

    if constexpr (sizeof...(Rest) > 0) {
        return DispatchCPU<F, Rest...>(std::forward<F>(func), ptr, index - 1);
    } else {
        assert(false && "Invalid tag index");
        return std::forward<F>(func)(static_cast<T *>(ptr));
    }
}

template <typename F, typename T, typename... Rest>
decltype(auto) DispatchCPU(F &&func, const void *ptr, int index) {
    if (index == 0)
        return std::forward<F>(func)(static_cast<const T *>(ptr));

    if constexpr (sizeof...(Rest) > 0) {
        return DispatchCPU<F, Rest...>(std::forward<F>(func), ptr, index - 1);
    } else {
        assert(false && "Invalid tag index");
        return std::forward<F>(func)(static_cast<const T *>(ptr));
    }
}

template <typename... Ts>
class TaggedPointer {
  private:
    static constexpr int tagShift = 57;
    static constexpr int tagBits = 64 - tagShift;
    static constexpr uint64_t tagMask = ((uint64_t{1} << tagBits) - 1) << tagShift;
    static constexpr uint64_t ptrMask = ~tagMask;

  public:
    static_assert(sizeof(uintptr_t) <= sizeof(uint64_t));
    static_assert(sizeof...(Ts) < (1u << tagBits), "Too many tagged pointer types");

    TaggedPointer() = default;
    TaggedPointer(std::nullptr_t) {}

    template <typename T>
    explicit TaggedPointer(T *ptr) {
        set(ptr);
    }

    template <typename T>
    void set(T *ptr) {
        const auto iptr = reinterpret_cast<uint64_t>(ptr);
        assert((iptr & ptrMask) == iptr && "Pointer uses bits reserved for tag");

        const auto typeTag = static_cast<uint64_t>(type_index<T>());
        bits_ = iptr | (typeTag << tagShift);
    }

    template <typename T>
    static constexpr int type_index() {
        return 1 + TypeIndex<std::remove_cv_t<T>, Ts...>();
    }

    static constexpr int max_tag() { return sizeof...(Ts); }
    static constexpr int num_tags() { return max_tag() + 1; }

    int tag() const { return static_cast<int>((bits_ & tagMask) >> tagShift); }
    void *ptr() { return reinterpret_cast<void *>(bits_ & ptrMask); }
    const void *ptr() const { return reinterpret_cast<const void *>(bits_ & ptrMask); }

    explicit operator bool() const { return ptr() != nullptr; }

    template <typename T>
    bool is() const {
        return tag() == type_index<T>();
    }

    template <typename T>
    T *cast() {
        assert(is<T>());
        return static_cast<T *>(ptr());
    }

    template <typename T>
    const T *cast() const {
        assert(is<T>());
        return static_cast<const T *>(ptr());
    }

    template <typename T>
    T *cast_or_nullptr() {
        return is<T>() ? static_cast<T *>(ptr()) : nullptr;
    }

    template <typename T>
    const T *cast_or_nullptr() const {
        return is<T>() ? static_cast<const T *>(ptr()) : nullptr;
    }

    template <typename F>
    decltype(auto) dispatch(F &&func) {
        assert(ptr() != nullptr);
        return DispatchCPU<F, Ts...>(std::forward<F>(func), ptr(), tag() - 1);
    }

    template <typename F>
    decltype(auto) dispatch(F &&func) const {
        assert(ptr() != nullptr);
        return DispatchCPU<F, Ts...>(std::forward<F>(func), ptr(), tag() - 1);
    }

  private:
    uint64_t bits_ = 0;
};
```