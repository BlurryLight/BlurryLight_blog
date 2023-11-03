
---
title: "UE 降低编译线程数"
date: 2023-11-03T23:28:08+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "36d363d7"
toc: false
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

简单做个备忘。
与在公司不同，在家编译UE的时候通常会一边干其他事情一边等编译。
如果虚幻把所有线程都占满就没法干其他事情了(刷B站或者看其他代码都卡)。

# 编译CPP的线程控制

`BuildConfiguration.xml`可以控制UBT的一些行为，所以可以用来控制编译线程数。这个文件有几个不同目录，工程目录下的只会影响工程，而`C:\Users\<User>AppData\Roaming\Unreal Engine\UnrealBuildTool\BuildConfiguration.xml`目录下的会影响全局。

在家里没有xge其实只需要设置`LocalExecutor`就够了。
稍微解释下: 
- ProcessorCountMultiplier 默认值是1.0, 对于有超线程的CPU(主流CPU应该都有吧)，极限榨干性能可以设置为2，可以把整个CPU都打满，系统会很卡。反之降低就可以把CPU核占用给降下来。

```xml
<?xml version="1.0" encoding="utf-8" ?>
<Configuration xmlns="https://www.unrealengine.com/BuildConfiguration">

<BuildConfiguration>
    <bAllowXGE>false</bAllowXGE>
</BuildConfiguration>

<ParallelExecutor>
    <ProcessorCountMultiplier>0.8</ProcessorCountMultiplier>
    <MaxProcessorCount>7</MaxProcessorCount>
</ParallelExecutor>

<LocalExecutor>
    <ProcessorCountMultiplier>0.8</ProcessorCountMultiplier>
    <MaxProcessorCount>7</MaxProcessorCount>
</LocalExecutor>

</Configuration>
```

# 编译shader的线程控制

这个需要去`BaseEngine.ini`去找。同样有好几个层级，工程目录下也有，我的文档下也可以找到。
比较关键的是

```ini
[DevOptions.Shaders]
...
NumUnusedShaderCompilingThreads=3
; Make sure the game has enough cores available to maintain reasonable performance
NumUnusedShaderCompilingThreadsDuringGame=4
```

把这两个数字调大一点，尤其是第一个。越大预留的线程越多，ShaderCompiler调度的线程就越少。