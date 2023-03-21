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

let index_shapes = Hashtbl.create 128

module Shape_full_reduce = Shape_reduce.Make_reduce (struct
  include Reduce_common

  let load_index comp_unit filename =
    Log.debug "Looking for shapes in %S\n" filename;
    match File_format.read ~file:(Load_path.find_uncap filename) with
    | { cu_shape; _ } ->
        Log.debug "Succesfully loaded %S\nIt contains shapes for %s\n\n%!"
          filename
          (String.concat "; " (Hashtbl.to_seq_keys cu_shape |> List.of_seq));
        Hashtbl.add index_shapes comp_unit cu_shape;
        Hashtbl.find_opt cu_shape comp_unit
    | exception Not_found ->
        Log.debug "Failed to load file %S in load_path: @[%s@]\n%!" filename
        @@ String.concat "; " (Load_path.get_paths ());
        None

  let try_load ~unit_name () =
    let lib_name =
      let rec prefix acc = function
        | [] | "" :: _ -> List.rev acc |> String.concat "_"
        | segment :: tl -> prefix (segment :: acc) tl
      in
      prefix [] (String.split_on_char '_' unit_name)
    in

    (* This is an awful hack: we don't know if the shapes are in another module of the
       same library, or in the global index of another library or the stdlib/another
       external installed cmt. So we try them all.

       The shapes could also have already been loaded from a stanza's index.

       todo: check risk of finding the wrong shape todo: we could instantiate the functor
       later (just before starting the reduction) and take advantage of more information
    *)
    Log.debug "Lookup %s (%s) in the already loaded shapes." lib_name unit_name;
    let shape =
      match Hashtbl.find_opt index_shapes lib_name with
      | Some tbl -> Hashtbl.find_opt tbl unit_name
      | None -> None
    in
    match shape with
    | Some shape -> Some shape
    | None -> (
        let index_index = Format.sprintf "%s.stanza.merlin-index" unit_name in
        match load_index unit_name index_index with
        | Some shape -> Some shape
        | None -> (
            let index = Format.sprintf "%s.merlin-index" unit_name in
            match load_index unit_name index with
            | Some shape -> Some shape
            | None -> (
                let cmt = Format.sprintf "%s.cmt" unit_name in
                match Cmt_format.read (Load_path.find_uncap cmt) with
                | _, Some cmt_infos ->
                    Log.debug "Loaded CMT %s" cmt;
                    cmt_infos.cmt_impl_shape
                | _ | (exception Not_found) ->
                    Log.warn "Failed to load file %S in load_path: @[%s@]\n%!"
                      cmt
                    @@ String.concat "; " (Load_path.get_paths ());
                    None)))

  let read_unit_shape ~unit_name =
    Log.debug "Read unit shape: %s\n%!" unit_name;
    try_load ~unit_name ()

  let find_shape env id =
    (* When partial reduction is performed only the summary of the env is stored on the
       filesystem. We need to reconstitute the complete envoronment but we do it only if
       we need it. *)
    let env = rebuild_env env in
    find_shape env id
end)

module Shape_local_reduce = Shape_reduce.Make_reduce (struct
  include Reduce_common

  let read_unit_shape ~unit_name:_ = None
end)

(** [gather_shapes] iterates on the Typedtree and reduce the shape of every type
    and value to add them to the index. *)
let gather_shapes ~root ~unreduced ~partial_shapes:_ tree =
  Log.debug "Start gathering SHAPES";
  let iterator =
    let register_loc ~env ~lid shape =
      let lid = add_root ~root lid in
      let shape = Shape_local_reduce.weak_reduce env shape in
      let summary = Env.keep_only_summary env in
      unreduced := (shape, summary, lid) :: !unreduced
    in
    {
      Tast_iterator.default_iterator with
      (* Only types and values are indexed right now *)
      expr =
        (fun sub ({ exp_desc; exp_env; _ } as e) ->
          (match exp_desc with
          | Texp_ident (path, lid, _) -> (
              try
                let env = rebuild_env exp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Value env path in
                register_loc ~env ~lid shape
              with Not_found ->
                Log.warn "No shape for expr %a at %a" Path.print path
                  Location.print_loc lid.loc)
          | _ -> ());
          Tast_iterator.default_iterator.expr sub e);
      typ =
        (fun sub ({ ctyp_desc; ctyp_env; _ } as me) ->
          (match ctyp_desc with
          | Ttyp_constr (path, lid, _ctyps) -> (
              try
                let env = rebuild_env ctyp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Type env path in
                register_loc ~env ~lid shape
              with Not_found ->
                Log.warn "No shape for type %a at %a" Path.print path
                  Location.print_loc lid.loc)
          | _ -> ());
          Tast_iterator.default_iterator.typ sub me);
    }
  in
  match tree with
  | Interface signature -> iterator.signature iterator signature
  | Implementation structure -> iterator.structure iterator structure

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

(* Hijack loader to print requested modules *)
let () =
  let old_load = !Persistent_env.Persistent_signature.load in
  Persistent_env.Persistent_signature.load :=
    fun ~unit_name ->
      Log.debug "Loading CU %s\n" unit_name;
      old_load ~unit_name

(* This is only a dummy for now *)
let generate_one ~root ~build_path:_ cmt_path =
  match Cmt_format.read_cmt cmt_path with
  | {
   cmt_annots = Implementation ({ str_final_env; _ } as structure);
   cmt_loadpath;
   cmt_impl_shape;
   cmt_modname;
   _;
  } -> (
      try
        Load_path.init cmt_loadpath;
        let str_final_env = Envaux.env_of_only_summary str_final_env in
        ();
        let public_shapes = Option.get cmt_impl_shape in
        let unreduced = ref [] in
        let partial_shapes = Hashtbl.create 64 in
        let () =
          gather_shapes ~root ~unreduced ~partial_shapes
            (Implementation { structure with str_final_env })
        in
        let cu_shapes = Hashtbl.create 1 in
        Hashtbl.add cu_shapes cmt_modname public_shapes;
        Some (partial_shapes, !unreduced, cu_shapes, cmt_loadpath)
      with Envaux.Error err ->
        Log.error "Failed to rebuild env: %a.\nLoad_path: [%s]\n%!"
          Envaux.report_error err
          (String.concat "; " cmt_loadpath);
        raise @@ Envaux.Error err)
  | exception Cmi_format.Error err ->
      Log.error "Failed to load cmt: %a\n%!" Cmi_format.report_error err;
      raise @@ Cmi_format.Error err
  | _ ->
      Log.error "No implementation in %s\n%!" cmt_path;
      None

(** [generate ~root ~output_file ~build_path cmt] indexes the cmt [cmt] by
      iterating on its [Typedtree] and reducing partially the shapes of every
      value.
    - In some cases (implicit transitive deps) the [build_path] contains in the
      cmt file might be missing entries, these can be provided using the
      [build_path] argument.
    - If [root] is provided all location paths will be made absolute *)
let generate ~root ~output_file ~build_path cmt =
  Log.debug "Generating index for cmt %S\n%!" cmt;
  let shapes = generate_one ~root ~build_path cmt in
  Option.iter
    (fun (partials, unreduced, cu_shape, load_path) ->
      Log.debug "Writing to %s\n%!" output_file;
      File_format.write ~file:output_file
        { defs = Hashtbl.create 0; partials; unreduced; load_path; cu_shape })
    shapes

let aggregate ~store_shapes ~output_file =
  let defs = Hashtbl.create 256 in
  let partials = Hashtbl.create 64 in
  let merge_file ~cu_shape file =
    let pl = File_format.read ~file in
    Log.debug "Aggregating file %s\n" file;
    if store_shapes then Hashtbl.add_seq cu_shape (Hashtbl.to_seq pl.cu_shape);
    merge_tbl pl.defs ~into:defs;
    merge_tbl pl.partials ~into:partials;
    Load_path.init pl.load_path;
    List.iter
      (fun (shape, env, lid) ->
        match Shape_full_reduce.weak_reduce env shape with
        | { desc = Leaf; uid = Some uid } as _s ->
            add defs uid (LidSet.singleton lid)
        | s ->
            Log.debug "Partial shape: %a\n" Shape.print s;
            add partials shape (LidSet.singleton lid))
      pl.unreduced
  in
  fun files ->
    let cu_shape = Hashtbl.create (List.length files) in
    List.iter (merge_file ~cu_shape) files;
    File_format.write ~file:output_file
      { defs; partials; unreduced = []; load_path = []; cu_shape }
