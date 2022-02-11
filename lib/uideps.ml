open File_format

type typedtree =
 | Interface of Typedtree.signature
 | Implementation of Typedtree.structure

let gather_uids tree =
  let tbl = Hashtbl.create 64 in
  let add uid loc =
    try
      let locations = Hashtbl.find tbl uid in
      Hashtbl.replace tbl uid (LocSet.add loc locations)
    with Not_found -> Hashtbl.add tbl uid (LocSet.singleton loc)
  in
  let add_if_external ~loc = function
    | (Shape.Uid.Compilation_unit comp_unit | Item { comp_unit; _ }) as uid ->
      if Env.get_unit_name () <> comp_unit then
        add uid loc
    | _ -> ()
  in
  let iterator env =
    { Tast_iterator.default_iterator with

      expr =
        (fun sub ({ exp_desc; exp_loc; _} as e) ->
          begin match exp_desc with
          | Texp_ident (_, _, { val_uid; _ }) ->
            add_if_external ~loc:exp_loc val_uid
          | _ -> () end;
          Tast_iterator.default_iterator.expr sub e);

      module_expr =
        (fun sub ({ mod_desc; mod_loc; _} as me) ->
          begin match mod_desc with
          | Tmod_ident (path, _lid) ->
            let md = Env.find_module path env in
            add_if_external ~loc:mod_loc md.md_uid
          | _ -> () end;
          Tast_iterator.default_iterator.module_expr sub me);

      typ =
        (fun sub ({ ctyp_desc; ctyp_loc; _} as me) ->
          begin match ctyp_desc with
          | Ttyp_constr (path, _lid, _ctyps) ->
            let td = Env.find_type path env in
            add_if_external ~loc:ctyp_loc td.type_uid
          | _ -> () end;
          Tast_iterator.default_iterator.typ sub me);
    }
  in
  begin match tree with
  | Interface signature ->
    let iterator = iterator signature.sig_final_env in
    iterator.signature iterator signature
  | Implementation structure ->
    let iterator = iterator structure.str_final_env in
    iterator.structure iterator structure
  end;
  tbl

let get_typedtree (cmt_infos : Cmt_format.cmt_infos) =
  Load_path.init cmt_infos.cmt_loadpath;
  match cmt_infos.cmt_annots with
  | Interface s ->
    let sig_final_env = Envaux.env_of_only_summary s.sig_final_env in
    Some (Interface { s with sig_final_env })
  | Implementation str ->
    let str_final_env = Envaux.env_of_only_summary str.str_final_env in
    Some (Implementation { str with str_final_env })
  | _ -> None

let generate_one_aux ~input_file tree =
  let uids = gather_uids tree in
  let file =
    String.concat "." [Filename.basename input_file; File_format.ext]
  in
  File_format.write ~file uids

let generate_one input_file =
  match Cmt_format.read input_file with
  | _, Some cmt_infos -> begin match get_typedtree cmt_infos with
    | Some tree -> generate_one_aux ~input_file tree
    | None -> (* todo log error *) ()
    end
  | _, _ -> (* todo log error *) ()

let generate = List.iter generate_one
