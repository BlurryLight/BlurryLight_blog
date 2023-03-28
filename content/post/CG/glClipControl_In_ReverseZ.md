
---
title: "Why glClipControl is crucial for reverse-Z implementation in OpenGL"
date: 2023-03-22T20:00:13+08:00
draft: false
categories: [ "CG"]
isCJKLanguage: true
slug: "9f52e5cc"
toc: false
mermaid: false
fancybox: false
# latex support
katex: true
markup: mmark
mmarktoc: false 
---
![glClipControl_In_ReverseZ-2023-03-22-20-56-48](https://img.blurredcode.com/img/glClipControl_In_ReverseZ-2023-03-22-20-56-48.png?x-oss-process=style/compress)

Reverse-Z is a widely used technique for optimizing depth buffer precision in modern video games.
If you are looking for a detailed tutorial on how to implement Reverse-Z in OpenGl,
Blog [reversed-z-in-opengl](https://nlguillemot.wordpress.com/2016/12/07/reversed-z-in-opengl/) is an excellent starting point.

In short, the process involves several steps, including:
1. Use `glClipControl` to adjust z-range in NDC from `[-1,1]` to `[0,1]`
2. Adjust Project Matrix to project far plane on 0 and near plane on 1 
3. Change Depth Comparison function to `GL_GREATER/GL_GEQUAL`
4. Clear Depth Buffer with 0


At first glance, it looks good. However, soon I released flipping the projext matrix to put the far plane at `-1` and the near plane at `1` would be a simpler solution. Why should we use `glClipControl`?
After further consideration, I realized `glClipControl` is necessary to avoid any loss depth precision.

In Reverse-Z, the goal is to place faraway objects at a depth value close to 0 in order to improve their precision. This is because float-point numbers  have higher precision near 0, making it easier to represent the subtle differences.

In vanilla OpenGL,  the final z-buffer value is obtained through 2 steps:
1. project objects in NDC `[-1,1]` range
2. scale and bias the z axis to `[0,1]` by $$0.5 z + 0.5$$


Flipping the Z axis doesn't help in depth precision. 
It essentially does nothing.
Although we may get **correct** reversed z-buffer, the precision is lost when we project faraway object on `-1`, making it a **fake** reversed-z.

There is also another idea to do that. How about adjusting our project matrix to assign a value of 0 to faraway objects and 1 to nearby objects?
Unfortunately, this approach is also flawed. While we may correctly get `[0,1]` z-value at stage 1, OpenGL will subsequently scale and bias it, resulting in a limited zbuffer of `[0.5,1]` range. The depth precision is lost because of the fixed `0.5` bias.

# Any Other Tricks?

The second approach fails because OpenGL will adjust depth value to DepthRange, which is initially set at [0,1]. However, there is a function control the range `glDepthRange`.
If we adjust depth range to `[-1,1]`, we avoid the `0.5` bias.
Unfortunately, OpenGL Spec doesn't allow us to do that: `glDepthRange` clamps its args to `[0,1]` range. 

Taking Mesa3D code as example:

```c
static void
set_depth_range_no_notify(struct gl_context *ctx, unsigned idx,
                          GLclampd nearval, GLclampd farval)
{
   if (ctx->ViewportArray[idx].Near == nearval &&
       ctx->ViewportArray[idx].Far == farval)
      return;

   /* The depth range is needed by program state constants. */
   FLUSH_VERTICES(ctx, _NEW_VIEWPORT, GL_VIEWPORT_BIT);
   ctx->NewDriverState |= ST_NEW_VIEWPORT;

    // clamp happens
   ctx->ViewportArray[idx].Near = SATURATE(nearval);
   ctx->ViewportArray[idx].Far = SATURATE(farval);
}
```

There is an extension named [`NV_depth_buffer_float`](https://registry.khronos.org/OpenGL/extensions/NV/NV_depth_buffer_float.txt) who provides an extended function `glDepthRangedNV` which can accept unclamped depth range, so this trick is not allowed in unextended OpenGL.
For more details, Secion **DirectX vs. OpenGL** in Blog [Outerra: Maximizing Depth Buffer Range and Precision](https://outerra.blogspot.com/2012/11/maximizing-depth-buffer-range-and.html) offers more insights.