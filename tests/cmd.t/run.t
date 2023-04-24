Test various error situations:

  $ ocaml-uideps file.cmt
  ocaml-uideps: unknown command 'file.cmt', must be one of 'aggregate', 'dump' or 'process-cmt'.
  Usage: ocaml-uideps COMMAND …
  Try 'ocaml-uideps --help' for more information.
  [124]

  $ ocaml-uideps process-cmt
  ocaml-uideps: a required argument is missing
  Usage: ocaml-uideps process-cmt [OPTION]… ARG [ARG]…
  Try 'ocaml-uideps process-cmt --help' or 'ocaml-uideps --help' for more information.
  [124]

  $ ocaml-uideps aggregate
  ocaml-uideps: a required argument is missing
  Usage: ocaml-uideps aggregate [OPTION]… ARG…
  Try 'ocaml-uideps aggregate --help' or 'ocaml-uideps --help' for more information.
  [124]

  $ ocaml-uideps --help=plain
  NAME
         ocaml-uideps - An indexer for OCaml's artifacts
  
  SYNOPSIS
         ocaml-uideps COMMAND …
  
  COMMANDS
         aggregate [OPTION]… ARG…
             merge multiple indexes into a unique one
  
         dump [OPTION]… ARG
             print the content of an index file to stdout
  
         process-cmt [OPTION]… ARG [ARG]…
             builds the index for a single .cmt file
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         ocaml-uideps exits with the following status:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  

  $ ocaml-uideps aggregate --help=plain
  NAME
         ocaml-uideps-aggregate - merge multiple indexes into a unique one
  
  SYNOPSIS
         ocaml-uideps aggregate [OPTION]… ARG…
  
  OPTIONS
         --debug
             set maximum log verbosity
  
         -o VAL, --output-file=VAL (absent='project.index')
             name of the generated index
  
         --store_shapes
             aggregate input-indexes shapes and store them in the new index
  
         -v, --verbose
             increase log verbosity
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         aggregate exits with the following status:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  SEE ALSO
         ocaml-uideps(1)
  
