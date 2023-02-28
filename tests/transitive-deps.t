  $ cat >dune-project <<EOF
  > (lang dune 2.0)
  > (implicit_transitive_deps false)
  > EOF
 
  $ cat >main.ml <<EOF
  > let x = Foo.x
  > EOF
  $ cat >dune <<EOF
  > (executable (name Main) (libraries Foo))
  > EOF

  $ mkdir lib1
  $ cat >lib1/foo.ml <<EOF
  > include Bar
  > EOF
  $ cat >lib1/dune <<EOF
  > (library (name Foo) (libraries Bar))
  > EOF

  $ mkdir lib2
  $ cat >lib2/bar.ml <<EOF
  > let x = 21
  > EOF
  $ cat >lib2/dune <<EOF
  > (library (name Bar))
  > EOF

  $ ocamlc -bin-annot -c lib2/bar.ml
  $ ocamlc -bin-annot -c lib1/foo.ml -I lib2
  $ ocamlc -bin-annot -c main.ml -I lib1

  $ ocaml-uideps process-cmt -o main.uideps main.cmt
  $ ocaml-uideps process-cmt -o lib1/foo.uideps lib1/foo.cmt
  $ ocaml-uideps process-cmt -o lib2/bar.uideps lib2/bar.cmt

FIXME: There must be an issue with the load path
  $ ocaml-uideps aggregate -o test.uideps main.uideps lib1/foo.uideps lib2/bar.uideps
  [error] Failed to load cmt(i): Bar.cmti in load_path: [:
  lib1:
  /Users/ulysse/tmp/occurrences/_opam/lib/ocaml]

  $ ocaml-uideps dump main.uideps
  {uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5 }
  And 1 partial shapes.

  $ ocaml-uideps dump lib1/foo.uideps
  {}
  And 0 partial shapes.

  $ ocaml-uideps dump test.uideps
  {uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5
   uid: Bar.0; locs: "x": File "lib2/bar.ml", line 1, characters 4-5 }
  And 0 partial shapes.

