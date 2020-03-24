
---
title: "AABB包围盒快速变换方式"
date: 2020-03-24T20:57:36+08:00
draft: false
# tags: [ "" ]
categories: [ "CG"]
# keywords: [ ""]
lastmod: 2020-03-24T20:57:36+08:00
# CJKLanguage: Chinese, Japanese, Korean
isCJKLanguage: true
slug: "AABB包围盒快速变换方式"
toc: false
# latex support
katex: true
markup: mmark
---

这个问题来源于PBRT的第二章的一个练习题，朴素的AABB包围盒的变换方式是对8个顶点做同等变换，然后在8个顶点中找最小的xyz和最大的xyz来构成新的AABB顶点`pMin,pMax`。PBRT指出有更高效的方法来变换AABB，稍微搜索了并实现了一下。
参考:http://dev.theomader.com/transform-bounding-boxes/

考虑一个AABB的构造应该是两个对角点`pMin`和`pMax`，假设AABB的中点是$$\mathbf{c} = (c_x,c_y,c_t)^T$$,以及到两个对角点的`offset`: $$\mathbf{r} = (r_x,r_y,r_z)^T$$

$$
\mathbf{Box} = [\text{pMin,pMax}] = [c - r, c + r] =
\begin{bmatrix}
min \begin{pmatrix}
c_x \pm r_x \\
c_y \pm r_y \\
c_z \pm r_z \\
\end{pmatrix} &
max \begin{pmatrix}
c_x \pm r_x \\
c_y \pm r_y \\
c_z \pm r_z \\
\end{pmatrix}
\end{bmatrix}
$$

加上变换矩阵以及齐次坐标以后，应当是

$$
\mathbf{Box} = [M(c - r), M(c + r)] =
\begin{bmatrix}
min(M\begin{pmatrix}
c_x \pm r_x \\
c_y \pm r_y \\
c_z \pm r_z \\
1\\
\end{pmatrix}) &
max(M\begin{pmatrix}
c_x \pm r_x \\
c_y \pm r_y \\
c_z \pm r_z \\
1\\
\end{pmatrix})
\end{bmatrix}
$$

**最重要**的一点来了: 矩阵左乘列向量可以拆开成为多个列向量的和:

$$
\begin{bmatrix}
M_{00} & M_{01} \\
M_{10} & M_{11} \\
\end{bmatrix} 
\begin{bmatrix}
v_1 \\
v_2 \\
\end{bmatrix} = 
\begin{bmatrix}
M_{00} \\
M_{10} \\
\end{bmatrix} * v_1 + 
\begin{bmatrix}
M_{01} \\
M_{11} \\
\end{bmatrix} * v_2
$$

所以`AABB`的变换可以拆为

$$
min(M\begin{pmatrix}
c_x \pm r_x \\
c_y \pm r_y \\
c_z \pm r_z \\
1\\
\end{pmatrix})
=min(M_{|0} * (c_x \pm r_x) + M_{|1} * (c_y \pm r_y) +M_{|2} * (c_z \pm r_z) +M_{|3}
)
$$

又已知min函数的一个良好性质:`min(A+B) = min(A)+ min(B)`，所以上式还可以继续拆开:

$$
min(M\begin{pmatrix}
c_x \pm r_x \\
c_y \pm r_y \\
c_z \pm r_z \\
1\\
\end{pmatrix})
=min(M_{|0} * (c_x \pm r_x)) + min(M_{|1} * (c_y \pm r_y)) +min(M_{|2} * (c_z \pm r_z)) +M_{|3}
)
$$

到这里就找到我们想要的变换后的`pMin`了，我们只需要把变换矩阵的三个列向量拿出来分别与 $$(c_x \pm r_x),(c_y \pm r_y),(c_z \pm r_z)$$相乘，中间的结果可以复用,并取三次最小值就可以找到`pMin`,总共的计算量是 六次列向量与标量乘法，六次min/max操作以及三次列向量加法。

贴一下实现的代码:
```cpp
    Vector3f xa = m_col0 * b.pMin.x;
    Vector3f xb = m_col0 * b.pMax.x;

    Vector3f ya = m_col1 * b.pMin.y;
    Vector3f yb = m_col1 * b.pMax.y;

    Vector3f za = m_col2 * b.pMin.z;
    Vector3f zb = m_col2 * b.pMax.z;
    float w = m[3][3];
    Vector3f pmin_  =  Min(xa,xb) + Min(ya,yb) + Min(za,zb) + m_col4;
    Vector3f pmax_  =  Max(xa,xb) + Max(ya,yb) + Max(za,zb) + m_col4;
    box.pMin = {pmin_.x/w,pmin_.y/w,pmin_.z/w};
    box.pMax = {pmax_.x/w,pmax_.y/w,pmax_.z/w};
    return box;
```
