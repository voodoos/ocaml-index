module LidSet : Set.S with type elt = Longident.t Location.loc

type payload = {
  defs : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  partial : (Longident.t Location.loc * Shape.t * Env.t) list;
  load_path : string list;
}

type file_format = V1 of payload

val pp_payload : Format.formatter -> payload -> unit
val pp : Format.formatter -> file_format -> unit
val ext : string
val write : file:string -> payload -> unit
val read : file:string -> payload
