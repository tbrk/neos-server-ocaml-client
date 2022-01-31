OCaml XML-RPC client for NEOS Server
====================================

Access the [NEOS Server](https://neos-server.org/neos/) using the 
[XMLRPC](https://neos-server.org/neos/xml-rpc.html) interface from OCaml.
See the [help](https://neos-server.org/neos/solvers/lp:CPLEX/LP-help.html) 
for submitting LP problems.

This program relies on the [ocaml-rpc](https://github.com/mirage/ocaml-rpc), 
[ocaml-base64](https://github.com/mirage/ocaml-base64), and 
[ocaml-cohttp](https://github.com/mirage/ocaml-cohttp) libraries. Many 
thanks to their authors and hard-working maintainers.

Dependencies
------------

```
opam install base64.rfc2045 cohttp-lwt-unix ppx_deriving.show ppx_deriving_rpc rpclib
```

Requires [funzip](https://linux.die.net/man/1/funzip). If you know how to 
use either [camlzip](https://github.com/xavierleroy/camlzip) or 
[decompress](https://github.com/mirage/decompress) libraries to unzip the 
only file in a `.zip` archive into a string, please [let me 
know](mailto:tim@tbrk.org)!

Use
---

Run the example code as follows
```
make && ./neosclient.exe --email <your-email-address> test.lp

```

Please provide your real email address out of respect for the maintainers of 
the NEOS servers.

