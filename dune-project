(lang dune 2.9)

(name ocaml-index)

(cram enable)

(generate_opam_files true)

(package
 (name ocaml-index)
 (synopsis "A tool that indexes value usages in a cmt file.")
 (description "ocaml-index should integrate with the build system to index a \
  codebase.")
 (depends
  (cmdliner (>= "1.1.0"))))
