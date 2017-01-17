---
layout: post
title:  "Performance: Iron vs Nickel"
date:   2017-01-17 10:35:00
categories: rust web iron nickel performance
permalink: /rust/performance-nickel-vs-iron
---

This is part 3 of the Great Rust Web Experiment. See [Part 1](/rust/iron-getting-started) about Iron, and [Part 2](/rust/nickel-getting-started) about Nickel, and how it compares to Iron. In short, I've built the same relatively small web-application in Rust using both Iron and Nickel, in order to get a feel for both frameworks and determine which framework I prefer. But now that I have the identical application written using both frameworks, we have an opportunity to see how they compare, performance wise.

I used `wrk2` to run a series of benchmarks against both applications on my Dell XPS 13 laptop (with an i5 processor), and measured the number of requests per second that each application was able to field over a 30 second test. Both applications have logging middleware which prints a line to the console (timestamp, IP, request uri) for every request, and all tests were run twice -- once normally, and once with this `println!()` line commented out (in case printing to the console caused slowdown).

Of note is that Nickel can handle up to 7 concurrent connections, while Iron handles up to 25. I'm not sure where these values are set, but I tailored the tests to these values. **As a result, this may be comparing apples to oranges.** I would greatly appreciate feedback on the matter, whether this test is fair and how to make it moreso.


## Note: tweaking test parameters changed results significantly, so I'll have to do more analysis before making any kind of claims.
<!--

## Iron

`./wrk -c 25 -t 4 -d 30s -R 300000 http://localhost:3000/[request URI]`:

| Type | URI | Logging | No Logging |
|---|---|---|---|
| Render Template | /            | 25.5 k req/s | 37.3 k req/s |
| 404             | /nonexistant | 42.1 k req/s | 86.4 k req/s |
| Static File     | /webupload   | 41.6 k req/s | 80.8 k req/s |
| Retrieve Paste  | /mysrc       | 594 req/s    | 596 req/s    |

## Nickel

`./wrk -c 7 -t 4 -d 30s -R 300000 http://localhost:6767/[request URI]`:

| Type | URI | Logging | No Logging |
|---|---|---|---|
| Render Template | /               | 24.7 k req/s | 40.0 k req/s  |
| 404             | /nonexistant    | 47.2 k req/s | 111.0 k req/s |
| Static File     | /webupload.html | 43.5 k req/s | 101.5 k req/s |
| Retrieve Paste  | /mysrc          | 99 req/s     | 99 req/s      |

## Comparison

Iron seems to be somewhat faster than Nickel, although I'm not certain why that would be. In particular, the actual code driving retrieving pastes is identical, and given the numbers it seems to me that this code is the bottleneck (hence why this type of request is so much slower than the others) -- so why would Iron perform almost 5 times as well in this case? I am very curious about what's going on. Does this match other people's experiences?

My primary conclusion with respect to Iron versus Nickel from a programming perspective was that it really doesn't matter. They're both great frameworks, they're both fairly immature, and most of the differences you'll come across when writing a simple application are very minor. They are both very fast. I have leaned towards prefering Iron, because I understand its middleware model more clearly and because I feel like I have more control, but if we're honest here it's also probably because I happened to pick it up first.

-->