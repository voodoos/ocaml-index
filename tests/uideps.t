  $ cat >main.ml <<EOF
  > let x = Foo.x + Foo.y
  > let y = Foo.y
  > include Foo
  > EOF

  $ cat >foo.ml <<EOF
  > let x = 42
  > let y = 36
  > EOF

  $ ocamlc -bin-annot -c foo.ml main.ml

  $ ocaml-uideps process-cmt main.cmt

  $ ocaml-uideps dump main.cmt.uideps
  {uid: Foo.1; locs: File "main.ml", line 1, characters 16-21;
                     File "main.ml", line 2, characters 8-13
   uid: Stdlib.48; locs: File "main.ml", line 1, characters 14-15
   uid: Foo.0; locs: File "main.ml", line 1, characters 8-13}
