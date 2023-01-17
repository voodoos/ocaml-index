open File_format
module Kind = Shape.Sig_component_kind

type typedtree =
  | Interface of Typedtree.signature
  | Implementation of Typedtree.structure

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

    match Cmt_format.read (Load_path.find_uncap cmt) with
    | _, Some cmt_infos -> cmt_infos.cmt_impl_shape
    | _, None | (exception Not_found) ->
        if ext = "cmt" then (
          Log.debug "Failed to load cmt: %s, attempting cmti" cmt;
          try_load ~unit_name ~ext:"cmti" ())
        else (
          Log.error "Failed to load cmt(i): %s in load_path: [%s]" cmt
          @@ String.concat ":\n" (Load_path.get_paths ());
          raise Not_found)

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

let gather_shapes ~is_exposed _defs tree =
  Log.debug "Gather SHAPES";
  (* Todo: handle error even if it should not happen *)
  let shapes = ref [] in
  let iterator =
    let register_loc ~env ~lid shape =
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

let from_tbl uid_to_loc =
  let tbl = Hashtbl.create 128 in
  Shape.Uid.Tbl.iter
    (fun uid loc -> Hashtbl.add tbl uid (LidSet.singleton loc))
    uid_to_loc;
  tbl

let from_fragments ~is_exposed tbl fragments =
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
        | Some lid -> Hashtbl.add tbl uid @@ LidSet.singleton lid
        | None -> ())
    fragments

let generate_one ~build_path input_file =
  Log.debug "Gather uids from %s\n%!" input_file;
  match Cmt_format.read input_file with
  | _, Some cmt_infos -> (
      let load_path =
        List.merge String.compare cmt_infos.cmt_loadpath build_path
      in
      Load_path.init load_path;
      match get_typedtree cmt_infos with
      | Some (tree, _) ->
          let defs = Hashtbl.create 128 in
          let public_shapes : Shape.t = Option.get cmt_infos.cmt_impl_shape in
          let is_exposed = is_exposed ~public_shapes in
          from_fragments ~is_exposed defs cmt_infos.cmt_uid_to_loc;
          let partial_shapes = gather_shapes ~is_exposed defs tree in
          Some { defs; partial = partial_shapes; load_path }
      | None -> (* todo log error *) None)
  | _, _ -> (* todo log error *) None

let generate ~output_file ~build_path cmt =
  Log.debug "Writing %s\n%!" output_file;
  let payload =
    match generate_one ~build_path cmt with
    | Some pl -> pl
    | None -> { defs = Hashtbl.create 0; partial = []; load_path = [] }
  in
  File_format.write ~file:output_file payload

let aggregate ~output_file =
  let tbl = Hashtbl.create 256 in
  let merge_file file =
    let pl = File_format.read ~file in
    merge_tbl pl.defs ~into:tbl;
    Load_path.init pl.load_path;
    List.iter
      (fun (loc, shape, env) ->
        match (Shape_full_reduce.weak_reduce env shape).uid with
        | Some uid -> add tbl uid @@ LidSet.singleton loc
        | None -> ())
      pl.partial
  in
  fun files ->
    List.iter merge_file files;
    File_format.write ~file:output_file
      { defs = tbl; partial = []; load_path = [] }
