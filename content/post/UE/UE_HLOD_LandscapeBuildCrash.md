
---
title: "UE | HLOD 绕开Landscape Build Crash"
date: 2025-06-14T21:03:13+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "309c585a"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
UEVersion: 5.3.2 
---


这是一个在5.3.2上碰到的问题，不清楚更新一点的引擎还会不会有。
Build HLOD中如果Landscape参与了Build那么可能会出现 Build中断崩溃的情况。

这个在UDN上也能翻到对应的其他人的提问，
https://udn.unrealengine.com/s/question/0D54z00009dZSD3CAO/engine-crashing-when-trying-to-build-hlods-in-53

崩溃的堆栈类似如下，主要是崩溃在`ALandscapeProxy::ExportToRawMeshDataCopyNew()`

```
[2023.09.18-00.39.57:482][222]LogWindows: Windows GetLastError: The operation completed successfully. (0)
[2023.09.18-00.40.04:668][222]LogWindows: Error: === Critical error: ===
[2023.09.18-00.40.04:668][222]LogWindows: Error: 
[2023.09.18-00.40.04:668][222]LogWindows: Error: Assertion failed: Pair != nullptr [File:D:\build\++UE5\Sync\Engine\Source\Runtime\Core\Public\Containers\Map.h] [Line: 671] 
[2023.09.18-00.40.04:668][222]LogWindows: Error: 
[2023.09.18-00.40.04:668][222]LogWindows: Error: 
[2023.09.18-00.40.04:668][222]LogWindows: Error: 
[2023.09.18-00.40.04:668][222]LogWindows: Error: [Callstack] 0x00007ff906e89cae UnrealEditor-Landscape.dll!ALandscapeProxy::ExportToRawMeshDataCopyNew() [D:\build\++UE5\Sync\Engine\Source\Runtime\Landscape\Private\LandscapeEdit.cpp:4187]
[2023.09.18-00.40.04:668][222]LogWindows: Error: [Callstack] 0x00007ff906e861ce UnrealEditor-Landscape.dll!ALandscapeProxy::ExportToRawMesh() [D:\build\++UE5\Sync\Engine\Source\Runtime\Landscape\Private\LandscapeEdit.cpp:3846]
[2023.09.18-00.40.04:668][222]LogWindows: Error: [Callstack] 0x00007ff906fb6872 UnrealEditor-Landscape.dll!ULandscapeHLODBuilder::Build() 
```

经过我在git的历史里刨了半天以后，翻到一个可能修复了这个问题的提交，这个提交把`ALandscapeProxy::ExportToRawMeshDataCopyNew()`这个函数都给干没了。

Potential Fix: https://github.com/EpicGames/UnrealEngine/commit/b9b8d9517582d95f3693ad68dd3cfd1cb9417124


另外一个解决这个问题的方案是把设置 `landscape.nanite.marchingsquaresvisibility = 0`，可以绕开这个问题。