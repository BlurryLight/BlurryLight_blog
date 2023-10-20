
---
title: "用Unreal Insights 查看UE Cooking过程"
date: 2023-10-20T21:16:51+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "85fda58f"
toc: false
mermaid: false
fancybox: true 
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


`Cooking Profiling`可以用来查打包过程中Cooking打包过程为什么慢的问题。
可以用Unreal Insights来看。

{{<fancybox URL="https://img.blurredcode.com/img/UE-Cooking-profiling-2023-10-20-21-19-14.png?x-oss-process=style/compress" Caption="Cooking Insights(引用自Ken Kuwano" >}}

官方虽然有一个文档，但是写的不清不楚的，一直没弄明白该怎么跑起来。
> 参考：[Unreal Cooking Insights in Unreal Engine 5 | Unreal Engine 5.2 Documentation](https://docs.unrealengine.com/5.2/en-US/unreal-cooking-insights-in-unreal-engine-5/)

摸索了一下，参考了Unreal Japan的一篇文章[^1]，才弄明白: 
**在Editor下Cook是没办法看到Cooking Insights的，需要从命令行拉起UnrealEditor-cmd.exe来Cook资源**

# 参考脚本

1. 先打开UnrealInsights, `UE4Editor-Cmd.exe`拉起来的时候会反向链接UnrealInsights
2. 按照下面的脚本拉起命令行编辑器来Cook资源，对应路径需要自己调整

UE4
```bat
set ENGINE_PATH="D:\Release-4.27\Engine\Binaries\Win64\UE4Editor-Cmd.exe"
set PROJECT_PATH="D:\Projects\ShooterGame\ShooterGame.uproject"
set COMMAND=-tracehost=localhost -trace=cpu,cook,loadtime,savetime,log -ini:Engine:[ConsoleVariables]:cook.displaymode=2 -statnamedevents
%ENGINE_PATH% %PROJECT_PATH% -run=cook -targetplatform=WindowsNoEditor %COMMAND%
```

UE5主要是 targetplatform 有点不同。

UE5

```bat
set ENGINE_PATH="<UEEditor-CMD.exe>"
set PROJECT_PATH="D:\Projects\ShooterGame\ShooterGame.uproject"
set COMMAND=-tracehost=localhost -trace=cpu,cook,loadtime,savetime,log -ini:Engine:[ConsoleVariables]:cook.displaymode=2 -statnamedevents
%ENGINE_PATH% %PROJECT_PATH% -run=cook -targetplatform=Windows %COMMAND%
```


# Reference

[^1]: [[UE4] Unreal InsightsによるCookプロファイル (Cook Trace) #UE4 - Qiita](https://qiita.com/EGJ-Ken_Kuwano/items/359e82a4780cfdca2844)
