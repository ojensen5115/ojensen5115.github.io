---
layout: post
title:  "Performance: Iron vs Nickel"
date:   2017-01-20 14:50:00
categories: rust web iron nickel performance
permalink: /rust/performance-nickel-vs-iron
---

This is part 3 of the Great Rust Web Experiment. See [Part 1](/rust/iron-getting-started) about Iron, and [Part 2](/rust/nickel-getting-started) about Nickel, and how it compares to Iron. In short, I've built the same relatively small web-application in Rust using both Iron and Nickel, in order to get a feel for both frameworks and determine which framework I prefer. But now that I have the identical application written using both frameworks, we have an opportunity to see how they compare, performance wise.

I used `wrk2` to run a series of benchmarks against both applications on my Dell XPS 13 laptop (with an i5 processor), and measured the number of requests per second that each application was able to field over a 30 second test. Both applications have logging middleware which prints a line to the console (timestamp, IP, request uri) for every request, and all tests were run twice -- once normally, and once without attaching the logging middleware (in case printing to the console caused slowdown).

Of note is that Nickel can handle up to 5 concurrent connections, while Iron handles up to 25. I'm not sure where these values are set, but for the sake of comparing apples to apples, I ran Iron's test three times: once with 10 connections (wrk2's default), once with 25 (Iron's max), and once with 5 (Nickel's max). I ran the Nickel tests only once, with 5 concurrent connections. Each wrk2 session consisted of a 5 minute test.

## Iron (25 concurrent connections)

`./wrk -c 25 -d 5m -R 300000 http://localhost:3000/[request URI]`:

| Type            | URI          | Logging      | No Logging   |
|-----------------|--------------|--------------|--------------|
| Render Template | /            | 27.7 k req/s | 40.0 k req/s |
| 404             | /nonexistant | 44.8 k req/s | 89.7 k req/s |
| Static File     | /webupload   | 40.7 k req/s | 84.4 k req/s |
| Retrieve Paste  | /mysrc       | 595 req/s    | 596 req/s    |

## Iron (10 concurrent connections)

`./wrk -d 5m -R 300000 http://localhost:3000/[request URI]`:

| Type            | URI          | Logging      | No Logging   |
|-----------------|--------------|--------------|--------------|
| Render Template | /            | 28.0 k req/s | 39.1 k req/s |
| 404             | /nonexistant | 43.7 k req/s | 89.2 k req/s |
| Static File     | /webupload   | 41.5 k req/s | 82.6 k req/s |
| Retrieve Paste  | /mysrc       | 248 req/s    | 249 req/s    |

<!--
## Iron (7 concurrent connections)

`./wrk -c 7 -d 5m -R 300000 http://localhost:3000/[request URI]`:

| Type            | URI          | Logging      | No Logging   |
|-----------------|--------------|--------------|--------------|
| Render Template | /            | 27.2 k req/s | 39.0 k req/s |
| 404             | /nonexistant | 41.9 k req/s | 81.4 k req/s |
| Static File     | /webupload   | 40.9 k req/s | 77.6 k req/s |
| Retrieve Paste  | /mysrc       | 149 req/s    | 149 req/s    |
-->

## Iron (5 concurrent connections)

`./wrk -c 5 -d 5m -R 300000 http://localhost:3000/[request URI]`:

| Type            | URI          | Logging      | No Logging   |
|-----------------|--------------|--------------|--------------|
| Render Template | /            | 22.8 k req/s | 38.6 k req/s |
| 404             | /nonexistant | 36.0 k req/s | 71.2 k req/s |
| Static File     | /webupload   | 32.0 k req/s | 63.5 k req/s |
| Retrieve Paste  | /mysrc       | 99  req/s    | 100 req/s    |

## Nickel

`./wrk -c 5 -d 5m -R 300000 http://localhost:6767/[request URI]`:

| Type            | URI             | Logging      | No Logging    |
|-----------------|-----------------|--------------|---------------|
| Render Template | /               | 25.4 k req/s | 37.9 k req/s  |
| 404             | /nonexistant    | 50.1 k req/s | 84.3  k req/s |
| Static File     | /webupload.html | 41.0 k req/s | 79.4  k req/s |
| Retrieve Paste  | /mysrc          | 99  req/s    | 100 req/s     |

## Comparison

I think it's interesting that retreiving pastes is so much slower than the other page types. For paste retrieval, I read the contents of a file into a string, and then package it as a `200 Ok` response. While I could use Static File to serve up pastes (and on the surface, that seems like a better plan), reading the contents into a string allows for optional syntax highlighting. It may have something to do with each request retrieving the *same* paste. My initial reaction is that there's probably some file locking going on, preventing more than one thread from accessing a given file at any given time, but if that were the case then we wouldn't see a dramatic increase in requests per second when increasing the number of concurrent connections (in the case of Iron). Interesting indeed.

Overall, the relative ability of Iron and Nickel to process requests quickly is fairly comparable. Given a number of concurrent connections that Nickel can handle (five or fewer), Nickel appears to slightly take the upper hand for "short circuit" requests like 404s or serving static files. When employing the same number of concurrent connections, Iron and Nickel both retrieve pastes at almost identical speeds, but Iron's ability to handle 25 connections as compared to Nickel's 5 means that increasing the number of concurrent connections allowed Iron to serve almost six times as many pastes per second as Nickel.

My primary conclusion with respect to Iron versus Nickel from a programming perspective, as well as now from a performance perspective, is that it really doesn't matter much. They're both great frameworks, they're both fairly immature, and most of the differences you'll come across when writing a simple application are very minor. They are both very fast. I have leaned towards prefering Iron, because it is better documented, because I understand its middleware model more clearly, and because I feel like I can extend it more effectively to do the sorts of things I want, but if we're honest here it's also probably because I happened to pick it up first.

If you are deciding between Iron and Nickel, I'd suggest you have a quick look through the source code of this application (see my [Iron version](https://github.com/ojensen5115/pastebin-iron/blob/master/src/main.rs) and my [Nickel version](https://github.com/ojensen5115/pastebin-nickel/blob/master/src/main.rs)), and decide which approach feels more natural to you.