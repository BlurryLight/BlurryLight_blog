
---
title: "直线与三角形相交Moller Trumbore算法推导"
date: 2020-04-03T20:24:25+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
lastmod: 2020-04-03T20:24:25+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "直线与三角形相交Moller Trumbore算法推导"
toc: false
# latex support
katex: true
markup: mmark
---

`Moller Trumbore`算法是一种快速求解直线与三角形求交的算法，通过向量与矩阵计算可以快速得出交点与重心坐标。要推导它还比较麻烦，需要用到向量的混合积和克拉莫法则。

# 引理
## 引理1:
**三阶方阵的行列式等于三个列向量的混合积。**

$$
\begin{aligned}
&\mathbf{a \cdot (b \times c)} = 
\mathbf{b \cdot (c \times a)} = 
\mathbf{c \cdot (a \times b)}& = \\
&\mathbf{a \cdot -(c \times b)} = 
\mathbf{b \cdot -(a \times c)} = 
\mathbf{c \cdot -(b \times a)}& = 
\end{aligned}
\begin{vmatrix}
a_1 & b_1 & c_1\\
a_2 & b_2 & c_2\\
a_3 & b_3 & c_3
\end{vmatrix}
$$

## 引理2:
**克拉莫法则**:

如果一个线性方程组 $$\mathbf{Ax = c}$$, 其中A是可逆方阵，$$ \mathbf{x,c}$$都是列向量，那么方程有解，且x的每一个解

$$
x_i = \frac{\det{A_i}}{\det{A}}
$$

其中 $$A_i$$是被列向量取代了第i列的矩阵。

# Moller Trumbore Algorithm

已知光线 $$\mathbf{Ray = O + \text{t}\vec{D}}$$, 三角形三个顶点 $$ P_0, P_1, P_2 $$。
光线与三角形相交时，有如下等式:

$$
\mathbf{O + \text{t}\vec{D}} = (1 - b_1 - b_2)\mathbf{P_0} + b_1\mathbf{P_1} + b_2 \mathbf{P_2}
$$

则可以解

$$
\begin{bmatrix}
t \\ b_1 \\ b_2
\end{bmatrix} 
= \mathbf{\frac{1}{S_1 \cdot E_1}}
\begin{bmatrix} 
\bf{S_2 \cdot E_2}\\\bf{S_1 \cdot S}\\\bf{S_2 \cdot D}
\end{bmatrix}
$$

where:

$$
\begin{aligned}
E_1 = P_1 - P_0\\
E_2 = P_2 - P_0\\
S = O - P_0 \\
S_1 = D \times E_2 \\
S_2 = S \times E_1 \\
\end{aligned}
$$

## 推导过程

从这里开始

$$
\mathbf{O + \text{t}\vec{D}} = (1 - b_1 - b_2)\mathbf{P_0} + b_1\mathbf{P_1} + b_2 \mathbf{P_2}
$$

括号展开，移项可得

$$
\mathbf{O - P_0} = \mathbf{(P_1 - P_0)}b_1 + \mathbf{(P_2 - P_0)}b_2 - t\mathbf{D}
$$

观察一下上面的括号以及等式左边的内容，都是已知的**点**，因此点的加减可以用向量来表示，令

$$
\begin{aligned}
E_1 = P_1 - P_0\\
E_2 = P_2 - P_0\\
S = O - P_0 \\
\end{aligned}
$$

得到

$$
\mathbf{S} = \mathbf{E_1} b_1 + \mathbf{E_2}b_2 - t\mathbf{D}
$$

也即

$$
\begin{bmatrix}
\mathbf{-D} & \mathbf{E_1} & \mathbf{E_2}
\end{bmatrix}
\begin{bmatrix}
t \\ b_1 \\ b_2
\end{bmatrix}
= \mathbf{S}
$$

这是一个形如 $$\mathbf{A}x = c$$的等式，所以可以用克拉莫法则。

$$
t = \frac{\det{
\begin{bmatrix}
\mathbf{S} & \mathbf{E_1} & \mathbf{E_2}
\end{bmatrix}
}}{
\det{
\begin{bmatrix}
\mathbf{-D} & \mathbf{E_1} & \mathbf{E_2}
\end{bmatrix}
}}
$$

由向量混合积可以得出
分母部分:

$$
\det{
\begin{bmatrix}
\mathbf{-D} & \mathbf{E_1} & \mathbf{E_2}
\end{bmatrix}
} = 
\mathbf{-D} \cdot ( \mathbf{E_1} \times  \mathbf{E_2}) = 
\mathbf{E_1} \cdot ( \mathbf{D} \times  \mathbf{E_2}) \\
令S_1 = D \times E_2\\
原式等于 E_1 \cdot S_1
$$

分子部分:

$$
\det{
\begin{bmatrix}
\mathbf{S} & \mathbf{E_1} & \mathbf{E_2}
\end{bmatrix}
} = 
(\mathbf{S} \times \mathbf{E_1}) \cdot  \mathbf{E_2}\\
令S_2 = S \times E_1\\
原式等于 S_2 \cdot E_2
$$

因此

$$ t = \frac{\mathbf{S_2 \cdot E_2 }}{\mathbf{E_1 \cdot S_1}}$$

其他的两个`b1,b2`参数可以同样推出来。
