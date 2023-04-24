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

  $ ocamlc -bin-annot -dshape -c external.ml main.ml
  {<External>
   "equal"[value] -> <External.0>;
   }
  
  {<Main>
   "B"[module] -> {<Main.5>
                   "g"[value] -> <Main.3>;
                   };
   "f"[value] -> <Main.0>;
   }
  

  $ ocaml-uideps process-cmt -o main.uideps main.cmt

  $ ocaml-uideps aggregate -o test.uideps main.uideps

  $ ocaml-uideps dump main.uideps
  0 uids: {}, 0 partial shapes: {}, 6 unreduced shapes:
  {shape: <<predef:bool>> ; locs:
     bool: File "main.ml", line 3, characters 30-34
   shape: <<predef:string>> ; locs:
     string: File "main.ml", line 3, characters 20-26
   shape: <<predef:string>> ; locs:
     string: File "main.ml", line 3, characters 10-16
   shape: <Main.2> ; locs: C.g: File "main.ml", line 9, characters 10-13
   shape: <External.0> ; locs: equal: File "main.ml", line 7, characters 12-17
   shape: CU Stdlib . "String"[module] . "equal"[value] ; locs:
     String.equal: File "main.ml", line 1, characters 8-20
   } and shapes for CUS Main.


  $ ocaml-uideps dump test.uideps
  5 uids:
  {uid: <predef:bool>; locs: "bool": File "main.ml", line 3, characters 30-34
   uid: <predef:string>; locs:
     "string": File "main.ml", line 3, characters 10-16;
     "string": File "main.ml", line 3, characters 20-26
   uid: Main.2; locs: "C.g": File "main.ml", line 9, characters 10-13
   uid: Stdlib__String.188; locs:
     "String.equal": File "main.ml", line 1, characters 8-20
   uid: External.0; locs: "equal": File "main.ml", line 7, characters 12-17 },
  0 partial shapes: {}, 0 unreduced shapes: {} and shapes for CUS .

