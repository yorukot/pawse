---
title: Natural Breaks
description: How Pawse waits before starting a break.
---

When Focus ends:

1. **Break soon** appears.
2. Click it, or stay idle for the configured interval.
3. Pawse waits through the Break Entry Grace Period.
4. The break begins if input does not resume.

Input during the grace period returns Pawse to **Break soon**.

Configure **Wait for Natural Break**, **Idle Before Break** (default: 2 seconds), and **Break Entry Grace Period** (default: 3 seconds) under **Break Behavior**.

Pawse reads aggregate idle activity, not keys, pointer positions, apps, or screen contents.
