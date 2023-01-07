
---
title: "Monkey语言 | 3. 字节码与栈式VM"
date: 2023-01-07T17:05:30+08:00
draft: false
categories: [ "pl"]
isCJKLanguage: true
slug: "56b5a9fd"
toc: true 
mermaid: true 
fancybox: false
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

# 结构

{{<mermaid>}}
graph TD
A[Source Code]
B[AST]
C[Evaluator]
D[Result]
E[ByteCode]
F[Virtual Machine]

subgraph 前端
A--Lexer&Parser-->B
end

subgraph 后端
    B-->C
    B--Compiler-->E

    subgraph 解释器
        C-->D
    end

    subgraph 编译器
        E-->F
        F-->D
    end
end

{{</mermaid>}}

采用bytecode + VM的方案会比树上求值的解释器(tree-walking interp)更快。
因为最简单的tree-walker解释器本质上是在对一个比较深的树(AST)以递归的方式做后续遍历，不仅内存连续性不好，也不方便做一些很容易就能做的优化，比如常量消除，而且每走一步都需要将走到的Ast的节点转换为求值器内部的数据表示，需要不断的malloc/free。
而生成bytecode后，VM可以将所有的常量收集起来，采用索引的方式索引常量，并且bytecode是一段连续的字节，cache更友好。
一些更详细的讨论可以见
> 参考：[Chunks of Bytecode · Crafting Interpreters](https://craftinginterpreters.com/chunks-of-bytecode.html)

# 栈式VM

对于一个简单的表达式 `(1 + 2) * (2 + 3) `

其构成的AST类似于

{{<mermaid>}}
graph TD
A[operator*]
B[operator+]
C[1]
D[2]
B-->C
B-->D

E[2]
F[3]
G[operator+]

G-->E
G-->F

A-->G
A-->B
{{</mermaid>}}

`tree-walker`对它求值时需要按照**左->右->根**的方式进行求值，这是二叉树的后序遍历，其迭代实现可以基于栈实现。

贴一段解释器对于`InfixExpression`的出处理
```c#
case Ast.InfixExpression exp:
    {
        var left = Eval(exp.Left, env);
        if (left is MonkeyError) return left;
        IMonkeyObject right = MonkeyNull.NullObject;
        // 处理短路原则
        if (exp.Operator == "&&")
        {
            // 如果 (a && b)中a不合法，则b不会被执行
            if (!EvaluatorHelper.IsTrueObject(left))
                return EvalInfixExpression(exp.Operator, left, MonkeyNull.NullObject);
        }

        right = Eval(exp.Right, env);
        if (right is MonkeyError) return right;
        return EvalInfixExpression(exp.Operator, left, right);
    }
```

以上的表达式用栈实现可以表示为:
1. 压入左子树的`operator+`的左右子树和`operator+`,然后清栈，得到(1 + 2) = 3，往栈压入3
2. 压入右子树的`operator+`的左右子树和`operator+`,然后清栈，得到(2 + 3) = 5，往栈压入5
3. 压入operator*，清栈得到 (3 * 5) = 15,压入结果15
4. 栈顶元素为表达式的结果

# 字节码的表示

字节码是Compiler和VM的共同约定，Compiler把AST转换为字节码，VM读取字节码执行。
Monkey语言定义的字节码的格式为

```
opcode[char]   arg0[char/short/int] arg1[char/short/int] ...
```

每个字节码 起始的字节代表操作，后面跟随若干个参数。
每个字节码自身的字节，以及其拥有多少个参数，以及其每个参数的位宽，都需要定义在源码里，并且Compiler/VM都需要持有同一份定义，否则无法解释字节码。


字节码本身的序号可以通过枚举来自增，其自身的序号没有意义，只要是unique的就行。
```C#
public enum OpConstants : byte
{
    OpConstant,
    OpPop,
    ...
}
public static readonly Dictionary<Opcode, Definition> Definitions = new()
{
    {(Opcode) OpConstants.OpConstant, new Definition(OpConstants.OpConstant.ToString(), new List<int> {2})},
    ...
     {(Opcode) OpConstants.OpClosure, new Definition(OpConstants.OpClosure.ToString(), new List<int> {2, 1})},
```

以上的代码中，
- 定义了`OpConstant`字节码，其拥有`1`个`2`字节宽的参数
- 定义了`OpClosure`字节码，其拥有`2`个参数，第一个参数宽两个字节，第一个参数宽1个字节

所以当VM读取到`OpConstant`时，它应该明白整个指令宽3个字节，而`OpClosure`宽5个字节。

## 大小端问题的处理

对于Compiler而言，其需要把AST翻译为字节码。
Compiler执行的机器和VM执行的机器不必是一台机器(分发字节码)。
所以Compiler生成的字节码中，需要考虑字节序。

比如在小端序中将常量`65534`转换为两字节表示应该是`0xFFFE`，在小端序机器中，低位在前所以内存中是`0xFE 0xFF`,而大端序机器为`0xFF 0xFE`。
不同端序会造成错误，所以Compiler和VM需要约定好bytecode的端序问题，不应该受到本地机器的arch的影响。

