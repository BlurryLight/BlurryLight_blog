
---
title: "UE | Android AGDE 找不到Adb机器的问题"
date: 2026-05-23T12:20:39+08:00
draft: false
categories: ["UE"]
isCJKLanguage: true
slug: "5ae13e5c"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
# UEVersion: 5.3.2 
---

# 首次连接不上

这种情况大概率是因为本地存在多个不同版本的 `adb`。比如，`RenderDoc` 里通常自带一份 `adb`，`Android Studio` 里也会带一份，某些厂商工具，比如 `Snapdragon Profiler`，也可能额外提供一份 `adb`。

`adb` 对版本比较敏感，不同版本之间反复切换或连接，可能会导致设备一直处于断连状态。

建议把本地的 `adb` 统一到同一个版本，尽量避免多个来源混用。


# 第二次连接不上

这种情况通常出现在 `adb` 是通过 Wi-Fi 连接时，设备在下一次连接前更换了 `IP` 地址或端口。

![edit-d67efc8de28b40348766e2ae00ce3c45-2026-05-21-13-43-59](https://img.blurredcode.com/img/edit-d67efc8de28b40348766e2ae00ce3c45-2026-05-21-13-43-59.png?x-oss-process=style/compress)


首先要确认在 `adb` 下确实能看到目标设备，而且状态不是断开的。

另一个常见的 `AGDE` 问题是：上一次连接的是 `A` 机器，这一次想连接 `B` 机器，但 `AGDE` 仍然使用了上一次缓存的 `A` 机器 `IP` 地址，结果就连不上了。

这时可以删除以下文件，然后重新生成一个干净的工程，以彻底清理本地 `Visual Studio` 对ip地址的缓存：

- `UnrealProject\<ProjectName>\.vs`
- `UnrealProject\<ProjectName>\<ProjectName>.sln`
- `UnrealProject\<ProjectName>\Intermediate\ProjectFiles\*.vcxproj.user`
- `Engine\Intermediate\ProjectFiles\*.vcxproj.user`

重新打开工程后，通常就能恢复正常连接了。
