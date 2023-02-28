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

let add tbl uid locs =
  try
    let locations = Hashtbl.find tbl uid in
    Hashtbl.replace tbl uid (LidSet.union locs locations)
  with Not_found -> Hashtbl.add tbl uid locs

let merge_tbl ~into tbl = Hashtbl.iter (add into) tbl

let rebuild_env env =
  try Envaux.env_of_only_summary env
  with Envaux.Error e ->
    Log.warn "Error while trying to rebuild env from summary: %a\n%!"
      Envaux.report_error e;
    env

module Reduce_common = struct
  type env = Env.t

  let fuel = 10

  let find_shape env id =
    Env.shape_of_path ~namespace:Shape.Sig_component_kind.Module env (Pident id)
end

module Shape_full_reduce = Shape_reduce.Make_reduce (struct
  include Reduce_common

  let rec try_load ~unit_name ?(ext = "cmt") () =
    let cmt = String.concat "." [ unit_name; ext ] in
    match Load_path.find_uncap cmt with
    | cmt_path -> (
        match Cmt_format.read cmt_path with
        | _, Some cmt_infos -> cmt_infos.cmt_impl_shape
        | _, None ->
            Log.error "Cannot read cmt file %s." cmt;
            None)
    | exception Not_found ->
        (* todo: clarify cmt / cmti distinction *)
        if ext = "cmt" then (
          Log.debug "Failed to load cmt: %s, attempting cmti" cmt;
          try_load ~unit_name ~ext:"cmti" ())
        else (
          Log.error "Failed to load cmt(i): %s in load_path: [%s]" cmt
          @@ String.concat ":\n" (Load_path.get_paths ());
          None)

  let read_unit_shape ~unit_name =
    Log.debug "Read unit shape: %s\n%!" unit_name;
    try_load ~unit_name ()

  let find_shape env id =
    (* When partial reduction is performed only the summary of the env is stored
       on the filesystem. We need to reconstitute the complete envoronment but we do it only if we need it. *)
    let env = rebuild_env env in
    find_shape env id
end)

module Shape_local_reduce = Shape_reduce.Make_reduce (struct
  include Reduce_common

  let read_unit_shape ~unit_name:_ = None
end)

(* Storing locations of values whose definitions are not exposed by the current
   compilation unit is wasteful. As a first approximation we simply look if the
   defnition's shape is part of the public shapes stored in the CMT. *)
let is_exposed ~public_shapes =
  let open Shape in
  (* We gather (once) the uids of all leaf in the public shapes *)
  let rec aux acc = function
    | { desc = Leaf; uid = Some uid } -> Uid.Map.add uid () acc
    | { desc = Struct map; _ } ->
        Item.Map.fold (fun _item shape acc -> aux acc shape) map acc
    | _ -> acc
  in
  let public_uids = aux Uid.Map.empty public_shapes in
  (* If the tested shape is a leaf we check if its uid is public *)
  function
  | { desc = Leaf; uid = Some uid } -> Uid.Map.mem uid public_uids
  | _ -> true (* in doubt, store it *)

(** [gather_shapes] iterates on the Typedtree and reduce the shape of every type
    and value to add them to the index. *)
let gather_shapes ~root ~is_exposed _defs tree =
  Log.debug "Gather SHAPES";
  (* Todo: handle error even if it should not happen *)
  let shapes = ref [] in
  let iterator =
    let register_loc ~env ~lid shape =
      let lid = add_root ~root lid in
      let shape = Shape_local_reduce.weak_reduce env shape in
      let summary = Env.keep_only_summary env in
      shapes := (lid, shape, summary) :: !shapes
    in
    {
      Tast_iterator.default_iterator with
      expr =
        (fun sub ({ exp_desc; exp_env; _ } as e) ->
          (match exp_desc with
          | Texp_ident (path, lid, _) -> (
              try
                let env = rebuild_env exp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Value env path in
                if is_exposed shape then register_loc ~env ~lid shape
              with Not_found ->
                Log.warn "No shape for expr %a at %a" Path.print path
                  Location.print_loc lid.loc)
          | _ -> ());
          Tast_iterator.default_iterator.expr sub e);
      (* Only types and values are indexed right now *)
      typ =
        (fun sub ({ ctyp_desc; ctyp_env; _ } as me) ->
          (match ctyp_desc with
          | Ttyp_constr (path, lid, _ctyps) -> (
              try
                let env = rebuild_env ctyp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Type env path in
                if is_exposed shape then register_loc ~env ~lid shape
              with Not_found ->
                Log.warn "No shape for type %a at %a" Path.print path
                  Location.print_loc lid.loc)
          | _ -> ());
          Tast_iterator.default_iterator.typ sub me);
    }
  in
  (match tree with
  | Interface signature -> iterator.signature iterator signature
  | Implementation structure -> iterator.structure iterator structure);
  !shapes

let get_typedtree (cmt_infos : Cmt_format.cmt_infos) =
  Log.debug "get Typedtree\n%!";
  match cmt_infos.cmt_annots with
  | Interface s ->
      Log.debug "Interface\n%!";
      let sig_final_env = rebuild_env s.sig_final_env in
      Some (Interface { s with sig_final_env }, sig_final_env)
  | Implementation str ->
      Log.debug "Implementation\n%!";
      let str_final_env = rebuild_env str.str_final_env in
      Some (Implementation { str with str_final_env }, str_final_env)
  | _ ->
      Log.debug "No typedtree\n%!";
      None

(** Cmt files contains a table of declarations' Uids associated to a typedtree
    fragment. [from_fragments] gather locations from these *)
let from_fragments ~root ~is_exposed tbl fragments =
  let of_option name =
    match name.Location.txt with
    | Some txt -> Some { name with txt }
    | None -> None
  in
  let get_loc = function
    | Cmt_format.Class_declaration cd -> Some cd.ci_id_name
    | Class_description cd -> Some cd.ci_id_name
    | Class_type_declaration ctd -> Some ctd.ci_id_name
    | Extension_constructor ec -> Some ec.ext_name
    | Module_binding mb -> of_option mb.mb_name
    | Module_declaration md -> of_option md.md_name
    | Tmodule_declaration (_, name) -> of_option name
    | Module_type_declaration mtd -> Some mtd.mtd_name
    | Type_declaration td -> Some td.typ_name
    | Value_description vd -> Some vd.val_name
    | Tvalue_description (_, name) -> of_option name
  in
  let to_located_lid (name : string Location.loc) =
    { name with txt = Longident.Lident name.txt }
  in
  Shape.Uid.Tbl.iter
    (fun uid fragment ->
      if is_exposed @@ Shape.leaf uid then
        match get_loc fragment |> Option.map to_located_lid with
        | Some lid ->
            let lid = add_root ~root lid in
            Hashtbl.add tbl uid @@ LidSet.singleton lid
        | None -> ())
    fragments

let list_preppend_uniq l1 l2 =
  let rec aux acc = function
    | [] -> List.rev_append acc l1
    | h :: tl when List.mem h l1 -> aux acc tl
    | h :: tl -> aux (h :: acc) tl
  in
  aux [] l2

let generate_one ~root ~build_path input_file =
  Log.debug "Gather uids from %s\n%!" input_file;
  match Cmt_format.read input_file with
  | _, Some cmt_infos -> (
      let load_path = list_preppend_uniq build_path cmt_infos.cmt_loadpath in
      Load_path.init load_path;
      match get_typedtree cmt_infos with
      | Some (tree, _) ->
          let defs = Hashtbl.create 128 in
          let public_shapes = Option.get cmt_infos.cmt_impl_shape in
          let is_exposed = is_exposed ~public_shapes in
          from_fragments ~root ~is_exposed defs cmt_infos.cmt_uid_to_loc;
          let partial_shapes = gather_shapes ~root ~is_exposed defs tree in
          Some { defs; partial = partial_shapes; load_path }
      | None -> (* todo log error *) None)
  | _, _ -> (* todo log error *) None

(** [generate ~root ~output_file ~build_path cmt] indexes the cmt [cmt] by
      iterating on its [Typedtree] and reducing partially the shapes of every
      value.
    - In most cases (implicit transitive deps, externally installed libs) the [build_path] should contain the transitive closure of all dependencies of the unit
    - If [root] is provided all location paths will be made absolute *)
let generate ~root ~output_file ~build_path cmt =
  let payload =
    match generate_one ~root ~build_path cmt with
    | Some pl -> pl
    | None -> { defs = Hashtbl.create 0; partial = []; load_path = [] }
  in
  Log.debug "Writing to %s\n%!" output_file;
  File_format.write ~file:output_file payload

let aggregate ~output_file =
  let tbl = Hashtbl.create 256 in
  let merge_file file =
    let pl = File_format.read ~file in
    Load_path.init pl.load_path;
    merge_tbl pl.defs ~into:tbl;
    List.iter
      (fun (loc, shape, env) ->
        match Shape_full_reduce.weak_reduce env shape with
        | { uid = Some uid; _ } -> add tbl uid @@ LidSet.singleton loc
        | { uid = None; _ } as _s ->
            (* Log.warn "File %S: Shape %a was not fully reduced: %a" file Shape.print shape Shape.print s; *)
            ())
      pl.partial
  in
  fun files ->
    List.iter merge_file files;
    File_format.write ~file:output_file
      { defs = tbl; partial = []; load_path = [] }
