  $ cat >main.ml <<EOF
  > let f = String.equal
  > module B : sig 
  >   val g : string -> string -> bool
  > end = struct
  >   module C = struct
  >     include External
  >     let g = equal
  >   end
  >   let g = C.g
  > end
  > EOF

  $ cat >external.ml <<EOF
  > let equal = String.equal
  > EOF

  $ ocamlc -bin-annot -c external.ml main.ml

  $ ocaml-uideps process-cmt -o main.uideps main.cmt

  $ ocaml-uideps aggregate -o test.uideps main.uideps

  $ ocaml-uideps dump main.uideps
  9 uids:
  {uid: <predef:string>; locs:
     "string": File "main.ml", line 3, characters 10-16;
     "string": File "main.ml", line 3, characters 20-26
   uid: External.0; locs: "equal": File "external.ml", line 1, characters 4-9
   uid: Main.5; locs: "B": File "main.ml", line 2, characters 7-8
   uid: Main.1; locs:
     "g": File "main.ml", line 7, characters 8-9;
     "C.g": File "main.ml", line 9, characters 10-13
   uid: Main.0; locs: "f": File "main.ml", line 1, characters 4-5
   uid: Main.3; locs: "g": File "main.ml", line 9, characters 6-7
   uid: Main.2; locs: "C": File "main.ml", line 5, characters 9-10
   uid: Main.4; locs: "g": File "main.ml", line 3, characters 6-7
   uid: <predef:bool>; locs: "bool": File "main.ml", line 3, characters 30-34 },
  0 partial shapes: {}, 4 unreduced shapes:
  {shape: CU External . "equal"[value] ; locs:
     equal: File "main.ml", line 7, characters 12-17
   shape: CU External ; locs:
     External: File "main.ml", line 6, characters 12-20
   shape: CU Stdlib . "String"[module] . "equal"[value] ; locs:
     String.equal: File "main.ml", line 1, characters 8-20
   shape: CU Stdlib . "String"[module] . "equal"[value] ; locs:
     String.equal: File "external.ml", line 1, characters 12-24
   } and shapes for CUS Main.


  $ ocaml-uideps dump test.uideps
  11 uids:
  {uid: Stdlib__String.173; locs:
     "String.equal": File "external.ml", line 1, characters 12-24;
     "String.equal": File "main.ml", line 1, characters 8-20
   uid: Main.3; locs: "g": File "main.ml", line 9, characters 6-7
   uid: Main.4; locs: "g": File "main.ml", line 3, characters 6-7
   uid: Main.0; locs: "f": File "main.ml", line 1, characters 4-5
   uid: External; locs: "External": File "main.ml", line 6, characters 12-20
   uid: <predef:bool>; locs: "bool": File "main.ml", line 3, characters 30-34
   uid: <predef:string>; locs:
     "string": File "main.ml", line 3, characters 10-16;
     "string": File "main.ml", line 3, characters 20-26
   uid: Main.5; locs: "B": File "main.ml", line 2, characters 7-8
   uid: Main.1; locs:
     "g": File "main.ml", line 7, characters 8-9;
     "C.g": File "main.ml", line 9, characters 10-13
   uid: Main.2; locs: "C": File "main.ml", line 5, characters 9-10
   uid: External.0; locs:
     "equal": File "external.ml", line 1, characters 4-9;
     "equal": File "main.ml", line 7, characters 12-17
   }, 0 partial shapes: {}, 0 unreduced shapes: {} and shapes for CUS .

