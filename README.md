Native Service Demo
===================

A toy project to implement a native service because I can't access Node-style modules from Elm.  The aim was to create something sorta resembling http-elm, although that may ultimately be pointless.

Note that Native modules are by their nature currently fragile, **depending on how the Elm compiler works**.  This may be out of date by the time you see it.  You have been warned.

A better (or at least less fragile) pattern to follow may be to simply create a `port signal` out which service requests flow and another in through which service responses flow.  Also, Requests and Responses should be in the form of either primitives such as Strings and Numbers, or Records/JSON so that the implementation details of type classes can be ignored.
