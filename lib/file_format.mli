module LocSet : Set.S with type elt = Location.t

type payload = (Shape.Uid.t, LocSet.t) Hashtbl.t
type file_format = V1 of payload

val pp_payload : Format.formatter -> payload -> unit
val pp : Format.formatter -> file_format -> unit

val ext : string

val write : file:string -> payload -> unit
val read : file:string -> payload
