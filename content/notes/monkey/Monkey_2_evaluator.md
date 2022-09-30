
---
title: "Monkey语言 | 2.evaluator"
date: 2022-09-26T00:09:52+08:00
draft: false
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


## 作用域，上值与闭包

在`Monkey`中也存在作用域的概念，比如如下的代码

在函数内部定义的变量`shadow`了外部的变量，在函数内部进行的变量定义不会修改外部变量的值。

```
let a = 0;
fn(){ let a  = 1; puts(a);}(); // a = 1
puts(a); // 0
```

为了实现这样的机制，我们需要定义一个`Environment`，本质上是一个字典，记录了每个`<VarName,MonkeyObj>`的映射关系。
比如`let a = 1`,就创建了一个`<"a",MonkeyInteger(1)>`的映射关系。


另外一个值得注意的就是`Monkey`中的函数可以捕获外部的变量
这是创造闭包的基础，被捕获的变量用`lua`的术语被称为上值。

其代码类似于
```
let sum = fn(x,y)
{
    return fn(y){ x + y;};
}

let sum_five = sum(5); // 返回了一个新的函数,这个函数捕获了外层函数的参数x
puts(sum_five(6)) // 实质上是 5 + 6
```


实现`Environment`可以大致类似于这样，当查找一个变量时首先从本层查找，无法从本层查找到变量时，再从外部查找。

```cs
public class Environment
{
    private Dictionary<string, IMonkeyObject> Bindings = null;
    public Environment? Outer;

    public IMonkeyObject? Get(string valName)
    {
        var value = Bindings.TryGetValue(valName, out var obj) ? obj : null;
        if (value == null && Outer != null)
        {
            value = Outer.Get(valName);
        }

        return value;
    }
}
```

还有一部分原版书里面没有考虑的，是`Monkey`里变量和数据结构都是不可变的。
也就是原版`Monkey`没有实现`AssignExpression`的求值。


我扩展了这部分的语法，大概表现为
```c
    let p = 0;
    let q = 1;
    let tmp = 0;
    while(i++ < n)
    {
        tmp = q;
        q = p + q;
        p = tmp;
    }
```

在`while`循环里修改tmp的值，会修改外部的值。
实现上类似于逐层向上递归寻找最近的Scope的值。

```cs
public IMonkeyObject TrySetBoundedVar(string valName, IMonkeyObject val)
{
    if (Bindings.ContainsKey(valName))
    {
        Bindings[valName] = val;
        return val;
    }

    if (Outer == null) return new MonkeyError($"Try to assign an unbound value {valName}");
    // 从本层往上逐层寻找最近的定义
    return Outer.TrySetBoundedVar(valName, val);
}
```
