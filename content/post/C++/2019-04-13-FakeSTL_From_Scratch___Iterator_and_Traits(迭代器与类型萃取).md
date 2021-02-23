---
layout: post
cid: 452
title: "FakeSTL From Scratch | Iterator and Traits(迭代器与类型萃取)"
slug: 452-1
date: 2019-04-13
updated: 2019-04-13
status: publish
author: panda
categories: 
  - cpp
  - STL
tags: 
---



### Iterator
迭代器是STL特有的一个概念,翻译的比较绕口,更加通俗的翻译可以翻译成**游标**. 它提供一种统一和抽象的方式,使用迭代器可以用于访问和修改`STL`容器的每一个元素,而无需暴露`STL`容器的内部实现.
迭代器提供和指针一样的`dereference`和`member access`的功能,所有的迭代器都重载了`*`和`->`运算符,使他们工作的更像指针. 事实上,一般的`STL`实现里,`vector`容器的`iterator`就是`T*`.

在这里推荐一篇博客[带你深入理解STL之迭代器和Traits技法](https://zcheng.ren/sourcecodeanalysis/stliterator/#%E8%BF%AD%E4%BB%A3%E5%99%A8%E6%A6%82%E8%BF%B0).


<!--more-->


### Iterator与重载决议
下面讲一个工程问题,如何利用迭代器特性来帮助重载决议.

[C++模板函数的重载决议问题](https://www.blurredcode.com/2018/01/433.html).
```cpp
//construct 1
iterator insert( const_iterator pos, size_type n, const value_type &value ) 
//construct 2
template<typename InputIterator>
iterator insert( const_iterator pos, InputIterator first, InputIterator last ) 
```
当出现这样两个构造函数时,很明显,可以看到,当出现`insert(pos,5,10)`这样的函数调用时,`InputIterator`将会被构造成`int`,从而调用第二个构造函数,这是错误的.我们应该在构造函数中引入判断是否是`InputIterator`的代码.

```cpp
template <typename Iter>
using isInputIterator = typename std::enable_if<
std::is_convertible<typename iterator_traits<Iter>::iterator_category,
input_iterator_tag>::value>;
```
注意,这里代码里的`iterator_traits<Iter>`自己实现的话,**容易触发编译期错误.接下来看**

一个朴素的`iterator_traits<Iter>`的实现
```cpp
template <typename Iter>
struct iterator_traits
{
    typedef typename Iter::iterator_category iterator_category;
    typedef typename Iter::value_type value_type;
    typedef typename Iter::difference_type difference_type;
    typedef typename Iter::pointer pointer;
    typedef typename Iter::reference reference;
};
```
联想到之前谈到的,`insert(pos,5,10)`中,`InputIter`被推断成`int`,为了避免调用错误的函数,我们引入了`Iterator_traits<Iter>`来检验`InputIter`是否是迭代器.**错误出现在这里**,当我们传入`Iterator_traits<int>`,妄图获得它是不是一个迭代器的结果时,我们触发了编译期错误,因为在`Iterator_traits<int>`的内部,我们定义了
`typedef typename int::iterator_category iterator_category`,
而`int`并不具备`iterator_category`成员.我们会获得`int is not a class,struct or an union`的错误.

### Iterator_helper和SFINAE
`SFINAE`是一个简写的术语,**Substitution Failure Is Not An Error**.当模版参数在重载决议的实例化时候无效,该模版实例被移除重载决议,而不是抛出错误.
简单的来说
注:这一节主要参考于
[C++模板技术之SFINAE与enable_if的使用](https://izualzhy.cn/SFINAE-and-enable_if)

```cpp
struct test
{
  typedef int bar;
};
template <typename T>
void foo(typeame T::bar){}
template <typename T>
void foo(T){}

foo<test>(10); 
foo<double>(10.0); //will not throw an error
```
当`double`被构造的时候,不会因为没有定义`double::bar`而抛出编译错误.
由此,我们可以写一个`helper`函数,用于探测`T`是否含有`nested type`.
```cpp
struct false_type{const static bool bool_flag = false;};
struct true_type{const static bool bool_flag = true;};

template <typename U>
struct iterator_help {
    typedef void iterator;
};

template <typename T, typename = void>
struct has_typedef_iterator : false_type {}; //fallback

template <typename T>
struct has_typedef_iterator<T, typename iterator_help<typename T::iterator>::iterator > : true_type {};

struct foo {
    typedef float iterator;
};
has_typedef_iterator<foo>::bool_flag //true
has_typedef_iterator<int>::bool_flag //false
```
原理:当编译器在重载决议时, 当`T::iterator`成员存在时,模版2的匹配程度更高,而当`T::iterator`不存在时,模版2被编译器排除出重载决议,回到模版1.通过两个不同的继承,带上了不同的`bool_flag`.

------
现在通过帮助函数可以探测到`T::iterator`的存在了,所以回到最开始的问题,如果检测`T`是否是一个`iterator`,如果是,则萃取它的`iterator_category`,如果不是这个模版匹配失败,排除出重载决议.

接着上面的`has_typedef_iterator`的代码,我们可以利用模版的**偏特化**(*partial specialization*)来完善我们的`iterator traits`.
```cpp
template <class Iter,bool>
struct iterator_traits_helper {};

template <class Iter>
struct iterator_traits_helper<Iter,true>
{
typedef typename Iter::iterator_category iterator_category;
typedef typename Iter::value_type value_type;
typedef typename Iter::difference_type difference_type;
typedef typename Iter::pointer pointer;
typedef typename Iter::reference reference;
};

template <typename Iter>
struct iterator_traits : public iterator_traits_helper<Iter,has_typedef_iterator<Iter>::bool_flag>{};
```
我们定义一个默认的空的`iterator_traits_helper`,再偏特化一个真正的萃取器`iterator_traits_helper`.当我们调用`iterator_traits`时,我们利用`has_typedef_iterator`来检验它是否包含`iterator`这个`nested type`,如果是`int`,`iterator_traits`将继承一个空的`traits table`,从而在重载决议条件中的`enable_if`中失败,被排除出重载决议. 

> Written with [StackEdit](https://stackedit.io/).
