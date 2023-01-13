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

  $ ocaml-uideps process-cmt -o main.uideps main.cmt
  INSTRVAL x Main.0
  INSTRVAL y Main.1
  $ ocaml-uideps process-cmt -o foo.uideps foo.cmt
  INSTRVAL x Foo.1
  INSTRVAL y Foo.2
  $ ocaml-uideps process-cmt -o bar.uideps bar.cmt
  INSTRVAL z Bar.0

  $ ocaml-uideps aggregate -o test.uideps main.uideps foo.uideps bar.uideps

FIXME: Main.0 and Main.1 are not exposed, it is useless to register them
  $ ocaml-uideps dump main.uideps
  {uid: Main.1; locs: "y": File "main.ml", line 2, characters 4-5
   uid: Main.2; locs: "pouet": File "main.ml", line 3, characters 5-10
   uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5 }
  And 8 partial shapes.

  $ ocaml-uideps dump foo.uideps
  {uid: Foo.1; locs: "x": File "foo.ml", line 2, characters 4-5
   uid: Foo.2; locs: "y": File "foo.ml", line 3, characters 4-5
   uid: Foo.0; locs: "t": File "foo.ml", line 1, characters 5-6 }
  And 4 partial shapes.

  $ ocaml-uideps dump test.uideps
  {uid: Foo.2; locs:
     "y": File "foo.ml", line 3, characters 4-5;
     "Foo.y": File "main.ml", line 1, characters 16-21;
     "Foo.y": File "main.ml", line 2, characters 8-13
   uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5
   uid: Foo.0; locs:
     "t": File "foo.ml", line 1, characters 5-6;
     "Foo.t": File "main.ml", line 3, characters 13-18
   uid: Foo; locs: "Foo": File "main.ml", line 4, characters 8-11
   uid: Main.1; locs: "y": File "main.ml", line 2, characters 4-5
   uid: Foo.1; locs:
     "x": File "foo.ml", line 2, characters 4-5;
     "x": File "foo.ml", line 3, characters 21-22;
     "Foo.x": File "main.ml", line 1, characters 8-13
   uid: Bar.0; locs:
     "z": File "bar.ml", line 1, characters 4-5;
     "Bar.z": File "foo.ml", line 3, characters 13-18;
     "Bar.z": File "main.ml", line 2, characters 16-21
   uid: Stdlib.55; locs:
     "+": File "foo.ml", line 3, characters 11-12;
     "+": File "foo.ml", line 3, characters 19-20;
     "+": File "main.ml", line 1, characters 14-15;
     "+": File "main.ml", line 2, characters 14-15
   uid: Main.2; locs: "pouet": File "main.ml", line 3, characters 5-10 }
  And 0 partial shapes.

