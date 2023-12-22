  $ cat >main.ml <<EOF
  > let x = Foo.x + Foo.y
  > let y = Foo.y + Bar.z
  > type pouet = Foo.t
  > let _, z = let x = 1 in x + y, 42
  > module A = struct 
  >   let ina = 42
  >   let _ = ina
  > end
  > let _ = A.ina
  > module _ = Foo
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

  $ ocamlc -bin-annot -bin-annot-occurrences -c bar.ml foo.ml main.ml

  $ ocaml-index aggregate -o main.uideps main.cmt
  $ ocaml-index aggregate -o foo.uideps foo.cmt
  $ ocaml-index aggregate -o bar.uideps bar.cmt

  $ ocaml-index dump main.uideps
  9 uids:
  {uid: Foo.2; locs:
     "Foo.y": File "main.ml", line 1, characters 16-21;
     "Foo.y": File "main.ml", line 2, characters 8-13
   uid: Main.4; locs: "x": File "main.ml", line 4, characters 24-25
   uid: Foo.0; locs: "Foo.t": File "main.ml", line 3, characters 13-18
   uid: Foo; locs:
     "Foo": File "main.ml", line 10, characters 11-14;
     "Foo": File "main.ml", line 11, characters 8-11
   uid: Main.5; locs:
     "ina": File "main.ml", line 7, characters 10-13;
     "A.ina": File "main.ml", line 9, characters 8-13
   uid: Main.1; locs: "y": File "main.ml", line 4, characters 28-29
   uid: Foo.1; locs: "Foo.x": File "main.ml", line 1, characters 8-13
   uid: Bar.0; locs: "Bar.z": File "main.ml", line 2, characters 16-21
   uid: Stdlib.55; locs:
     "+": File "main.ml", line 1, characters 14-15;
     "+": File "main.ml", line 2, characters 14-15;
     "+": File "main.ml", line 4, characters 26-27
   }, 0 approx shapes: {}, and shapes for CUS .

  $ ocaml-index dump foo.uideps
  3 uids:
  {uid: Foo.1; locs: "x": File "foo.ml", line 3, characters 21-22
   uid: Bar.0; locs: "Bar.z": File "foo.ml", line 3, characters 13-18
   uid: Stdlib.55; locs:
     "+": File "foo.ml", line 3, characters 11-12;
     "+": File "foo.ml", line 3, characters 19-20
   }, 0 approx shapes: {}, and shapes for CUS .



  $ ocaml-index -o test.uideps main.cmt foo.cmt bar.cmt
  $ ocaml-index dump test.uideps
  9 uids:
  {uid: Foo.2; locs:
     "Foo.y": File "main.ml", line 1, characters 16-21;
     "Foo.y": File "main.ml", line 2, characters 8-13
   uid: Main.4; locs: "x": File "main.ml", line 4, characters 24-25
   uid: Foo.0; locs: "Foo.t": File "main.ml", line 3, characters 13-18
   uid: Foo; locs:
     "Foo": File "main.ml", line 10, characters 11-14;
     "Foo": File "main.ml", line 11, characters 8-11
   uid: Main.5; locs:
     "ina": File "main.ml", line 7, characters 10-13;
     "A.ina": File "main.ml", line 9, characters 8-13
   uid: Main.1; locs: "y": File "main.ml", line 4, characters 28-29
   uid: Foo.1; locs:
     "x": File "foo.ml", line 3, characters 21-22;
     "Foo.x": File "main.ml", line 1, characters 8-13
   uid: Bar.0; locs:
     "Bar.z": File "foo.ml", line 3, characters 13-18;
     "Bar.z": File "main.ml", line 2, characters 16-21
   uid: Stdlib.55; locs:
     "+": File "foo.ml", line 3, characters 11-12;
     "+": File "foo.ml", line 3, characters 19-20;
     "+": File "main.ml", line 1, characters 14-15;
     "+": File "main.ml", line 2, characters 14-15;
     "+": File "main.ml", line 4, characters 26-27
   }, 0 approx shapes: {}, and shapes for CUS .

