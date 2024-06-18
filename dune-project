(lang dune 2.9)

(name ocaml-index)

(cram enable)

(generate_opam_files true)

(package
 (name ocaml-index)
 (maintainers "ulysse@tarides.com")
 (authors "ulysse@tarides.com")
 (license MIT)
 (source (github voodoos/ocaml-index))
 (homepage "https://github.com/voodoos/ocaml-index")
 (bug_reports "https://github.com/voodoos/ocaml-index/issues")
 (synopsis "A tool that indexes value usages from cmt files")
 (description "ocaml-index should integrate with the build system to index codebase and allow tools such as Merlin to perform project-wide occurrences queries.")
 (depends
  (ocaml (>= "5.2"))
  (merlin-lib (>= "5.1-502"))))
