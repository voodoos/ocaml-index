open Import

exception Not_an_index of string

module LidSet : Set.S with type elt = Longident.t Location.loc

type index = {
  defs : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  approximated : (Shape.Uid.t, LidSet.t) Hashtbl.t;
  unresolved : (Longident.t Location.loc * Shape.t) list;
  load_path : string list;
  cu_shape : (string, Shape.t) Hashtbl.t;
}

val pp : Format.formatter -> index -> unit
val ext : string
val write : file:string -> index -> unit

type file_content =
  | Cmt of Cmt_format.cmt_infos
  | Index of index
  | Unknown

val read : file:string -> file_content
val read_exn : file:string -> index
