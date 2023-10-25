Test various error situations:

  $ ocaml-index file.cmt
  ocaml-uideps: unknown command 'file.cmt', must be either 'aggregate' or 'dump'.
  Usage: ocaml-uideps [COMMAND] …
  Try 'ocaml-uideps --help' for more information.
  [124]

  $ ocaml-index process-cmt
  ocaml-uideps: unknown command 'process-cmt', must be either 'aggregate' or 'dump'.
  Usage: ocaml-uideps [COMMAND] …
  Try 'ocaml-uideps --help' for more information.
  [124]

  $ ocaml-index aggregate
  ocaml-uideps: a required argument is missing
  Usage: ocaml-uideps aggregate [OPTION]… ARG… [ARG]…
  Try 'ocaml-uideps aggregate --help' or 'ocaml-uideps --help' for more information.
  [124]

  $ ocaml-index --help=plain
  NAME
         ocaml-uideps - An indexer for OCaml's artifacts
  
  SYNOPSIS
         ocaml-uideps [COMMAND] …
  
  COMMANDS
         aggregate [OPTION]… ARG… [ARG]…
             builds the index for a single .cmt file
  
         dump [OPTION]… ARG
             print the content of an index file to stdout
  
  OPTIONS
         -o VAL, --output-file=VAL (absent='project.index')
             name of the generated index
  
         --root=VAL
             if provided all locations will be appended to that path
  
         --store-shapes
             aggregate input-indexes shapes and store them in the new index
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         ocaml-uideps exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  $ ocaml-index aggregate --help=plain
  NAME
         ocaml-uideps-aggregate - builds the index for a single .cmt file
  
  SYNOPSIS
         ocaml-uideps aggregate [OPTION]… ARG… [ARG]…
  
  OPTIONS
         --debug
             set maximum log verbosity
  
         -o VAL, --output-file=VAL (absent='project.index')
             name of the generated index
  
         --root=VAL
             if provided all locations will be appended to that path
  
         --store-shapes
             aggregate input-indexes shapes and store them in the new index
  
         -v, --verbose
             increase log verbosity
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         ocaml-uideps aggregate exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  SEE ALSO
         ocaml-uideps(1)
  
  $ ocaml-index dump --help=plain
  NAME
         ocaml-uideps-dump - print the content of an index file to stdout
  
  SYNOPSIS
         ocaml-uideps dump [OPTION]… ARG
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         ocaml-uideps dump exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  SEE ALSO
         ocaml-uideps(1)
  
