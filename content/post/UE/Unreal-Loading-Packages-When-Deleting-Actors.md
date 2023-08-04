
---
title: "Unreal Loads Packages Slowly On Actor Deletion"
date: 2023-08-04T23:37:06+08:00
draft: false
categories: [ "UE"]
isCJKLanguage: true
slug: "692f9003"
toc: false
mermaid: false
fancybox: false
# latex support
# katex: true
# markup: mmark
# mmarktoc: false 
---

Recently, I've been annoyed by a long loading when deleting actors in an active level.
It happens only in studio project with a fairly large amount of assets.

The behavior is weird: when creating a new template level, then trying to delete an actor from this level, unreal strangely begins to calculate references, and a lot of packages are loaded, taking about 20 seconds.
This happens the first time an actor is deleted since editor startup, and the next deletions are as fast as usual.

20 seconds is not a long time, and there are some other urgent crashing bugs to fix in the project, so even though it's a little annoying, I just ignore it and work with this weird behavior for months.


# What's Worse...

And today, I found out it was, in fact, a huge disaster when in large level with thousands of actors.
It can take 5 minutes at most to load packages, what's worse, the editor begins to compile thousands of textures/meshes/shaders, after `Del` key is pressed down to delete an actor from the large level, which drives me to mad.

All I want to do is **Delete An Actor**, no loading, no compiling, no computing, JUST DELETE IT.

# The Solution

There is a zombie post on unreal forum, originally posted in 2018, but nobody answered the poor poster.(By the way, there are too many zombie topics on forum).
Luckily, this guy gave an interesting callstack about why deleting actors finally going into `LoadPackage`.


> Ref：[Actor Deletion in large level slow - Platform & Builds / Mobile - Epic Developer Community Forums](https://forums.unrealengine.com/t/actor-deletion-in-large-level-slow/439388)

It seems this problem is related to `FAssetRenameManager::CheckPackageForSoftObjectReferences`.
With a quick look through about the code, I found out unreal will try to load all referencers with the actor, and reset/rename existing references to avoid referencing invalid actors.
At least, it should behaves like that, and sounds reasonable. 
However, Apparently in my project editor loads too many unrelated assets, and the referencer list is obtained from `AssetRegistry`, which is beyond the scope of this problem.

I noticed there is an `editor setting` to turn off this annoying reference check, at the risk of breaking soft references.
But it should be OK, I guess, because soft references are usually null(they are null by default), and it's a good practice to check if a soft reference is valid before actually using it.

This behavior can be toggled in `Project Settings -> Editor -> Blurprint Project Settings -> Validate Unloaded Soft Actor References`.
A short documentation from epic is here [Blueprint Project Settings](https://docs.unrealengine.com/5.1/en-US/blueprint-project-settings-in-the-unreal-engine-project-settings/)
![Unreal-Loading-Packages-When-Deleting-Actors-2023-08-05-00-07-18](https://img.blurredcode.com/img/Unreal-Loading-Packages-When-Deleting-Actors-2023-08-05-00-07-18.png?x-oss-process=style/compress)

I have also posted the solution on the zombie thread. 
Hopefully, after five years, the original poster can no longer be bothered with this problem :)
