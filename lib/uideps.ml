open File_format
module Kind = Shape.Sig_component_kind

type typedtree =
  | Interface of Typedtree.signature
  | Implementation of Typedtree.structure

let add tbl uid locs =
  try
    let locations = Hashtbl.find tbl uid in
    Hashtbl.replace tbl uid (LocSet.union locs locations)
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
end)

module Shape_local_reduce = Shape_reduce.Make_reduce (struct
  include Reduce_common

  let read_unit_shape ~unit_name:_ = None
end)

let gather_shapes tree =
  Log.debug "Gather SHAPES";
  let shapes = ref [] in
  let iterator =
    let register_loc ~env ~loc shape =
      let shape = Shape_local_reduce.weak_reduce env shape in
      shapes := (loc, shape, env) :: !shapes
    in
    {
      Tast_iterator.default_iterator with
      expr =
        (fun sub ({ exp_desc; exp_loc; exp_env; _ } as e) ->
          (match exp_desc with
          | Texp_ident (path, _, { val_uid = _; _ }) -> (
              try
                let env = rebuild_env exp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Value env path in
                register_loc ~env ~loc:exp_loc shape
              with Not_found ->
                Log.warn "No shape for expr %a at %a" Path.print path
                  Location.print_loc exp_loc)
          | _ -> ());
          Tast_iterator.default_iterator.expr sub e);
      module_expr =
        (fun sub ({ mod_desc; mod_loc; mod_env; _ } as me) ->
          (match mod_desc with
          | Tmod_ident (path, _lid) -> (
              try
                let env = rebuild_env mod_env in
                let shape = Env.shape_of_path ~namespace:Kind.Module env path in
                register_loc ~env ~loc:mod_loc shape
              with Not_found ->
                Log.warn "No shape for module %a at %a\n%!" Path.print path
                  Location.print_loc mod_loc)
          | _ -> ());
          Tast_iterator.default_iterator.module_expr sub me);
      typ =
        (fun sub ({ ctyp_desc; ctyp_loc; ctyp_env; _ } as me) ->
          (match ctyp_desc with
          | Ttyp_constr (path, _lid, _ctyps) -> (
              try
                let env = rebuild_env ctyp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Type env path in
                register_loc ~env ~loc:ctyp_loc shape
              with Not_found ->
                Log.warn "No shape for type %a at %a" Path.print path
                  Location.print_loc ctyp_loc)
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
      Some (Interface { s with sig_final_env })
  | Implementation str ->
      Log.debug "Implementation\n%!";
      let str_final_env = rebuild_env str.str_final_env in
      Some (Implementation { str with str_final_env })
  | _ ->
      Log.debug "No typedtree\n%!";
      None

let from_tbl uid_to_loc =
  let tbl = Hashtbl.create 128 in
  Shape.Uid.Tbl.iter
    (fun uid loc -> Hashtbl.add tbl uid (LocSet.singleton loc))
    uid_to_loc;
  tbl

let generate_one ~build_path input_file =
  Log.debug "Gather uids from %s\n%!" input_file;
  match Cmt_format.read input_file with
  | _, Some cmt_infos -> (
      let load_path =
        List.merge String.compare cmt_infos.cmt_loadpath build_path
      in
      Load_path.init load_path;
      match get_typedtree cmt_infos with
      | Some tree ->
          let partial_shapes = gather_shapes tree in
          let defs = from_tbl cmt_infos.cmt_uid_to_loc in
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
        | Some uid -> add tbl uid @@ LocSet.singleton loc
        | None -> ())
      pl.partial
  in
  fun files ->
    List.iter merge_file files;
    File_format.write ~file:output_file
      { defs = tbl; partial = []; load_path = [] }
