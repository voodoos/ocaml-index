open Shape

module Make(Params : sig
  type env
  val fuel : int
  val read_unit_shape : unit_name:string -> t option
  val find_shape : env -> Ident.t -> t
  val persist_memo : bool
end) = struct
  (* We implement a strong call-by-need reduction, following an
     evaluator from Nathanaelle Courant. *)

  type nf = { uid: Uid.t option; desc: nf_desc }
  and nf_desc =
    | NVar of var
    | NApp of nf * nf
    | NAbs of local_env * var * t * delayed_nf
    | NStruct of delayed_nf Item.Map.t
    | NProj of nf * Item.t
    | NLeaf
    | NComp_unit of string
    | NoFuelLeft of desc
  (* A type of normal forms for strong call-by-need evaluation.
     The normal form of an abstraction
       Abs(x, t)
     is a closure
       NAbs(env, x, t, dnf)
     when [env] is the local environment, and [dnf] is a delayed
     normal form of [t].

     A "delayed normal form" is morally equivalent to (nf Lazy.t), but
     we use a different representation that is compatible with
     memoization (lazy values are not hashable/comparable by default
     comparison functions): we represent a delayed normal form as
     just a not-yet-computed pair [local_env * t] of a term in a
     local environment -- we could also see this as a term under
     an explicit substitution. This delayed thunked is "forced"
     by calling the normalization function as usual, but duplicate
     computations are precisely avoided by memoization.
   *)
  and delayed_nf = Thunk of local_env * t

  and local_env = delayed_nf option Ident.Map.t
  (* When reducing in the body of an abstraction [Abs(x, body)], we
     bind [x] to [None] in the environment. [Some v] is used for
     actual substitutions, for example in [App(Abs(x, body), t)], when
     [v] is a thunk that will evaluate to the normal form of [t]. *)


  let persistent_memo_tables :
    ((delayed_nf option Ident.Map.t * t, nf) Hashtbl.t * (nf, t) Hashtbl.t) option =
    if Params.persist_memo then
      Some (Hashtbl.create 42, Hashtbl.create 42)
    else None
  let improve_uid uid (nf : nf) =
    match nf.uid with
    | Some _ -> nf
    | None -> { nf with uid }

  let in_memo_table memo_table memo_key f arg =
    match Hashtbl.find memo_table memo_key with
    | res -> res
    | exception Not_found ->
        let res = f arg in
        Hashtbl.replace memo_table memo_key res;
        res

  type env = {
    fuel: int ref;
    global_env: Params.env;
    local_env: local_env;
    reduce_memo_table: (local_env * t, nf) Hashtbl.t;
    read_back_memo_table: (nf, t) Hashtbl.t;
  }

  let bind env var shape =
    { env with local_env = Ident.Map.add var shape env.local_env }

  let rec reduce_ env t =
    let memo_key = (env.local_env, t) in
    in_memo_table env.reduce_memo_table memo_key (reduce__ env) t
  (* Memoization is absolutely essential for performance on this
     problem, because the normal forms we build can in some real-world
     cases contain an exponential amount of redundancy. Memoization
     can avoid the repeated evaluation of identical subterms,
     providing a large speedup, but even more importantly it
     implicitly shares the memory of the repeated results, providing
     much smaller normal forms (that blow up again if printed back
     as trees). A functor-heavy file from Irmin has its shape normal
     form decrease from 100Mio to 2.5Mio when memoization is enabled.

     Note: the local environment is part of the memoization key, while
     it is defined using a type Ident.Map.t of non-canonical balanced
     trees: two maps could have exactly the same items, but be
     balanced differently and therefore hash differently, reducing
     the effectivenss of memoization.
     This could in theory happen, say, with the two programs
       (fun x -> fun y -> ...)
     and
       (fun y -> fun x -> ...)
     having "the same" local environments, with additions done in
     a different order, giving non-structurally-equal trees. Should we
     define our own hash functions to provide robust hashing on
     environments?

     We believe that the answer is "no": this problem does not occur
     in practice. We can assume that identifiers are unique on valid
     typedtree fragments (identifier "stamps" distinguish
     binding positions); in particular the two program fragments above
     in fact bind *distinct* identifiers x (with different stamps) and
     different identifiers y, so the environments are distinct. If two
     environments are structurally the same, they must correspond to
     the evaluation evnrionments of two sub-terms that are under
     exactly the same scope of binders. So the two environments were
     obtained by the same term traversal, adding binders in the same
     order, giving the same balanced trees: the environments have the
     same hash.
*)

  and reduce__ ({fuel; global_env; local_env; _} as env) (t : t) =
    let reduce env t = reduce_ env t in
    let delay_reduce env t = Thunk (env.local_env, t) in
    let force (Thunk (local_env, t)) =
      reduce { env with local_env } t in
    let return desc : nf = { uid = t.uid; desc } in
    if !fuel < 0 then return (NoFuelLeft t.desc)
    else
      match t.desc with
      | Comp_unit unit_name ->
          begin match Params.read_unit_shape ~unit_name with
          | Some t -> reduce env t
          | None -> return (NComp_unit unit_name)
          end
      | App(f, arg) ->
          let f = reduce env f in
          begin match f.desc with
          | NAbs(clos_env, var, body, _body_nf) ->
              let arg = delay_reduce env arg in
              let env = bind { env with local_env = clos_env } var (Some arg) in
              reduce env body
              |> improve_uid t.uid
          | _ ->
              let arg = reduce env arg in
              return (NApp(f, arg))
          end
      | Proj(str, item) ->
          let str = reduce env str in
          let nored () = return (NProj(str, item)) in
          begin match str.desc with
          | NStruct (items) ->
              begin match Item.Map.find item items with
              | exception Not_found -> nored ()
              | nf ->
                  force nf
                  |> improve_uid t.uid
              end
          | _ ->
              nored ()
          end
      | Abs(var, body) ->
          let body_nf = delay_reduce (bind env var None) body in
          return (NAbs(local_env, var, body, body_nf))
      | Var id ->
          begin match Ident.Map.find id local_env with
          (* Note: instead of binding abstraction-bound variables to
             [None], we could unify it with the [Some v] case by
             binding the bound variable [x] to [NVar x].

             One reason to distinguish the situations is that we can
             provide a different [Uid.t] location; for bound
             variables, we use the [Uid.t] of the bound occurrence
             (not the binding site), whereas for bound values we use
             their binding-time [Uid.t]. *)
          | None -> return (NVar id)
          | Some def -> force def
          | exception Not_found ->
          match Params.find_shape global_env id with
          | exception Not_found -> return (NVar id)
          | res when res = t -> return (NVar id)
          | res ->
              decr fuel;
              reduce env res
          end
      | Leaf -> return NLeaf
      | Struct m ->
          let mnf = Item.Map.map (delay_reduce env) m in
          return (NStruct mnf)

  let rec read_back env (nf : nf) : t =
    in_memo_table env.read_back_memo_table nf (read_back_ env) nf
  (* The [nf] normal form we receive may contain a lot of internal
     sharing due to the use of memoization in the evaluator. We have
     to memoize here again, otherwise the sharing is lost by mapping
     over the term as a tree. *)

  and read_back_ env (nf : nf) : t =
    { uid = nf.uid; desc = read_back_desc env nf.desc }

  and read_back_desc env desc =
    let read_back nf = read_back env nf in
    let read_back_force (Thunk (local_env, t)) =
      read_back (reduce_ { env with local_env } t) in
    match desc with
    | NVar v ->
        Var v
    | NApp (nft, nfu) ->
        App(read_back nft, read_back nfu)
    | NAbs (_env, x, _t, nf) ->
        Abs(x, read_back_force nf)
    | NStruct nstr ->
        Struct (Item.Map.map read_back_force nstr)
    | NProj (nf, item) ->
        Proj (read_back nf, item)
    | NLeaf -> Leaf
    | NComp_unit s -> Comp_unit s
    | NoFuelLeft t -> t

  let reduce global_env t =
    let reduce_memo_table, read_back_memo_table =
      match persistent_memo_tables with
      | Some(r, rb) -> r, rb
      | None -> Hashtbl.create 42, Hashtbl.create 42
    in
    let fuel = ref Params.fuel in
    let local_env = Ident.Map.empty in
    let env = {
      fuel;
      global_env;
      reduce_memo_table;
      read_back_memo_table;
      local_env;
    } in
    reduce_ env t |> read_back env
end
