Test various error situations:

  $ ocaml-uideps file.cmt
  Unknown command "file.cmt".
  [2]

  $ ocaml-uideps process-cmt
  Command process-cmt requires at least one input file.
  [2]

  $ ocaml-uideps aggregate
  Command aggregate requires at least one input file.
  [2]
