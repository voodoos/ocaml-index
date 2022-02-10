module Loc : Set.OrderedType with type t = Location.t = struct
  type t = Location.t

  let compare_pos (p1 : Lexing.position) (p2 : Lexing.position) =
    match String.compare p1.pos_fname p2.pos_fname with
    | 0 -> Int.compare p1.pos_cnum p2.pos_cnum
    | n -> n

  let compare (t1 : t) (t2 : t) =
    (* TODO CHECK...*)
    match compare_pos t1.loc_start t2.loc_start with
    | 0 -> compare_pos t1.loc_end t2.loc_end
    | n -> n
end

module LocSet = Set.Make (Loc)

type payload = (Shape.Uid.t, LocSet.t) Hashtbl.t
type file_format = V1 of payload

let pp_payload (fmt : Format.formatter) pl =
  Format.fprintf fmt "{@[";
  Hashtbl.iter
    (fun uid locs -> Format.fprintf fmt "uid: %a; locs: @[%a@]@,"
      Shape.Uid.print uid
      (Format.pp_print_list
        ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@;")
        Location.print_loc) (LocSet.elements locs))
    pl;
    Format.fprintf fmt "@]}@,"

let pp (fmt : Format.formatter) ff =
  match ff with
  | V1 tbl ->
    Format.fprintf fmt "V1@,%a" pp_payload tbl

let ext = "uideps"

let write ~file tbl =
    let oc = open_out_bin file in
    Marshal.to_channel oc (V1 tbl) [];
    close_out oc

let read ~file =
  let ic = open_in_bin file in
  try
    let payload = match Marshal.from_channel ic with
      | V1 payload -> payload (* TODO is that "safe" ? *)
    in
    close_in ic;
    payload
  with e -> raise e (* todo *)
