  $ cat >main.ml <<EOF
  > let x = Foo.x + Foo.y
  > let y = Foo.y + Bar.z
  > type pouet = Foo.t
  > include Foo
  > EOF

  $ cat >foo.ml <<EOF
  > type t
  > let x = 42
  > let y = 36 + Bar.z + x
  > EOF

  $ cat >bar.ml <<EOF
  > let z = 42
  > EOF

  $ ocamlc -bin-annot -c bar.ml foo.ml main.ml

  $ ocaml-uideps process-cmt main.cmt foo.cmt bar.cmt

  $ ocaml-uideps dump main.uideps
  {uid: Foo; locs: File "main.ml", line 4, characters 8-11
   uid: Foo.1; locs: File "main.ml", line 1, characters 8-13
   uid: Foo.2; locs: File "main.ml", line 1, characters 16-21;
                     File "main.ml", line 2, characters 8-13
   uid: Bar.0; locs: File "main.ml", line 2, characters 16-21
   uid: Stdlib.48; locs: File "main.ml", line 1, characters 14-15;
                         File "main.ml", line 2, characters 14-15
   uid: Foo.0; locs: File "main.ml", line 3, characters 13-18}

  $ ocaml-uideps dump foo.uideps
  {uid: Foo.1; locs: File "foo.ml", line 3, characters 21-22
   uid: Bar.0; locs: File "foo.ml", line 3, characters 13-18
   uid: Stdlib.48; locs: File "foo.ml", line 3, characters 11-12;
                         File "foo.ml", line 3, characters 19-20
   }

  $ ocaml-uideps dump bar.uideps
  {}

  $ ocaml-uideps aggregate main.uideps foo.uideps bar.uideps

  $ ocaml-uideps dump workspace.uideps
  {uid: Foo.2; locs: File "main.ml", line 1, characters 16-21;
                     File "main.ml", line 2, characters 8-13
   uid: Foo.0; locs: File "main.ml", line 3, characters 13-18
   uid: Foo; locs: File "main.ml", line 4, characters 8-11
   uid: Foo.1; locs: File "foo.ml", line 3, characters 21-22;
                     File "main.ml", line 1, characters 8-13
   uid: Bar.0; locs: File "foo.ml", line 3, characters 13-18;
                     File "main.ml", line 2, characters 16-21
   uid: Stdlib.48; locs: File "foo.ml", line 3, characters 11-12;
                         File "foo.ml", line 3, characters 19-20;
                         File "main.ml", line 1, characters 14-15;
                         File "main.ml", line 2, characters 14-15
   }
