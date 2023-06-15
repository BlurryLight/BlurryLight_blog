
---
title: "禁止Hugo的goldmark后端转义英文引号为&rsquo"
date: 2023-06-15T20:29:56+08:00
draft: false
categories: [ "hugo"]
isCJKLanguage: true
slug: "02dd9af9"
toc: false
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

根据主题的不同，我有时候会使用英文写作博客。
平时由于字体的原因，我还没注意到hugo的会把markdown中的`'`转义为`&rsquo`。
直到某一天注意到引号好像渲染的不太对，把字体切换到`sans-serif`就更明显了。

{{< imgCompare 
	ImgWidth="60" 
	ImgSrc0="https://img.blurredcode.com/img/禁止Hugo转义英文引号-2023-06-15-20-34-52.png?x-oss-process=style/compress" 	ImgAlt0="异常引号" 
	ImgSrc1="https://img.blurredcode.com/img/禁止Hugo转义英文引号-2023-06-15-20-35-09.png?x-oss-process=style/compress" 	ImgAlt1="正常引号" 
	ImgCaption="左:异常引号 右:正常引号">}}

对前端完全不懂，在主题里的代码里翻了一下也没有找到相关的代码。
随后把渲染的后端从`goldmark`换成了`mmark`，发现问题就消失了，初步判断是hugo的渲染后端的问题。
打开html源码看了一眼，所有的`'`引号都被生成了`&rsquo`。

![禁止Hugo转义英文引号-2023-06-15-20-38-55](https://img.blurredcode.com/img/禁止Hugo转义英文引号-2023-06-15-20-38-55.png?x-oss-process=style/compress)

以`hugo` + `goldmark` + `rsquo`为关键词搜了一下，在官网的文档找到了相关的设置(吐槽一下，官网的文档没有历史版本，想找一下0.68.3的文档都很难找)

> [Configure Markup | Hugo](https://gohugo.io/getting-started/configuration-markup/)


在老版本(0.68.3)的版本下，配置和官网文档上的有点不一样，不过怀疑的方向是对的，在老版本直接关了就行。

在`config.toml`里加入，见[diff](https://github.com/BlurryLight/BlurryLight_blog/commit/f0d63e669d68da3d52e757df08e07fec08118216#diff-28043ff911f28a5cb5742f7638363546311225a63eabc365af5356c70d4deb77)
```
  [markup.goldmark.extensions]
      typographer = false
```