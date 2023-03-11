
---
title: "Discover Unreal Engine APIs Offline with Zeal"
date: 2023-03-11T20:26:44+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "d009f04a"
toc: false
mermaid: false
fancybox: true 
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

For days I have been using an offline documentation browser named [zealdocs/zeal](https://github.com/zealdocs/zeal/releases/tag/v0.6.1) to search for and browse the APIs I need while programming.
Zeal is an open-source offline documentation, which is compatible with the popular MacOS-Only paied documentation tool named `Dash`.


{{<fancybox URL="https://img.blurredcode.com/img/UE4-API-For-Zealdoc-2023-03-11-20-37-28.png?x-oss-process=style/compress" Caption="Unreal Doc in Zeal" >}}

Zeal offers several open-box documentations, including CPP and Lua documentation.
Unfortunately, there is no official UE documentation availbale from Epic Games or Zeal.
Some developpers have taken it upon themselves to grab contents from Unreal Engine website and create their own documentation.

The details about methods and scripts to make a documentation are described in this blog.
If you're interested in creating the latest documentation, you may need a Python2 environment and scrape from Epic on your own.
> Reference：[抓取 UE API 并生成带索引的 Dash 文档 | 循迹研究室](https://imzlp.com/posts/11515/)


There are also some user-contributed docsets availlable online. 
Here are the URLs I've collected so far:

- UE 4.26 Documentation: https://kapeli.com/feeds/zzz/user_contributed/build/UnrealEngine4/UnrealEngine4.tgz
- UE 4.25/UE 5.0.2: https://github.com/hxhb/UE4_API_FOR_DASH/releases

To use offline docsets, simply download them and extact them to the directory specified under `Prefereces->General->Docset Storage`.