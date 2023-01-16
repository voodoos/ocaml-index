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

  $ ocamlc -bin-annot -dshape -c bar.ml foo.ml main.ml
  {<Bar>
   "z"[value] -> <Bar.0>;
   }
  
  {<Foo>
   "t"[type] -> <Foo.0>;
   "x"[value] -> <Foo.1>;
   "y"[value] -> <Foo.2>;
   }
  
  {<Main>
   "A"[module] -> {<Main.6>
                   "ina"[value] -> <Main.5>;
                   };
   "pouet"[type] -> <Main.2>;
   "t"[type] -> CU Foo . "t"[type];
   "x"[value] -> CU Foo . "x"[value];
   "y"[value] -> CU Foo . "y"[value];
   "z"[value] -> <Main.3>;
   }
  

  $ ocaml-uideps process-cmt -o main.uideps main.cmt
  $ ocaml-uideps process-cmt -o foo.uideps foo.cmt
  $ ocaml-uideps process-cmt -o bar.uideps bar.cmt

  $ ocaml-uideps aggregate -o test.uideps main.uideps foo.uideps bar.uideps

  $ ocaml-uideps dump main.uideps
  {uid: Main.5; locs: "ina": File "main.ml", line 6, characters 6-9
   uid: Main.3; locs: "z": File "main.ml", line 4, characters 7-8
   uid: Main.2; locs: "pouet": File "main.ml", line 3, characters 5-10 }
  And 10 partial shapes.

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
   uid: Main.3; locs: "z": File "main.ml", line 4, characters 7-8
   uid: Foo.0; locs:
     "t": File "foo.ml", line 1, characters 5-6;
     "Foo.t": File "main.ml", line 3, characters 13-18
   uid: Main.5; locs:
     "ina": File "main.ml", line 6, characters 6-9;
     "ina": File "main.ml", line 7, characters 10-13;
     "A.ina": File "main.ml", line 9, characters 8-13
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
     "+": File "main.ml", line 2, characters 14-15;
     "+": File "main.ml", line 4, characters 26-27
   uid: Main.2; locs: "pouet": File "main.ml", line 3, characters 5-10 }
  And 0 partial shapes.

