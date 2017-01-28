---
layout: post
title:  "(Not) Getting Started with Pencil"
date:   2017-01-28 12:43:21
categories: rust web pencil
permalink: /rust/pencil-getting-started-compilation-issues
---

I've heard some great things about the Pencil framework, and the examples on the [Pencil website](https://fengsp.github.io/blog/2016/3/introducing-pencil/) look pretty compelling. Lets give it a try and see how it stacks up against Iron and Nickel! Time to create `pastebin-pencil`.

To get started, lets copy/paste Pencil's "hello world" example:

    extern crate pencil;

    use pencil::{Pencil, Request, Response, PencilResult};

    fn hello(_: &mut Request) -> PencilResult {
        Ok(Response::from("Hello World!"))
    }

    fn main() {
        let mut app = Pencil::new("/web/hello");
        app.get("/", "hello", hello);
        app.run("127.0.0.1:5000");
    }

My initial attempt at trying to `cargo build` it failed:

       Compiling openssl v0.7.14
       Compiling openssl-sys-extras v0.7.14
       Compiling handlebars v0.16.1
       Compiling phf_generator v0.7.21
    Build failed, waiting for other jobs to finish...
    Build failed, waiting for other jobs to finish...
    error: failed to run custom build command for `openssl v0.7.14`
    process didn't exit successfully: `/home/ojensen/programming/rust/pastebin-pencil/target/debug/build/openssl-a0ff3cdd6ccfd560/build-script-build` (exit code: 101)
    --- stdout
    TARGET = Some("x86_64-unknown-linux-gnu")
    OPT_LEVEL = Some("0")
    TARGET = Some("x86_64-unknown-linux-gnu")
    HOST = Some("x86_64-unknown-linux-gnu")
    TARGET = Some("x86_64-unknown-linux-gnu")
    TARGET = Some("x86_64-unknown-linux-gnu")
    HOST = Some("x86_64-unknown-linux-gnu")
    CC_x86_64-unknown-linux-gnu = None
    CC_x86_64_unknown_linux_gnu = None
    HOST_CC = None
    CC = None
    HOST = Some("x86_64-unknown-linux-gnu")
    TARGET = Some("x86_64-unknown-linux-gnu")
    HOST = Some("x86_64-unknown-linux-gnu")
    CFLAGS_x86_64-unknown-linux-gnu = None
    CFLAGS_x86_64_unknown_linux_gnu = None
    HOST_CFLAGS = None
    CFLAGS = None
    PROFILE = Some("debug")
    running: "cc" "-O0" "-ffunction-sections" "-fdata-sections" "-fPIC" "-g" "-m64" "-o" "/home/ojensen/programming/rust/pastebin-pencil/target/debug/build/openssl-87c538093dbe2342/out/src/c_helpers.o" "-c" "src/c_helpers.c"
    cargo:warning=src/c_helpers.c: In function ‘rust_SSL_clone’:
    cargo:warning=src/c_helpers.c:4:5: warning: implicit declaration of function ‘CRYPTO_add’ [-Wimplicit-function-declaration]
    cargo:warning=     CRYPTO_add(&ssl->references, 1, CRYPTO_LOCK_SSL);
    cargo:warning=     ^~~~~~~~~~
    cargo:warning=src/c_helpers.c:4:20: error: dereferencing pointer to incomplete type ‘SSL {aka struct ssl_st}’
    cargo:warning=     CRYPTO_add(&ssl->references, 1, CRYPTO_LOCK_SSL);
    cargo:warning=                    ^~
    cargo:warning=src/c_helpers.c:4:37: error: ‘CRYPTO_LOCK_SSL’ undeclared (first use in this function)
    cargo:warning=     CRYPTO_add(&ssl->references, 1, CRYPTO_LOCK_SSL);
    cargo:warning=                                     ^~~~~~~~~~~~~~~
    cargo:warning=src/c_helpers.c:4:37: note: each undeclared identifier is reported only once for each function it appears in
    cargo:warning=src/c_helpers.c: In function ‘rust_SSL_CTX_clone’:
    cargo:warning=src/c_helpers.c:8:20: error: dereferencing pointer to incomplete type ‘SSL_CTX {aka struct ssl_ctx_st}’
    cargo:warning=     CRYPTO_add(&ctx->references,1,CRYPTO_LOCK_SSL_CTX);
    cargo:warning=                    ^~
    cargo:warning=src/c_helpers.c:8:35: error: ‘CRYPTO_LOCK_SSL_CTX’ undeclared (first use in this function)
    cargo:warning=     CRYPTO_add(&ctx->references,1,CRYPTO_LOCK_SSL_CTX);
    cargo:warning=                                   ^~~~~~~~~~~~~~~~~~~
    cargo:warning=src/c_helpers.c: In function ‘rust_X509_clone’:
    cargo:warning=src/c_helpers.c:12:21: error: dereferencing pointer to incomplete type ‘X509 {aka struct x509_st}’
    cargo:warning=     CRYPTO_add(&x509->references,1,CRYPTO_LOCK_X509);
    cargo:warning=                     ^~
    cargo:warning=src/c_helpers.c:12:36: error: ‘CRYPTO_LOCK_X509’ undeclared (first use in this function)
    cargo:warning=     CRYPTO_add(&x509->references,1,CRYPTO_LOCK_X509);
    cargo:warning=                                    ^~~~~~~~~~~~~~~~
    ExitStatus(ExitStatus(256))


    command did not execute successfully, got: exit code: 1

I haven't run updates on my laptop in a little while, so giving it the old `apt update && apt upgrade` seems like a likely fix.
After allowing the upgrades to install, `cargo build` continues to fail with the same error.
Even `apt dist-upgrade` does not resolve the issue.
Perhaps this *isn't* my fault after all?

Looking through the `Cargo.lock` file, the current version of Pencil depends on [Hyper](https://github.com/hyperium/hyper) version 0.9.17.
This in turn depends on the openssl crate version 0.7.14, two minor versions out of date (the current version is 0.9.6).
Unfortunately, it looks like my installed version of OpenSSL may be *too new* to work with this.

As far as I can tell, there's no easy fix for this, besides waiting for Pencil to update to using a newer version of Hyper.
This update contains breaking changes, and so won't be a trivial fix.

<!--
*Side Note: like Nickel and in contrast to Iron, Pencil requires dependencies that you may not be planning on using.
For example, it pulls in Handlebars and requires OpenSSL, even if you're planning on making an HTTP-only API service.
This is not necessarily a bad thing: you should be using SSL no matter what you're making, and there are plenty of great tools around for making API services in Rust.
Still, it's something to be aware of, because the SSL dependency in particular is external to Cargo:
    **you will need to ensure that you install a current version of OpenSSL on any machine you wish to compile from or deploy to.***
-->