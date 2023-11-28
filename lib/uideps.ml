open Import
open File_format
module Kind = Shape.Sig_component_kind

type typedtree =
  | Interface of Typedtree.signature
  | Implementation of Typedtree.structure

let add_root ~root (lid : Longident.t Location.loc) =
  match root with
  | None -> lid
  | Some root ->
      let pos_fname = Filename.concat root lid.loc.loc_start.pos_fname in
      {
        lid with
        loc =
          {
            lid.loc with
            loc_start = { lid.loc.loc_start with pos_fname };
            loc_end = { lid.loc.loc_end with pos_fname };
          };
      }

(** [add tbl uid locs] adds a binding of [uid] to the locations [locs]. If this key is
    already present the locations are merged. *)
let add tbl uid locs =
  try
    let locations = Hashtbl.find tbl uid in
    Hashtbl.replace tbl uid (LidSet.union locs locations)
  with Not_found -> Hashtbl.add tbl uid locs

let merge_tbl ~into tbl = Hashtbl.iter (add into) tbl

module Reduce_common = struct
  type env = Env.t

  let fuel = 10

  let find_shape env id =
    (* Todo: Test when applying functor arg which is in another CU *)
    Env.shape_of_path ~namespace:Shape.Sig_component_kind.Module env (Pident id)
end

module Shape_full_reduce = Shape.Make_reduce (struct
  include Reduce_common

  let try_load ~unit_name () =
    let cmt = Format.sprintf "%s.cmt" unit_name in
    match Cmt_format.read (Load_path.find_uncap cmt) with
    | _, Some cmt_infos ->
        Log.debug "Loaded CMT %s" cmt;
        cmt_infos.cmt_impl_shape
    | _ | (exception Not_found) ->
        Log.warn "Failed to load file %S in load_path: @[%s@]\n%!" cmt
        @@ String.concat "; " (Load_path.get_paths ());
        None

  let read_unit_shape ~unit_name =
    Log.debug "Read unit shape: %s\n%!" unit_name;
    try_load ~unit_name ()
end)

(** Cmt files contains a table of declarations' Uids associated to a typedtree
    fragment. [add_locs_from_fragments] gather locations from these *)
let add_locs_from_fragments ~root tbl fragments =
  let to_located_lid (name : string Location.loc) =
    { name with txt = Longident.Lident name.txt }
  in
  let add_loc uid fragment =
    Merlin_analysis.Misc_utils.loc_of_decl ~uid fragment
    |> Option.iter (fun lid ->
           let lid = add_root ~root (to_located_lid lid) in
           Hashtbl.add tbl uid @@ LidSet.singleton lid)
  in
  Shape.Uid.Tbl.iter add_loc fragments

let index_of_cmt ~root ~build_path cmt_infos =
  let {
    Cmt_format.cmt_loadpath;
    cmt_impl_shape;
    cmt_modname;
    cmt_uid_to_decl;
    cmt_ident_occurrences;
    cmt_initial_env;
    _;
  } =
    cmt_infos
  in
  let keep_aliases = function
    | Shape.
        {
          uid = Some (Item { comp_unit; _ });
          desc = Alias { desc = Comp_unit alias_cu; _ };
          _;
        }
      when let by = comp_unit ^ "__" in
           Merlin_utils.Std.String.is_prefixed ~by alias_cu ->
        false
    | _ -> true
  in
  Ocaml_utils.Local_store.with_store (Ocaml_utils.Local_store.fresh ())
    (fun () ->
      let load_path = List.concat [ cmt_loadpath; build_path ] in
      Load_path.(init load_path);
      let public_shapes = Option.get cmt_impl_shape in
      let defs = Hashtbl.create 64 in
      add_locs_from_fragments ~root defs cmt_uid_to_decl;
      let approximated = Hashtbl.create 64 in
      List.iter
        (fun (lid, (item : Shape.reduction_result)) ->
          let lid = add_root ~root lid in
          match item with
          | Resolved uid -> add defs uid (LidSet.singleton lid)
          | Unresolved shape -> (
              match
                Shape_full_reduce.reduce_for_uid ~keep_aliases cmt_initial_env
                  shape
              with
              | Resolved uid -> add defs uid (LidSet.singleton lid)
              | Approximated (Some uid) ->
                  add approximated uid (LidSet.singleton lid)
              | _ -> ())
          | Approximated (Some uid) ->
              add approximated uid (LidSet.singleton lid)
          | _ -> ())
        cmt_ident_occurrences;
      let cu_shape = Hashtbl.create 1 in
      Hashtbl.add cu_shape cmt_modname public_shapes;
      { defs; approximated; load_path; cu_shape })

let merge_index ~store_shapes ~into index =
  merge_tbl index.defs ~into:into.defs;
  merge_tbl index.approximated ~into:into.approximated;

  if store_shapes then
    Hashtbl.add_seq index.cu_shape (Hashtbl.to_seq into.cu_shape)

let from_files ~store_shapes ~output_file ~root ~build_path files =
  let final_index =
    {
      defs = Hashtbl.create 256;
      approximated = Hashtbl.create 0;
      load_path = [];
      cu_shape = Hashtbl.create 64;
    }
  in
  List.iter
    (fun file ->
      let index =
        match File_format.read ~file with
        | Cmt cmt_infos -> index_of_cmt ~root ~build_path cmt_infos
        | Index index -> index
        | Unknown -> failwith "unknown file type"
      in
      merge_index ~store_shapes index ~into:final_index)
    files;
  File_format.write ~file:output_file final_index
