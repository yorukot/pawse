---
title: Install Pawse
description: Install and approve Pawse on macOS.
---

Requires macOS 14 or later on Apple silicon or Intel.

## Install

1. Download the DMG from the [Download page](/download/).
2. Open it and drag Pawse to Applications.
3. Eject the DMG and open Pawse from Applications.

## First launch

Early-access builds are not notarized. If macOS blocks Pawse:

1. Open **System Settings → Privacy & Security**.
2. Click **Open Anyway** next to Pawse.
3. Confirm with **Open**.

Only approve a DMG from this site or the [official release](https://github.com/yorukot/pawse/releases).

## Verify the DMG

```shell
shasum -a 256 ~/Downloads/Pawse-x.y.z.dmg
```

Compare the result with the checksum file linked on the Download page.

## Remove Pawse

Quit Pawse and move it from Applications to the Trash. Delete its sandbox container only if you also want to remove local settings and history.
