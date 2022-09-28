
---
title: "Monkey_2_evaluator"
date: 2022-09-26T00:09:52+08:00
draft: true
# tags: [ "" ]
categories: [ "pl"]
# keywords: [ ""]
# lastmod: 2022-09-26T00:09:52+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "e6a47ab4"
toc: true
mermaid: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


{{% spoiler "笔记栏文章声明"%}} 
    {{% notice warning %}}
    笔记栏所记录文章往往未经校对，或包含错误认识或偏颇观点，亦或采用只有自身能够理解的记录。
    {{% /notice %}}
{{% /spoiler %}}


# 树遍历求值

求值，也就是解释器的后端，有许多优化方法。
但是这里实现的是最简单、最慢的递归AST求值的方法。
从AST的Root出发，应该算是`DFS`？
假设一段伪代码

```
    <aaaaa>;
    <bbbbb>;
```
那么先要递归求值完毕`<aaaaa>`中的所有表达式，得到这一句的结果后才能进一步求值`<bbbbb>`语句。

更进一步用伪代码展示，其核心入口为一个`Eval`函数，根据碰见不同的`Ast`节点采取不同的求值。

```c
var Eval(astNode)
{
    switch(node)
    {
        case Ast.IntegerLiteral node:
            return node.Value;
        case Ast.PrefixExpression node: // <op><right>
            var right = Eval(node.right);
            return EvalPrefix(node.op,right);
        case Ast.FunctionLiteral:
            ...
        case Ast.InfixExpression :
            ...
        case Ast.LetStatement:
            ...
    }
}
```
最简单的求值是整数字面量，可以直接返回值。
一个`Eval(Ast.Integer{Token:"5"}) => 5`就完成了从一个`AstNode`到`Int(5)`。
然而这已经完成了从一个Ast的节点表示，到宿主语言的真正的值。
## 对象系统

在解释器中，负责执行解释器的语言被称为宿主语言。
是否要在脚本语言中，暴露宿主语言的原始数据结构是一种设计考量。
一种简单的方法是将所有脚本语言的值都用`Object`封装起来，他们继承于一个公共的祖先。

许多非Native的语言里都可以看到这种设计，比如`Python`，`Lua`，乃至`Java`之类的，在C++中亦可以做出相关设计。
比如UE的所有受引擎管理的对象都继承于UObject。

继承于同一个Object有一些比较好的好处:
- 方便实现GC，无论是引用计数还是更复杂的Mark-Sweep,最基本的tracing功能可以实现在最基础的Object
- 可以方便把所有的对象装进宿主语言的同构容器里，比如C++的`std::vector<MonkeyObject>`

也会有一些缺点:
- Object设计的越复杂，脚本语言里每个对象的占用的内存越大。
- 在一些可以用原生数据表示的数据类型中，会引入额外的开销。比如int,float,bool，用Object包一层会引入额外的开销


比如在`Monkey`中，一个`MonkeyInteger`可以用`C#`语言表示成如下

```cs
    public interface IMonkeyObject
    {
        ObjectType Type();
        string Inspect(); // for debug
    }
    public class MonkeyInteger : IMonkeyObject
    {
        public Int64 Value;
    }
```
 
这里这么清爽是因为我所采用的`C#`作为宿主语言，由于C#是一个GC语言，我们不用手动实现GC，其复杂度被C#自带的GC掩盖了。
否则可能需要在Object里记录额外的数据以实现反射和GC，反射是因为当我们拿到一个`IMonkeyObject`时我们需要知道它的确切类型以转型到`MonkeyInteger`。


TODO:
## 作用域，上值与闭包
(词法定界)
## 内建函数与数据结构
(可变与不可变)