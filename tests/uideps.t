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

  $ ocaml-uideps process-cmt -o main.uideps main.cmt foo.cmt bar.cmt

  $ ocaml-uideps dump main.uideps
  {uid: Foo.2; locs: File "foo.ml", line 3, characters 4-5;
                     File "main.ml", line 1, characters 16-21;
                     File "main.ml", line 2, characters 8-13
   uid: Main.0; locs: File "main.ml", line 1, characters 4-5
   uid: Foo.0; locs: File "foo.ml", line 1, characters 0-6;
                     File "main.ml", line 3, characters 13-18
   uid: Foo; locs: File "main.ml", line 4, characters 8-11
   uid: Main.1; locs: File "main.ml", line 2, characters 4-5
   uid: Foo.1; locs: File "foo.ml", line 2, characters 4-5;
                     File "foo.ml", line 3, characters 21-22;
                     File "main.ml", line 1, characters 8-13
   uid: Bar.0; locs: File "bar.ml", line 1, characters 4-5;
                     File "foo.ml", line 3, characters 13-18;
                     File "main.ml", line 2, characters 16-21
   uid: Main.2; locs: File "main.ml", line 3, characters 0-18
   uid: Stdlib.55; locs: File "foo.ml", line 3, characters 11-12;
                         File "foo.ml", line 3, characters 19-20;
                         File "main.ml", line 1, characters 14-15;
                         File "main.ml", line 2, characters 14-15
   }
