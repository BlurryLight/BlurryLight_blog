
---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: false
# tags: [ "" ]
categories: [ "默认分类"]
# keywords: [ ""]
lastmod: {{ .Date }}
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "{{ substr (md5 (printf "%s%s" .Date (replace .TranslationBaseName "-" " " | title))) 4 8 }}"
toc: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

