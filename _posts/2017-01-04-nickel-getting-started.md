---
layout: post
title:  "Getting Started with Nickel"
date:   2017-01-04 10:09:00
categories: rust web iron
permalink: /rust/nickel-getting-started
---

This is part 2 of the Great Rust Web Experiment. For Part 1 see [here](/rust/iron-getting-started). I'm building the same relatively small web-application in Rust using both Iron and Nickel, in order to get a feel for both frameworks and determine which framework I prefer. The application is a simple Pastebin clone, designed primarily for use with `curl` but which will also work (to a limited extent) via browser. It supports submitting, deleting, editing, and retrieving pastes (with optional syntax highlighting).

At this stage, the Nickel version is complete and at more-or-less feature parity with the Iron version. I'm finding I can copy almost all of the code verbatim, which is a nice surprise. And it turns out Nickel is surprisingly great too. I was kind of hoping it wouldn't be, because now that I've gotten the hang of Iron it'd be nice to say "yep and the others suck, I don't need to bother learning them". And having two great frameworks makes the final decision of which to use more difficult.

- A paste of its [own source](http://45.62.211.238:3000/messH) code, which you can see [syntax highlighted](http://45.62.211.238:3000/messH/rs)
- See it on [Github](https://github.com/ojensen5115/pastebin-nickel)

Nickel supports exactly what I wished Iron had: a quick and easy way to generate a common-case response. It adds a trait to a lot of types including `str`, `String`, a rendered template, etc. allowing you to call a `resp()` method on it, generating a successful response. So for example, in Iron you might have:

```
Ok(Response::with((Status::Ok, "Hello, World!")));
```

In Nickel you could simply have:

```
"Hello, World!".respond(resp)
```

Writing middleware is also a little less verbose, as it has a convenient macro to do a lot of the magic for you. It has a slightly different model for chaining middleware together than Iron does, where you essentially attach components to the server and they execute in the order in which they were attached. That being said, as far as I can tell there isn't a way to write "after-handler" middleware, code that operates on a response after it gets generated from the request, but before it gets sent out to the client.

Other things that are more convenient in Nickel include setting a response content-type:

```
Nickel:
    resp.set(MediaType::Txt);

Iron:
    resp.set_mut(Header(ContentType::plaintext()));
```

and getting URL segments as parameters:

```
Nickel:
    let id = req.param("paste_id").unwrap_or("");

Iron:
    let params = req.extensions.get::<Router>().unwrap();
    let id = &params.find("paste_id").unwrap_or("");
```

On the other hand, some things are a lot more convenient in Iron. For example, Nickel does not appear to allow you to get a POST parameter directly, requiring instead that you loop through *all* POST parameters and match on the name:

```
let mut body = vec![];
req.origin.read_to_end(&mut body).unwrap();
let paste = match formdata::read_formdata(&mut body, &req.origin.headers) {
    Ok(data) => {
        let mut x = None;
        for (name, value) in data.fields {
            if name == "data" {
                x = Some(value);
                break;
            }
        }
        match x {
            Some(s) => s,
            _ => return (StatusCode::BadRequest, "No data.\n").respond(resp)
        }
    },
    _ => // formdata did not find *any* parameters
};
```

whereas in Iron, you'll need to use an external crate, but the end result is simpler:

```
extern crate params;
use params::{Params, Value};

[...]

let params = req.get_ref::<Params>().unwrap();
match params.find(&["data"]) {
    Some(&Value::String(ref data)) => data.clone().to_string(),
    _ => return Ok(Response::with((status::BadRequest, "No data.\n")))
}
```

I was also didn't end up managing to serve failure staus codes with a response body. As far as I could tell, when declaring that a response should have a `403 Bad Request` status, the response body would get eaten. For example, in the above case where Nickel is unable to find a POST parameter called "data", a `403 Bad Request` is sent to the client without the "No data submitted." string. Perhaps Nickel does this automatically for response codes that traditionally do not come attached with a response body, but this is the sort of decision I like to be able to make myself.

Continuing in things-Nickel-does-that-I-wish-it-didn't, Nickel infers the content type of statically served files from the file extension. It also passes requests through directly, so requesting file "file.xyz" requires that the request be for "file.xyz" with whatever path you've set for your static files. As such, while the Iron version had its web upload form accessible at `/webupload`, the Nickel version of the application requires that the URL be `/webupload.html` (as doing otherwise results in the visitor downloading the HTML page).

My overall impressions with Nickel are favorable -- in comparison, Iron is also definitely better documented than Nickel, but Nickel makes a number of common use cases a lot more convenient. Nickel also packages more functionality into the main Nickel crate (whereas with Iron you'll be `extern crate`ing a lot more things) -- the flip side of that means that you have dependencies whether you want them or not, e.g. your HTTP server will require openssl regardless of whether you actually use it or not.

When it comes down to it, Iron and Nickel are very similar. Switching from one to the other mostly just consists of altering function signatures and changing some small details, with the lion's share of your code remaining identical.