
---
title: "Bind的简单实现剖析"
date: 2022-08-22T00:20:21+08:00
draft: false
# tags: [ "" ]
categories: [ "C++"]
# keywords: [ ""]
# lastmod: 2022-08-22T00:20:21+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "402a1cee"
toc: true
mermaid: true
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

本来想剖析下UE的Delegate的实现，想到一直想看下bind的实现就干脆看看bind的。
翻了下`EASTL`，发现其拒绝实现`bind`，因为lambda是bind的上位替换(见effective modern cpp item 34 [条款三十四：考虑lambda而非std::bind](https://github.com/CnTransGroup/EffectiveModernCppChinese/blob/master/src/6.LambdaExpressions/item34.md))。

又翻了下llvm的`libcxx`，标准库里的代码真的很难看懂。。
根据(https://gist.github.com/Redchards/c5be14c2998f1ca1d757)改了一个版本的bind实现。

```cpp
int foo(int a,int b,int c)
{
    return a + b + c;
}

auto func = bind(foo,1,2,std::placeholder::_1);

func(3); // return 1 + 2 + 3 = 6
```

就从这个gist开始吧。

# bind

简单的说，bind由于部分实参需要延迟绑定(通过占位符占位的实参)，所以需要保存构造`bind`对象时的参数列表，并在第二次调用的时候将占位符替换为实参并进行实际的调用。

{{<mermaid>}}
graph TD
A["bind(func,a,b,_1)"]-->B[UnresolvedArgsList_]
A-->C["operator(c)"]
C-->D[callee_list]
D--c-->E[替换_1为c]
B--a,b,_1-->E
E-->F["func(a,b,c)"]
{{</mermaid>}}

其代码大致流程如上。
当`bind`被调用时:

1. 参数列表被保存在`UnresolvedArgsList_`里，里面既包含实参，也包含占位符，返回一个`binder`对象
2. `binder->operator(args...)`被调用时，实参数被保存在`callee_list`里，并且根据占位符`_1`,`_2`的标志来从`callee_list`里取出对应的实参
3. 填充完所有形参后，执行实际的函数调用

注意，所有的计算**可以**均发生在**编译期**，也就是这些参数的保存之类的在运行期都是0开销，在编译结束的时候，bind的调用均被转换为实际的函数调用。

# callee_list

```cpp
class callee_list
{
public:
	template<class ... TArgs>
	constexpr callee_list(TArgs&&... args) noexcept
	: boundedArgs_{std::forward<TArgs>(args)...}
	{}

	template<class T>
	constexpr decltype(auto) operator[](T&& t) noexcept
	{
	  if constexpr (!std::is_placeholder_v<std::decay_t<T>>)
	  {
	  	return std::forward<T>(t);
	  }
	  else
	  {
	  constexpr size_t Index = std::is_placeholder<std::decay_t<T>>::value - 1;
	  return std::get<Index>(std::move(boundedArgs_));
	  }
	}

  // Bind以值类型存储所有变量，会擦除int& 到int
	std::tuple<typename std::decay_t<Args>...> boundedArgs_;	
};
```

`callee_list`将第二次调用的实参保存在一个`tuple`里(注意bind的参数会发生退化，如果需要使用引用需要使用`std::ref`)。

`callee_list`提供一个`operaotr[]`函数，这里使用了`if-constexpr`特性，根据传入的参数进行选择。

```c
callee_list[1] -> 1
callee_list[_1] -> 返回参数列表第一个值
```

# binder

```cpp
template<class Fn, class ... Args>
class binder
{
public:
	template<class TFn, class ... TArgs>
	constexpr binder(TFn&& f, TArgs&&... args) noexcept 
	: f_{std::forward<TFn>(f)},
	  UnresolvedArgsList_{std::forward<TArgs>(args)...}
	{}

	template<class ... CallArgs>
	constexpr decltype(auto) operator()(CallArgs&&... args) 
	{
		return call(std::make_index_sequence<sizeof...(Args)>{}, std::forward<CallArgs>(args)...);
	}
	
private:
	template<class ... CallArgs, size_t ... Seq>
	constexpr decltype(auto) call(std::index_sequence<Seq...>, CallArgs&&... args) 
	{
		// 创建callee_List保存调用Operator()时候传入的参数,用于补齐占位符
		auto calleeList = callee_list<CallArgs...>{std::forward<CallArgs>(args)...};

// 参数折叠展开 
//f_(calleeList[std::get<0>(UnresolvedArgsList_)],calleeList[std::get<1>(UnresolvedArgsList_)],calleeList[std::get<2>(UnresolvedArgsList_)],....)

		return f_(calleeList[std::get<index_constant<Seq>{}>(UnresolvedArgsList_)]...);
	}
private:
	std::function<std::remove_reference_t<std::remove_pointer_t<Fn>>> f_;
	// 将占位符以及原有的参数保存在UnResolvedArgsLists_里，在call的时候填充占位符
	std::tuple<typename std::decay_t<Args>...> UnresolvedArgsList_;
};
```

`binder`类返回一个仿函数对象，对这个functor的`operator()`调用才是实际的函数执行时机。
在创建`binder`的时候，比如如下

```cpp
void foobar(int a,int b)
{
    std::cout << "a + b: " << a + b << std::endl;
}

int a = 1;

auto fn = Bind(foobar,a,_1);
fn(2); // 1 + 2 = 3
```

第一次调用`Bind(foobar,a,_1)`的时候，内部的`UnresolvedArgsList_`保存了所有的参数，但是占位符的实际参数还没被确定，所以被命名为`unresolved`，此时``UnresolvedArgsList_ = (1,_1)`。
第二次`fn(2)`被调用的时候，创建了一个`calleeList = (2)`，并和之前的`UnresolvedArgsList`拼装，最后拼装成实际的函数调用`foobar(1,2)`。

# 变参模版和折叠表达式

具体的规则可以读cpprefence(https://en.cppreference.com/w/cpp/language/parameter_pack)和(https://en.cppreference.com/w/cpp/language/fold)。

比如以下的打印seq的函数满足cppreference中，折叠表达式的第一种形式`( pack op ... )`，其中`op`为`operator,`，
```cpp
template <size_t ... ints>
void print_seq(std::index_sequence<ints...> )
{
    ((std::cout << std::integral_constant<size_t, ints>{}<<' '),...);
// 展开为,逗号运算符为依次执行
//((std::cout << std::integral_constant<0>{}<<' '),(std::cout << std::integral_constant<1>{}<<' '))
    std::cout << std::endl;
}
```

另外也可以写成如下形式，其满足cppreference中，折叠表达式的第4种形式`( init op ... op pack )`,op为`operator<<`,
```cpp
template <size_t ... ints>
void print_seq(std::index_sequence<ints...> )
{
    (std::cout << ... << std::integral_constant<size_t, ints>{}) << std::endl;
}
```
展开为

```
std::cout <<std::integral_constant<size_t, 0>{}  << std::integral_constant<size_t, 1>{} << ... << std::endl
```

在bind的实现中用了函数参数展开,在保存的函数调用时展开所有的参数列表，并在这里替换所有的占位符为实际的参数列表。

```cpp
return f_(calleeList[std::get<index_constant<Seq>{}>(UnresolvedArgsList_)]...);
```

# 附录

代码位于gist
<script src="https://gist.github.com/BlurryLight/17c99bb9d6e02dab2f4865b5204d24a3.js"></script>