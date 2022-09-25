
---
title: "Monkey语言 | 1. Lexer & Parser"
date: 2022-09-14T21:52:05+08:00
draft: false
# tags: [ "" ]
categories: [ "pl"]
# keywords: [ ""]
# lastmod: 2022-09-14T21:52:05+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "85f52114"
toc: true 
mermaid: true 
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

最近在阅读[Writing An Interpreter In Go](https://interpreterbook.com/)。

![](https://interpreterbook.com/img/cover-cb2da3d1.png)

# Lexer

{{<mermaid>}}

graph LR
A[source] --> B[Lexer]
B--Tokens-->C[Parser]
C--Ast-->D[Evaluator]
D-->Value

{{</mermaid>}}

`Lexer`把原始的代码(包含空格、注释、换行符等额外的符号)转换为Parser关注的一连串的*词*，以方便解析器将一连串的Token转换为抽象语法树(AST)。

然而`Lexer/Parser`分离只是一种抽象方法，实际上并没有什么限制必须要分层制作。
一些简易的配置文件的Parser(比如ini,json)由于其语法足够简单，可以不经过Lexer阶段，从头到尾一次扫描得到解析结果。
然而这样混杂在一起会导致在Parser的代码里会有许多关于处理空格、换行符、注释以及循环读取标识符(identifier)等代码，并且在碰见错误的时候不方便提示错误信息(混在一起只能提供当前和之前字符的信息，而经过Lexer阶段可以报错当前和之前的Token，更加清晰)。

# Statement和Expression

- Statement: 语句，表示一个动作，比如赋值，返回一个值
- Expression: 表达式，通常会产生一个值。

一个程序`Program`往往由许多个语句组成，这些语句内部可能包含多个表达式。

在`Monkey`中`Statement`只有三种

- LetStatement

形如` let <identifier> = <expression>;`这样的语法, 比如` let x = 5 * 10;`。

- Return Statement
 
形如` return <expression>;`这样的语法,比如 `return (a + b);`

- ExpressionStatement

孤立的表达式，这种在脚本语言里比较多见。
比如Python

```py
>>> 5 + 10; # 分号可以省略， 这个句子产生了一个15的值
15
```
在rust里也可以写出类似的语句，无需显式写出`return`。

```rust
if true {
  1
} else {
  2
};
```

# 递归下降解析

`Monkey`的语法符合`LL(1)`，适合用递归下降法来解析。我在[BlurryLight/TinyJsonParser](https://github.com/BlurryLight/TinyJsonParser)作为`json parser`实现过递归下降解析器，但是json解析器由于没有算术运算，所以不用考虑运算符优先级的问题。

`LL(1)`的递归下降的一部分伪代码可以写作

```cpp
Node ParseExpression()
{
    while(GetToken(1))
    {
        switch (token):
        case "\"":  parseString();break;
        case "[":  parseArray();break;
        ...
    }
}
Node parseArray()
{
    while(GetToken(1) != "])
    {
        ParseExression();
        ...
    }
}
```

其解析过程中，`ParseExpression`和`ParseArray`可能会交替着递归调用，直到解析结束或者碰见出错的值。

比如对于`[[0],1,2]`代码片段中，
1. 首先调用ParseExpression,发现其为一个数组，调用ParseArray
2. 在ParseArray中调用ParseExpression解析第一个元素
3. 在ParseExpression中继续调用ParseArray
4. 在第2点执行的ParseArray中继续解析第二个元素，调用ParseNumber

## 普拉特解析法
普拉特解析法的完整实现可以参考[Pratt Parsers: Expression Parsing Made Easy ](https://journal.stuffwithstuff.com/2011/03/19/pratt-parsers-expression-parsing-made-easy/),其展示了 Prefix/Infix/Postfix，三目表达式以及括号情况下的解析方法。

普拉特解析法的关键思想在于，对于任意一个`Token`，视乎其出现的位置，只需要将其关联到`prefix`和`infix`不同的两个解析函数就可完成解析(后缀表达式可以视作缺失了`right`部分的中缀表达式)。

简单的例子。

```c
-5;  // 它应该调用PrefixParse
1 - 5; // 而这个 -号应该理解调用InfixParse
```


写成伪代码大致应当写作

```c
Map<Token,ParseFunc> PrefixMap;
Map<Token,ParseFunc> InfixMap;
Expression ParseExpression(curToken)
{
    // 从映射表里查找对应当前Token应当调用的函数
    var prefixFunc = PrefixMap[curToken];
    var left = prefixFunc();
    
    // 类似于 5 + 10；的语句，会先解析(5)表达式，然后发现下一个token '+' 是中缀符号
    // 把5 再传入进去，解析得到  (5 + 10) 表达式

    //再尝试着检测下一个字符是否是中缀表达式
    while(NextToken != Semicolon)
    {
        var infixFunc = infixMap[NextToken];
        ConsumeToken();
        left = infixFunc(left);
    }
    return left;
}
```

另外一个普拉特解析法的优点是其处理优先级相当方便，具体可以见[如何理解 Pratt Parser？](https://www.zhihu.com/question/413146859)。
简单的理解，可以认为每一个操作符具有一定的优先级，优先级代表了它的*吸力*，*吸力*越大的操作符会将周围的表达式黏着到一起。 


```c
1 + 2 * 3
```
由于`*`的优先级大于`+`号，这里解析出来的结果会是`1 + (2 * 3)`。

虽然每个语言的定义都不太一样，但是大致上不会违反直觉的优先级定义大致如下,函数调用的优先级总是最高的

```c#
    enum Priority : int
    {
        Lowest,
        Condition, //  a ? b : c
        Equals, // == 
        LessGreater, // > or <
        Sum, // + -
        Product, // *
        Prefix, // -x or !x
        Postfix, // a++, a--
        Call // a + func(b)
    }
```
## 右关联

**Note**: 通常编程语言中的运算符都是左关联的，意味着`1 + 2 + 3`会被解析成` (1 + 2) + 3`，而普拉特解析法中可以在解析的时候细微的控制*左吸力*和*右吸力*。

一个右结合的伪代码可以写作，这段代码会把`1 + 2 + 3`解析为`1 + (2 + 3)`，因为我们在解析第二个加号的时候可以降低了之前的加号的优先级，使得它的优先级低于第二个加号的优先级。

```c
Expression InfixParse(left)
{
    var exp = new InfixExp(...);
    exp.left = left;

    var priority = GetPriority(); // a + b + c； 假设现在解析到 第二个+号，上一个操作符的优先级为 Sum
    NextToken();
    exp.right = parseExp(priority - 1); // 降低第一个+号的优先级(降低它的吸力)
    return exp;
}
```

