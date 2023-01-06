---
layout: post
title:  "Auditing public Google Drive files"
date:   2023-01-05 17:05:31
categories: articles open-source tools
permalink: /musings/google-drive-public-file-audit
---

If you work in information security for a company that uses Google Drive internally, you are probably concerned about the possibility that sensitive files in your company Google Drive are configured with no access control. Often, people will publicly share a file temporarily, but then forget to un-share it again. Google Drive does not make it easy to even find your own files with this sharing setting enabled.

**I'm happy to release: [Google Drive audit](https://gitlab.com/regrello-public/google-drive-audit)**

It's a set of well-documented scripts to audit your organization's Google Drive for publicly shared files,
and optionally the functionality to lock down permissions.


### Why you should care

A file shared with "Anyone with the link can view" has no access controls on it at all.
It isn't necessarily easy to access -- the links are difficult to guess, after all.
But issues still crop up if the link to a sensitive file:
* is forwarded to an unauthorized party
* remains in the browser history of a shared device
* is harvested by various browser plugins or data broker scripts
* appears in logs in various places

Worse, once a file is shared as "Anyone with the link can view", you lose any ability to audit *who* has viewed the file.

Irritatingly, Google Cloud Admin will happily show you a report of *how many* such files exist in your organization.
But won't show you what they are, or who owns them.

### Other solutions

There are a few paid vendor solutions you can purchase in order to keep tabs on publicly shared files in your organization.
There are also plenty of scripts online that, after you grant it access to your Google Drive, can tell you *your* public files.

However, if you want to perform an audit on these files for all users in your organization,
you'll need to fiddle around with the API, domain-wide delegation, and so on.
I found it needlessly difficult to figure out how to get this working from documentation and other online resources,
so here's to save you the time I wish I could have saved myself!
