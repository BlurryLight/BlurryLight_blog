
---
title: "一个JS的class fields导致在v8 9.4(nodejs 16)上的性能退化的问题"
date: 2024-02-10T15:32:34+08:00
draft: false
categories: [ "JavaScript", "PuerTs"]
isCJKLanguage: true
slug: "ca4cc3e1"
toc: true
mermaid: false
fancybox: false
blueprint: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---


最近仍然在做一些关于v8的性能测试，用到的v8的版本是`9.4`，对应nodejs的16版本。
在测试以下代码的时候发现一个有意思的性能问题。

```ts
class Point {
  X: number;
  Y: number;
  Z: number;
  constructor(x: number, y: number, z: number) {
    this.X = x;
    this.Y = y;
    this.Z = z;
  }
};

let start_time = new Date().getTime();
for (let i = 0; i < 100_0000; i++) {
  let p = new Point(1, 2, 3);
}
let end_time = new Date().getTime();
console.log("Time: " + (end_time - start_time) + "ms")
```


# 问题原因

`v8 9.4`在处理以下形式的js class声明的时候有性能问题，只要包含了`class fields`的声明，性能就会急剧劣化。

```js
class Point {

    //=== class fields define
    X;
    Y;
    Z;
    //=== class fields define

    constructor(x, y, z) {
        this.X = x;
        this.Y = y;
        this.Z = z;
    }
}
;
```

把tsc编译后的测试代码直接用node运行，

```js
"use strict";
class Point {
    X;
    Y;
    Z;
    constructor(x, y, z) {
        this.X = x;
        this.Y = y;
        this.Z = z;
    }
}
;
let start_time = new Date().getTime();
for (let i = 0; i < 1000000; i++) {
    let p = new Point(1, 2, 3);
}
let end_time = new Date().getTime();
console.log("Time: " + (end_time - start_time) + "ms");
```

在`v8 9.4`上运行的时间是`275ms`,在`v8 10.2`(node18)的运行时间是`6ms`。


# 绕过方法

参考：[#useDefineForClassFields](https://www.typescriptlang.org/tsconfig#useDefineForClassFields)
翻了下ts是在什么时候引入的`class fields`的生成，发现是在`3.7`版本引入的。
当编译目标为`ES2022 or later/ ESNext`的时候，就会自动生成`class fields`。

可能的修复方案:

- 通过`tsconfig.json`的`useDefineForClassFields`设置为false
- 下调编译目标到ES2022以前。
- 升级v8到10.1以上
