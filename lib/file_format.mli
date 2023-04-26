module LidSet : Set.S with type elt = Longident.t Location.loc

type payload = {
  defs : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  partials : (Shape.t, LidSet.t) Hashtbl.t;
  unreduced : (Shape.t * Longident.t Location.loc) list;
  load_path : string list;
  cu_shape : (string, Shape.t) Hashtbl.t;
}

type file_format = V1 of payload

val pp_payload : Format.formatter -> payload -> unit
val pp : Format.formatter -> file_format -> unit
val ext : string
val write : file:string -> payload -> unit
val read : file:string -> payload
