module Lid : Set.OrderedType with type t = Longident.t Location.loc = struct
  type t = Longident.t Location.loc

  let compare_pos (p1 : Lexing.position) (p2 : Lexing.position) =
    match String.compare p1.pos_fname p2.pos_fname with
    | 0 -> Int.compare p1.pos_cnum p2.pos_cnum
    | n -> n

  let compare (t1 : t) (t2 : t) =
    (* TODO CHECK...*)
    match compare_pos t1.loc.loc_start t2.loc.loc_start with
    | 0 -> compare_pos t1.loc.loc_end t2.loc.loc_end
    | n -> n
end

module LidSet = Set.Make (Lid)

type payload = {
  defs : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  partial : (Longident.t Location.loc * Shape.t * Env.t) list;
  load_path : string list;
}

type file_format = V1 of payload

let pp_payload (fmt : Format.formatter) pl =
  Format.fprintf fmt "{@[";
  Hashtbl.iter
    (fun uid locs ->
      Format.fprintf fmt "@[<hov 2>uid: %a; locs:@ @[<v>%a@]@]@;"
        Shape.Uid.print uid
        (Format.pp_print_list
           ~pp_sep:(fun fmt () -> Format.fprintf fmt ";@;")
           (fun fmt { Location.txt; loc } ->
             Format.fprintf fmt "%S: %a"
               (Longident.flatten txt |> String.concat ".")
               Location.print_loc loc))
        (LidSet.elements locs))
    pl.defs;
  Format.fprintf fmt "@]}@,";
  Format.fprintf fmt "And %i partial shapes.\n" (List.length pl.partial);
  Format.(
    fprintf fmt "With load_path: [%a]"
      (pp_print_list ~pp_sep:pp_force_newline pp_print_string)
      pl.load_path)

let pp (fmt : Format.formatter) ff =
  match ff with V1 tbl -> Format.fprintf fmt "V1@,%a" pp_payload tbl

let ext = "uideps"

let write ~file tbl =
  let oc = open_out_bin file in
  Marshal.to_channel oc (V1 tbl) [];
  close_out oc

let read ~file =
  let ic = open_in_bin file in
  try
    let payload =
      match Marshal.from_channel ic with V1 payload -> payload
      (* TODO is that "safe" ? We probably want some magic number *)
    in
    close_in ic;
    payload
  with e -> raise e (* todo *)
