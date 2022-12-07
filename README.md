# OCaml-uideps

Ocaml-uideps is a tool that indexes values from CMT files. Its current purpose
is to provide project-wide occurrences for OCaml codebases. The tool iterates on
a given cmt's typedtree and determines the definition of every value found in
it. It then write an index to disk where values corresponding to the same
definition are grouped together. The tool can also take multiple such indexes
and merge them in a signle one.

# Indexing a project

- For each CMT file, call `ocaml-uideps process-cmt <file.cmt>` to generate the
  index corresponding to that compilation unit. By default the output file is
  named `file.uideps`
- Group the resulting indexes together by calling `ocaml-uideps aggregate
  <index1.uideps> ... <indexn.uideps> -o project.uideps`

In the current version, generating the index for a given CMT file has the same
dependency cone than linking the corresponding compilation unit. This is due to
the process of determining a value's definition that requires loading the CMT
file of the compilation unit where this value is defined.

