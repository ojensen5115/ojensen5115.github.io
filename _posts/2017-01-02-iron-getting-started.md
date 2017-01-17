---
layout: post
title:  "Getting Started with Iron"
date:   2017-01-02 10:37:00
categories: rust web iron
permalink: /rust/iron-getting-started
---

After having dealt with far too much PHP, and finding python frameworks like Django and Flask ultimately unsatisfying, I've decided to try using Rust. The two big contenders at the moment seem to be [Iron](http://ironframework.io/) and [Nickel](http://nickel.rs/) (there is of course also [Rocket](https://rocket.rs/), but I'm [excluding that for now](/rust/helloweb)). So I figure I'll implement the same simple application in both, and see which one I prefer.

The application is a simple Pastebin clone, designed primarily for use with `curl` but which will also work (to a limited extent) via browser. It supports submitting, deleting, editing, and retrieving pastes (with optional syntax highlighting).

- See a [live demo](http://45.62.211.238:3000/).
- I pasted its [own source code](http://45.62.211.238:3000/8sIze) to it, which you can also see [syntax highlighted](http://45.62.211.238:3000/8sIze/rs).
- See it on [Github](https://github.com/ojensen5115/pastebin-iron).

Overall, my impressions are very favorable. Once you get the hang of how Iron deals with a request, and sort out how to piece components together, it's surprisingly pleasant to use. Implementing your own middleware is also very easy (see LoggingMiddleware). I like that all templates are loaded at startup time. I also like how it's really just a Rust program that happens to do some webstuff, so things like spawning a thread to cull old pastes is almost trivial.

Getting access to request parameters is a little painful, though. In the easy case (when the parameter in question is a URL segment that you matched on in the routing), it essentially looks something like this:

```
let params = req.extensions.get::<Router>().unwrap();
let paste_id = &params.find("paste_id").unwrap_or("");
```

Trying to grab POST parameters is a little more involved, and you'll need to pull in a crate of some kind. I used `Params`:

```
let params = req.get_ref::<Params>().unwrap();
match params.find(&["data"]) {
    Some(&Value::String(ref data)) => data.clone().to_string(),
    _ => return Ok(Response::with((status::BadRequest, "No paste data submitted.\n")))
}
```

Not the cleanest looking code. I'm still not entirely sure how to get at query parameters (e.g. `/somepage?param=value`) but I didn't give it too much effort. I suppose in theory the language identifier for syntax highlighting ought to be a query parameter instead of a URL segment, but I find I don't actually care that much.

Surprisingly, I find I am *very* much enjoying a compiled language for web development. Coming from a PHP / Python background, the compiler has been fantastic in finding and making me fix a number of "classic" bugs you find in interpreted languages. Having these sorts of things enforced at compile time is a wonderful change from the old "everything explodes at runtime" standby that I'm so used to.

Finally, there's something downright magical to a deployment process consisting of copying a binary to some host and running it. No dependencies, no runtimes, no *anything*. Just copy, execute, and sit back.