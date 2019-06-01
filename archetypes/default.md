---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true
# tags: [ "" ]
categories: [ "默认分类"]
# keywords: [ ""]
lastmod: {{ .Date }}
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "{{ replace .Name "-" " " | title }}"
---

