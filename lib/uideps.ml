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

let gather_uids tree =
  Log.debug "Gather UIDS";
  let tbl = Hashtbl.create 64 in
  let module Shape_reduce =
    Shape_reduce.Make (struct
      type env = Env.t
      let fuel = 10
      let persist_memo = true

      let read_unit_shape ~unit_name =
        Log.debug "Read unit shape: %s\n%!" unit_name;
        let cmt = String.concat "." [ unit_name; "cmt" ] in
        match Cmt_format.read (Load_path.find_uncap cmt) with
        | _, Some cmt_infos -> cmt_infos.cmt_impl_shape
        | _, None | exception Not_found ->
          Log.warn "Failed to load cmt: %s\n%!" cmt;
          None

      let find_shape env id =
        Env.shape_of_path ~namespace:Shape.Sig_component_kind.Module env
          (Pident id)
    end)

  in
  let iterator =
    let add_to_tbl ~env ~loc shape =
      match (Shape_reduce.reduce env shape).uid with
      | Some uid -> add tbl uid (LocSet.singleton loc)
      | None -> ()
    in
    { Tast_iterator.default_iterator with

      expr =
        (fun sub ({ exp_desc; exp_loc; exp_env; _ } as e) ->
          begin match exp_desc with
          | Texp_ident (path, _, { val_uid = _; _ }) ->
            begin
              try
                let env = rebuild_env exp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Value env path in
                add_to_tbl ~env ~loc:exp_loc shape
              with Not_found ->
                Log.warn "No shape for expr %a at %a" Path.print path
                  Location.print_loc exp_loc
            end
          | _ -> ()
          end;
          Tast_iterator.default_iterator.expr sub e);
      module_expr =
        (fun sub ({ mod_desc; mod_loc; mod_env; _ } as me) ->
          begin match mod_desc with
          | Tmod_ident (path, _lid) ->
            begin
              try
                let env = rebuild_env mod_env in
                let shape = Env.shape_of_path ~namespace:Kind.Module env path in
                add_to_tbl ~env ~loc:mod_loc shape
              with Not_found ->
                Log.warn "No shape for module %a at %a\n%!" Path.print path
                  Location.print_loc mod_loc
            end
          | _ -> ()
          end;
          Tast_iterator.default_iterator.module_expr sub me);
      typ =
        (fun sub ({ ctyp_desc; ctyp_loc; ctyp_env; _ } as me) ->
          begin match ctyp_desc with
          | Ttyp_constr (path, _lid, _ctyps) ->
            begin
              try
                let env = rebuild_env ctyp_env in
                let shape = Env.shape_of_path ~namespace:Kind.Type env path in
                add_to_tbl ~env ~loc:ctyp_loc shape
              with Not_found ->
                Log.warn "No shape for type %a at %a" Path.print path
                  Location.print_loc ctyp_loc
            end
          | _ -> ()
          end;
          Tast_iterator.default_iterator.typ sub me)
    }
  in
  begin match tree with
  | Interface signature -> iterator.signature iterator signature
  | Implementation structure -> iterator.structure iterator structure
  end;
  tbl

let get_typedtree (cmt_infos : Cmt_format.cmt_infos) =
  Log.debug "get Typedtree\n%!";
  match cmt_infos.cmt_annots with
  | Interface s ->
    Log.debug "Interface\n%!";
    let sig_final_env = rebuild_env s.sig_final_env in
    Some (Interface { s with  sig_final_env })
  | Implementation str ->
    Log.debug "Implementation\n%!";
    let str_final_env = rebuild_env str.str_final_env in
    Some (Implementation { str with  str_final_env })
  | _ ->
    Log.debug "No typedtree\n%!";
    None

let generate_one_aux ~uid_to_loc tree =
  let uids = gather_uids tree in
  Shape.Uid.Tbl.iter (fun uid loc -> add uids uid (LocSet.singleton loc))
    uid_to_loc;
  uids

let generate_one input_file =
  Log.debug "Gather uids from %s\n%!" input_file;
  match Cmt_format.read input_file with
  | _, Some cmt_infos ->
    Load_path.init cmt_infos.cmt_loadpath;
    begin match get_typedtree cmt_infos with
    | Some tree ->
      Some (generate_one_aux ~uid_to_loc:cmt_infos.cmt_uid_to_loc tree)
    | None -> (* todo log error *) None
    end
  | _, _ -> (* todo log error *) None

let generate ~output_file cmts =
  let tbl = Hashtbl.create 256 in
  List.iter (fun cmt -> Option.iter (merge_tbl ~into:tbl) (generate_one cmt))
    cmts;
  Log.debug "Writing %s\n%!" output_file;
  File_format.write ~file:output_file tbl

let aggregate ~output_file =
  let tbl = Hashtbl.create 256 in
  let merge_file file =
    let f_tbl = File_format.read ~file in
    merge_tbl f_tbl ~into:tbl
  in
  fun files ->
    List.iter merge_file files;
    File_format.write ~file:output_file tbl
