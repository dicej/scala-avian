Scala on Avian
==============

This project is intended to help make Scala portable to platforms
where a full-fledged JVM is difficult or impossible to install.


Status
------

Currently, all it does is create an executable which embeds the Avian
VM and relies on a filesystem-based classpath containing the Avian,
OpenJDK, and Scala classes needed to run the Scala interpreter.
Future goals include:

 * Use ProGuard to shrink the classpath to a minimal size.  This will
   require configuring ProGuard to keep all the code Scala loads via
   reflection or similar means which ProGuard can't detect itself.

 * Support loading classes from embedded JARs to allow the executable
   to work without any external dependencies.  Currently, Scala seems
   to require direct access to resources in the classpath, so we'll
   either need to fool it into thinking it's accessing the filesystem
   when it's really reading from an embedded JAR, or else find out if
   there's another way for Scala to operate without accessing
   classpath resources directly.

 * Support exclusively AOT-compiled operation (or AOT plus
   interpretation if the runtime-loaded bytecode is not
   performance-sensitive).  This is necessary to work on platforms
   such as iOS, where memory cannot be made both writable and
   executable, and thus JIT compilation is impossible.  How this is
   done will depend on if and how Scala does runtime bytecode
   generation.

 * Support platforms other than Linux.  This should be easy.


Building and Testing
--------------------

    $ make avian=<absolute path of avian source tree> \
        scala=<absolute path of scala binary distribution> \
        openjdk=<absolute path of openjdk binary distribution> \
        openjdk-src=<absolute path of openjdk source code>

    $ build/scala build/stage1

Note that you may need to reset your terminal after running the above
(e.g. using the "reset" command), since JLine does seem to clean up
after itself when run under Avian.  I haven't had a chance to
investigate why that is yet.
