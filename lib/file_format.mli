open Import
module LidSet : Set.S with type elt = Longident.t Location.loc

type index = {
  defs : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  approximated : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  unresolved : (Longident.t Location.loc * Shape.t) list;
  load_path : string list;
  cu_shape : (string, Shape.t) Hashtbl.t;
}

type file_format = V1 of index

val pp_payload : Format.formatter -> index -> unit
val pp : Format.formatter -> file_format -> unit
val ext : string
val write : file:string -> index -> unit
val read : file:string -> index
