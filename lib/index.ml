open Import
module MA = Merlin_analysis
open Merlin_index_format.Index_format
module Kind = Shape.Sig_component_kind

type typedtree =
  | Interface of Typedtree.signature
  | Implementation of Typedtree.structure

let with_root ?root file =
  match root with None -> file | Some root -> Filename.concat root file

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

module Reduce = Shape_reduce.Make (struct
  let fuel = 10

  let try_load ~unit_name () =
    let cmt = Format.sprintf "%s.cmt" unit_name in
    match Cmt_cache.read (Load_path.find_normalized cmt) with
    | cmt_item ->
        Log.debug "Loaded CMT %s" cmt;
        cmt_item.cmt_infos.cmt_impl_shape
    | (exception Not_found) ->
        Log.warn "Failed to load file %S in load_path: @[%s@]\n%!" cmt
        @@ String.concat "; " (Load_path.get_path_list ());
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
    cmt_sourcefile;
    cmt_source_digest;
    _;
  } =
    cmt_infos
  in
  Ocaml_utils.Local_store.with_store (Ocaml_utils.Local_store.fresh ())
    (fun () ->
      let visible = List.concat [ cmt_loadpath.visible; build_path ] in
      Load_path.(init ~auto_include:Load_path.no_auto_include ~visible ~hidden:cmt_loadpath.hidden);
      let defs = Hashtbl.create 64 in
      if Option.is_some cmt_impl_shape then
        add_locs_from_fragments ~root defs cmt_uid_to_decl;
      let approximated = Hashtbl.create 64 in
      List.iter
        (fun (lid, (item : Shape_reduce.result)) ->
          let lid = add_root ~root lid in
          let resolved = match item with
            | Unresolved shape -> Reduce.reduce_for_uid cmt_initial_env shape
            | result -> result
          in
          match MA.Locate.uid_of_result ~traverse_aliases:false resolved with
          | Some uid, false -> add defs uid (LidSet.singleton lid)
          | Some uid, true -> add approximated uid (LidSet.singleton lid)
          | None, _ -> ())
        cmt_ident_occurrences;
      let cu_shape = Hashtbl.create 1 in
      Option.iter (Hashtbl.add cu_shape cmt_modname) cmt_impl_shape;
      let stats =
        match cmt_sourcefile with
        | None -> Stats.empty
        | Some src -> (
            let src = with_root ?root src in
            try
              let stats = Unix.stat src in
              Stats.singleton src
                {
                  mtime = stats.st_mtime;
                  size = stats.st_size;
                  source_digest = cmt_source_digest;
                }
            with Unix.Unix_error _ -> Stats.empty)
      in
      let load_path = Load_path.get_paths () in
      { defs; approximated; load_path; cu_shape; stats })

let merge_index ~store_shapes ~into index =
  merge_tbl index.defs ~into:into.defs;
  merge_tbl index.approximated ~into:into.approximated;
  if store_shapes then
    Hashtbl.add_seq index.cu_shape (Hashtbl.to_seq into.cu_shape);
  {
    into with
    stats = Stats.union (fun _ _f1 _f2 -> None) into.stats index.stats;
  }

let from_files ~store_shapes ~output_file ~root ~build_path files =
  let initial_index =
    {
      defs = Hashtbl.create 256;
      approximated = Hashtbl.create 0;
      load_path = { Load_path.visible = []; hidden = [] };
      cu_shape = Hashtbl.create 64;
      stats = Stats.empty;
    }
  in
  let final_index =
    List.fold_left
      (fun into file ->
        let index =
          match read ~file with
          | Cmt cmt_infos -> index_of_cmt ~root ~build_path cmt_infos
          | Index index -> index
          | Unknown -> failwith "unknown file type"
        in
        merge_index ~store_shapes index ~into)
      initial_index files
  in
  write ~file:output_file final_index
