Test various error situations:

  $ ocaml-index file.cmt
  ocaml-index: unknown command 'file.cmt', must be either 'aggregate' or 'dump'.
  Usage: ocaml-index [COMMAND] …
  Try 'ocaml-index --help' for more information.
  [124]

  $ ocaml-index process-cmt
  ocaml-index: unknown command 'process-cmt', must be either 'aggregate' or 'dump'.
  Usage: ocaml-index [COMMAND] …
  Try 'ocaml-index --help' for more information.
  [124]

  $ ocaml-index aggregate

  $ ocaml-index --help=plain
  NAME
         ocaml-index - An indexer for OCaml's artifacts
  
  SYNOPSIS
         ocaml-index [COMMAND] …
  
  COMMANDS
         aggregate [OPTION]… [ARG]…
             builds the index for a single .cmt file
  
         dump [OPTION]… ARG
             print the content of an index file to stdout
  
  OPTIONS
         -I VAL
             an extra directory to add to the load path
  
         -o VAL, --output-file=VAL (absent=project.ocaml-index)
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
         ocaml-index exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  $ ocaml-index aggregate --help=plain
  NAME
         ocaml-index-aggregate - builds the index for a single .cmt file
  
  SYNOPSIS
         ocaml-index aggregate [OPTION]… [ARG]…
  
  OPTIONS
         --debug
             set maximum log verbosity
  
         -I VAL
             an extra directory to add to the load path
  
         -o VAL, --output-file=VAL (absent=project.ocaml-index)
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
         ocaml-index aggregate exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  SEE ALSO
         ocaml-index(1)
  
  $ ocaml-index dump --help=plain
  NAME
         ocaml-index-dump - print the content of an index file to stdout
  
  SYNOPSIS
         ocaml-index dump [OPTION]… ARG
  
  COMMON OPTIONS
         --help[=FMT] (default=auto)
             Show this help in format FMT. The value FMT must be one of auto,
             pager, groff or plain. With auto, the format is pager or plain
             whenever the TERM env var is dumb or undefined.
  
  EXIT STATUS
         ocaml-index dump exits with:
  
         0   on success.
  
         123 on indiscriminate errors reported on standard error.
  
         124 on command line parsing errors.
  
         125 on unexpected internal errors (bugs).
  
  SEE ALSO
         ocaml-index(1)
  
