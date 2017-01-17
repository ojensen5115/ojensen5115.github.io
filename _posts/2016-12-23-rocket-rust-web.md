---
layout: post
title:  "Rocket: a contender for web?"
date:   2016-12-23 22:37:45
categories: rust web rocket
permalink: /rust/helloweb
---

I've been getting into Rust recently, and have been extremely impressed with the language, just as a language. However, most of my code ends up in a web application, and thus far Rust has failed to impress in terms of web capabilities.

Today, I saw a [post on Hacker News](https://news.ycombinator.com/item?id=13245475) about a new contender in Rust web frameworks, [Rocket](https://rocket.rs/). Looking at the website, it looks pretty snazzy and the code snippets look really nice -- almost Djangoesque, which I suppose is what they're going for.

I'm going to go ahead and run through their tutorial and try to write a small application using Rocket, and see how it goes. Expect updates shortly!

-----------------

*Update (2016-12-28):*

So I've given Rocket a serious try over the last few days, implementing the [Pastebin tutorial application](https://rocket.rs/guide/pastebin/) and trying to accomplish everything in the closing list of ideas for extending the application. Unfortunately, I have to say that for now, this is not it. While the basics seem very interesting, Rocket has several large stumbling blocks ready for anyone who might want to "get serious" with it.

Documentation is very sparse. Indeed, the linked to page seems to be the primary documentation repository. This is particularly painful for a brand new project, because googling is wholly useless at this point (the only relevant results being the linked-to page). You can try to infer things from the API, but there's a lot that I would refer to as "hidden gotchas" which you'll only learn about through experimentation or by reading the source. Various side-comments in what documentaion there *is* leads me to believe that whoever's behind this has a poor grasp on probability and statistics, as well as on common security issues.

As an example of a hidden gotcha, consider the FromForm functionality which populates a struct from a form submission. Question: does it decode url-encoded values? Turns out the answer is: maybe. If your struct defines the field as a String then the input will be url-decoded, but if you define the field as a str then it won't be. FromForm only works at all if the submission has a of content-type 'application/x-www-form-urlencoded', failing entirely 'multipart/form-data' for example -- I have no idea how you're meant to go about parsing a multipart form besides doing it manually using just the raw post-data string as input. Also, good luck parsing anything with a checkbox (as their code example does) -- if the checkbox is checked, no problem, the field is populated with 'true'. But if the checkbox is left unchecked, then you get a parse failure because you're "missing" a field. There may be a way to work around this but if there is it isn't well documented and I haven't read through that part of the rocket source yet.

It also has zero support for middleware, which is probably going to be a dealbreaker for almost everyone. This means, for example, that there's no good way to implement CSRF protection. The toy examples on the Rocket website are very compelling, but at this point, creating toy examples seems about all it's good for.

All that being said, this has whet my apetite to try using Rust for web. The two big contenders at the moment seem to be [Iron](http://ironframework.io/) and [Nickel](http://nickel.rs/). I'll try implementing this Pastebin tutorial application in both of them, and see which one I like more.