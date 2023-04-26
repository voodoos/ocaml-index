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

  $ ocamlc -bin-annot -c bar.ml foo.ml main.ml

  $ ocaml-uideps process-cmt -o main.uideps main.cmt
  $ ocaml-uideps process-cmt -o foo.uideps foo.cmt
  $ ocaml-uideps process-cmt -o bar.uideps bar.cmt

  $ ocaml-uideps aggregate -o test.uideps main.uideps foo.uideps bar.uideps

  $ ocaml-uideps dump main.uideps
  11 uids:
  {uid: Main.5; locs:
     "ina": File "main.ml", line 6, characters 6-9;
     "ina": File "main.ml", line 7, characters 10-13;
     "A.ina": File "main.ml", line 9, characters 8-13
   uid: Main.1; locs:
     "y": File "main.ml", line 2, characters 4-5;
     "y": File "main.ml", line 4, characters 28-29
   uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5
   uid: Foo.1; locs:
     "x": File "foo.ml", line 2, characters 4-5;
     "x": File "foo.ml", line 3, characters 21-22
   uid: Foo.2; locs: "y": File "foo.ml", line 3, characters 4-5
   uid: Main.3; locs: "z": File "main.ml", line 4, characters 7-8
   uid: Bar.0; locs: "z": File "bar.ml", line 1, characters 4-5
   uid: Main.2; locs: "pouet": File "main.ml", line 3, characters 5-10
   uid: Main.6; locs: "A": File "main.ml", line 5, characters 7-8
   uid: Main.4; locs:
     "x": File "main.ml", line 4, characters 15-16;
     "x": File "main.ml", line 4, characters 24-25
   uid: Foo.0; locs: "t": File "foo.ml", line 1, characters 5-6 },
  0 partial shapes: {}, 13 unreduced shapes:
  {shape: CU Foo ; locs: Foo: File "main.ml", line 11, characters 8-11
   shape: CU Foo ; locs: Foo: File "main.ml", line 10, characters 11-14
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "main.ml", line 4, characters 26-27
   shape: CU Foo . "t"[type] ; locs:
     Foo.t: File "main.ml", line 3, characters 13-18
   shape: CU Bar . "z"[value] ; locs:
     Bar.z: File "main.ml", line 2, characters 16-21
   shape: CU Foo . "y"[value] ; locs:
     Foo.y: File "main.ml", line 2, characters 8-13
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "main.ml", line 2, characters 14-15
   shape: CU Foo . "y"[value] ; locs:
     Foo.y: File "main.ml", line 1, characters 16-21
   shape: CU Foo . "x"[value] ; locs:
     Foo.x: File "main.ml", line 1, characters 8-13
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "main.ml", line 1, characters 14-15
   shape: CU Bar . "z"[value] ; locs:
     Bar.z: File "foo.ml", line 3, characters 13-18
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "foo.ml", line 3, characters 11-12
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "foo.ml", line 3, characters 19-20
   } and shapes for CUS Main.

  $ ocaml-uideps dump foo.uideps
  4 uids:
  {uid: Foo.1; locs:
     "x": File "foo.ml", line 2, characters 4-5;
     "x": File "foo.ml", line 3, characters 21-22
   uid: Foo.2; locs: "y": File "foo.ml", line 3, characters 4-5
   uid: Bar.0; locs: "z": File "bar.ml", line 1, characters 4-5
   uid: Foo.0; locs: "t": File "foo.ml", line 1, characters 5-6 },
  0 partial shapes: {}, 3 unreduced shapes:
  {shape: CU Bar . "z"[value] ; locs:
     Bar.z: File "foo.ml", line 3, characters 13-18
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "foo.ml", line 3, characters 11-12
   shape: CU Stdlib . "+"[value] ; locs:
     +: File "foo.ml", line 3, characters 19-20
   } and shapes for CUS Foo.

  $ ocaml-uideps dump test.uideps
  13 uids:
  {uid: Foo.2; locs:
     "y": File "foo.ml", line 3, characters 4-5;
     "Foo.y": File "main.ml", line 1, characters 16-21;
     "Foo.y": File "main.ml", line 2, characters 8-13
   uid: Main.3; locs: "z": File "main.ml", line 4, characters 7-8
   uid: Main.6; locs: "A": File "main.ml", line 5, characters 7-8
   uid: Main.4; locs:
     "x": File "main.ml", line 4, characters 15-16;
     "x": File "main.ml", line 4, characters 24-25
   uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5
   uid: Stdlib.53; locs:
     "+": File "foo.ml", line 3, characters 11-12;
     "+": File "foo.ml", line 3, characters 19-20;
     "+": File "main.ml", line 1, characters 14-15;
     "+": File "main.ml", line 2, characters 14-15;
     "+": File "main.ml", line 4, characters 26-27
   uid: Foo.0; locs:
     "t": File "foo.ml", line 1, characters 5-6;
     "Foo.t": File "main.ml", line 3, characters 13-18
   uid: Foo; locs:
     "Foo": File "main.ml", line 10, characters 11-14;
     "Foo": File "main.ml", line 11, characters 8-11
   uid: Main.5; locs:
     "ina": File "main.ml", line 6, characters 6-9;
     "ina": File "main.ml", line 7, characters 10-13;
     "A.ina": File "main.ml", line 9, characters 8-13
   uid: Main.1; locs:
     "y": File "main.ml", line 2, characters 4-5;
     "y": File "main.ml", line 4, characters 28-29
   uid: Foo.1; locs:
     "x": File "foo.ml", line 2, characters 4-5;
     "x": File "foo.ml", line 3, characters 21-22;
     "Foo.x": File "main.ml", line 1, characters 8-13
   uid: Bar.0; locs:
     "z": File "bar.ml", line 1, characters 4-5;
     "Bar.z": File "foo.ml", line 3, characters 13-18;
     "Bar.z": File "main.ml", line 2, characters 16-21
   uid: Main.2; locs: "pouet": File "main.ml", line 3, characters 5-10 },
  0 partial shapes: {}, 0 unreduced shapes: {} and shapes for CUS .

