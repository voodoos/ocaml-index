  $ cat >main.ml <<EOF
  > let x = List.init Foo.x (fun n -> n)
  > EOF

  $ mkdir lib1
  $ cat >lib1/foo.ml <<EOF
  > include Bar
  > EOF

  $ mkdir lib2
  $ cat >lib2/bar.ml <<EOF
  > let x = 21
  > EOF

  $ ocamlc -bin-annot -c lib2/bar.ml
  $ ocamlc -bin-annot -c lib1/foo.ml -I lib2

# Here we have an implicit transitive dependency on lib2:
  $ ocamlc -bin-annot -c main.ml -I lib1 -I /Users/ulysse/tmp/occurrences/_opam/lib/fpath

# We pass explicitely the implicit transitive dependency over lib2:
  $ ocaml-uideps process-cmt -o main.uideps main.cmt lib2
  $ ocaml-uideps process-cmt -o lib1/foo.uideps lib1/foo.cmt
  $ ocaml-uideps process-cmt -o lib2/bar.uideps lib2/bar.cmt

  $ ocaml-uideps aggregate -o test.uideps main.uideps lib1/foo.uideps lib2/bar.uideps

  $ ocaml-uideps dump main.uideps
  2 uids:
  {uid: Main.1; locs: "n": File "main.ml", line 1, characters 34-35
   uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5 },
  0 partial shapes: {}, 2 unreduced shapes:
  {shape: CU Foo . "x"[value] ; locs:
     Foo.x: File "main.ml", line 1, characters 18-23
   shape: CU Stdlib . "List"[module] . "init"[value] ; locs:
     List.init: File "main.ml", line 1, characters 8-17
   } and shapes for CUS Main.

  $ ocaml-uideps dump lib1/foo.uideps
  0 uids: {}, 0 partial shapes: {}, 1 unreduced shapes:
  {shape: CU Bar ; locs: Bar: File "lib1/foo.ml", line 1, characters 8-11 }
  and shapes for CUS Foo.

  $ ocaml-uideps dump test.uideps
  5 uids:
  {uid: Stdlib__List.45; locs:
     "List.init": File "main.ml", line 1, characters 8-17
   uid: Main.0; locs: "x": File "main.ml", line 1, characters 4-5
   uid: Main.1; locs: "n": File "main.ml", line 1, characters 34-35
   uid: Bar.0; locs:
     "x": File "lib2/bar.ml", line 1, characters 4-5;
     "Foo.x": File "main.ml", line 1, characters 18-23
   uid: Bar; locs: "Bar": File "lib1/foo.ml", line 1, characters 8-11 },
  0 partial shapes: {}, 0 unreduced shapes: {} and shapes for CUS .

