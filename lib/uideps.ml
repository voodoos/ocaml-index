open File_format
module Kind = Shape.Sig_component_kind

module Shape_reduce = 
  Shape_reduce.Make (struct
    type env = Env.t
    let fuel = 10
    let persist_memo = true

    let read_unit_shape ~unit_name = 
      let cmt = String.concat "." [unit_name; "cmt"] in
      match Cmt_format.read (Load_path.find_uncap cmt) with
      | _, Some cmt_infos -> 
        (* TODO should we complete the load_path ? *)
        cmt_infos.cmt_impl_shape
      | _, None | exception Not_found -> 
        Printf.eprintf "Failed to load cmt: %s\n%!" cmt; 
        None
    let find_shape env id = Env.shape_of_path
      ~namespace:Shape.Sig_component_kind.Module env (Pident id)
  end) 

type typedtree =
 | Interface of Typedtree.signature
 | Implementation of Typedtree.structure

let add tbl uid locs =
  try
    let locations = Hashtbl.find tbl uid in
    Hashtbl.replace tbl uid (LocSet.union locs locations)
  with Not_found -> Hashtbl.add tbl uid locs

let merge_tbl ~into tbl = Hashtbl.iter (add into) tbl

let gather_uids tree =
  let tbl = Hashtbl.create 64 in
  let iterator env =
    let add_to_tbl ~loc shape = 
        match (Shape_reduce.reduce env shape).uid with
        | Some uid -> add tbl uid (LocSet.singleton loc)
        | None -> ()
    in
    { Tast_iterator.default_iterator with

      expr =
        (fun sub ({ exp_desc; exp_loc; _} as e) ->
          begin match exp_desc with
          | Texp_ident (path, _, { val_uid=_; _ }) ->
            let shape = Env.shape_of_path ~namespace:Kind.Value env path in
            add_to_tbl ~loc:exp_loc shape
          | _ -> () end;
          Tast_iterator.default_iterator.expr sub e);

      module_expr =
        (fun sub ({ mod_desc; mod_loc; _} as me) ->
          begin match mod_desc with
          | Tmod_ident (path, _lid) ->
            let shape = Env.shape_of_path ~namespace:Kind.Module env path in
            add_to_tbl ~loc:mod_loc shape
          | _ -> () end;
          Tast_iterator.default_iterator.module_expr sub me);

      typ =
        (fun sub ({ ctyp_desc; ctyp_loc; _} as me) ->
          begin match ctyp_desc with
          | Ttyp_constr (path, _lid, _ctyps) ->
            let shape = Env.shape_of_path ~namespace:Kind.Type env path in
            add_to_tbl ~loc:ctyp_loc shape
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
    String.concat "." [Filename.remove_extension input_file; File_format.ext]
  in
  File_format.write ~file uids

let generate_one input_file =
  match Cmt_format.read input_file with
  | _, Some cmt_infos -> 
    Load_path.init cmt_infos.cmt_loadpath;
    begin match get_typedtree cmt_infos with
    | Some tree -> generate_one_aux ~input_file tree
    | None -> (* todo log error *) ()
    end
  | _, _ -> (* todo log error *) ()

let generate = List.iter generate_one

let aggregate =
  let output = "workspace.uideps" in
  let tbl = Hashtbl.create 256 in
  let merge_file file =
    let f_tbl = File_format.read ~file in
    merge_tbl f_tbl ~into:tbl 
  in
  fun files -> 
    List.iter merge_file files;
    File_format.write ~file:output tbl
