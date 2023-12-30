
---
title: "我的2023: Unreal的一年"
date: 2023-12-30T13:52:57+08:00
draft: false
categories: [ "misc"]
isCJKLanguage: true
slug: "3e54c858"
toc: false
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

在2022的灰色基调后面，今年总算是多了一点鲜艳的颜色。

今年最大的改变也许是口罩令终于结束了。我在2022年12月的上半旬随着口罩令的解除也随着大军中招了，好在家里药箱里倒是有之前留下来的对乙酰氨基酚和布洛芬，还有一些缓解咽喉疼痛的含片。症状最明显的两三天基本上是躺在床上靠点外卖过活，然后每隔六七个小时准时开始起高热，这个时候就开始狠狠嗑药。过了两三天总算是满血复活了。


# 聊聊目标

![](https://img.blurredcode.com/img/我的2023-Unreal的一年-2023-12-30-14-02-05.png?x-oss-process=style/compress)

苟住工作这一条既算是失败又是成功了吧..尽管一度通过活水逃过了一次裁员，最后还是没能逃过降本增效，领了大礼包离开了腾讯。不过好在基本无缝衔接了下一份工作，来到了完美。并且从另一种角度来看也算是大成功中的大成功，因为家庭的原因我一直在思考从上海or深圳换工作地点到成都的事情。趁着这次机会也是成功换到了成都工作，彻底完成了这个小目标。

保持健身这一条只能说成功了一部分，我确实一直有在健身，体重从80+公斤降到了77左右，并且维持了较好的身体健康(今年完全没有生病过)，但是离预期的肌肉男还差得远，再接再厉。

讲好英语这条没做好，明年继续努力吧！

博客120篇的话完成了一部分吧，今年大概写了20+篇左右，离30篇的目标还有点距离。主要是工作里面有些内容和项目有关，不适合单独拆出来作为分享。业余时间在做的东西有一阵没一阵的。

今年比较满意的一点还是做了一些开源贡献。
给Puerts合进去了几个Commit:

- [TArray.Add() 变参函数](https://github.com/Tencent/puerts/pull/1513)
- [容器添加[Symbol.iterator]支持](https://github.com/Tencent/puerts/pull/1555)
- [Free POD UStruct on Worker Thread](https://github.com/Tencent/puerts/pull/1576)

给Nvidia的nvrhi也抓了一些虫

- [wrong calculation for vulkan buffer 4-byte alignment in vkCmdUpdateBuffer](https://github.com/NVIDIAGameWorks/nvrhi/issues/38)
- [VertexBufferBinding slot seems not work](https://github.com/NVIDIAGameWorks/nvrhi/pull/35)

## 2024的小目标

- 继续保持健身
- 能把nvrhi的dx12和vulkan后端看了，并且把donut框架看了
- 看虚幻的MobileRenderer
  
有挑战性的话，再把PBRT3看了吧！之前在学校里一度把Path Tracing部分看了，但是太久了早就忘记了。


# 聊聊我的2023

今年上半年到4月份都一直感觉还在梦游..主要是工作在动荡。
入职了新公司以后倒是沉浸在虚幻里做了一些事情，主要是沿着工具开发和性能优化两块主题做了一些蛮有意思的工作。摆脱了应届生的身份以后，也可以放开手来做一些大量的代码改动，不再是小修小补式的补丁式开发了。这一点还是挺开心的。

除开工作以外，今年还花了很长一段时间来平衡工作和生活，以及维持心理健康。可能这也是现在打工人很多人都处于心理亚健康的状态吧。感觉长期在家里和公司两点一线，加上程序员本身缺乏社交和户外运动，导致心理始终处于一种向下的状态。所以意识到这个问题后，今年也是添加了很多调剂活动，除掉每天的固定的一定强度的有氧运动(无论是科学报道还是自身体会，一定的有氧运动能够提高心情)，周末还去了几次剧院看一些古典乐的演出。同时也调早了每天入睡的时间，避免熬夜，每天保持8小时的睡眠时间，一套组合拳下来能够有效放松自己的心情。