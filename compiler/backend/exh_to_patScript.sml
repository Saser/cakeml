open preamble exhLangTheory patLangTheory
open backend_commonTheory

val _ = new_theory"exh_to_pat"
val _ = patternMatchesLib.ENABLE_PMATCH_CASES();
(*TODO: Verify that Empty is fine for Con here (should be since the con is never
* used but only there to determine true false, which the trace shouldnt affect *)
val Bool_def = Define `
  Bool b = Con Empty (if b then true_tag else false_tag) []`;
val Bool_eqns = save_thm("Bool_eqns[simp]",
  [``Bool T``,``Bool F``]
  |> List.map (SIMP_CONV(std_ss)[Bool_def])
  |> LIST_CONJ)

val sIf_def = Define `
  sIf tra e1 e2 e3 =
  if e2 = Bool T ∧ e3 = Bool F
    then e1
  else
    (dtcase e1 of
     | Con _ t [] => if t = true_tag then e2 else e3
     | _ => If tra e1 e2 e3)`;
(* TODO: Update sIf_pmatch to be consistent with traces
* val sIf_pmatch = Q.store_thm("sIf_pmatch",`!e1 e2 e3.
  sIf e1 e2 e3 =
  if e2 = Bool T ∧ e3 = Bool F
    then e1
  else
    (case e1 of
     | Con t [] => if t = true_tag then e2 else e3
     | _ => If e1 e2 e3)`, 
  rpt strip_tac
  >> every_case_tac
  >- fs[sIf_def]
  >- (CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV) >> every_case_tac
  >> fs[sIf_def]));*)

val _ = Define `
  pure_op_op op ⇔
    (op <> Opref) ∧
    (op <> Opapp) ∧
    (op <> Opassign) ∧
    (op <> Aw8update) ∧
    (op <> Aw8alloc) ∧
    (op <> Aw8sub) ∧
    (op <> Vsub) ∧
    (op <> Strsub) ∧
    (op <> Chr) ∧
    (op <> Aupdate) ∧
    (op <> Aalloc) ∧
    (op <> Asub) ∧
    (op <> (Opn Divide)) ∧
    (op <> (Opn Modulo)) ∧
    (!n. op <> FFI n)`;

val _ = Define `
  (pure_op (Op (Op op)) ⇔ pure_op_op op)
  ∧
  (pure_op (Op (Init_global_var _)) ⇔ F)
  ∧
  (pure_op (Tag_eq _ _) ⇔ T)
  ∧
  (pure_op (El _) ⇔ T)`;

val pure_def = Define `
  (pure (Raise tra _) ⇔ F)
  ∧
  (pure (Handle tra e1 _) ⇔ pure e1)
  ∧
  (pure (Lit tra _) ⇔ T)
  ∧
  (pure (Con tra _ es) ⇔ pure_list es)
  ∧
  (pure (Var_local tra _) ⇔ T)
  ∧
  (pure (Var_global tra _) ⇔ T)
  ∧
  (pure (Fun tra _) ⇔ T)
  ∧
  (pure (App tra op es) ⇔ pure_list es ∧ pure_op op)
  ∧
  (pure (If tra e1 e2 e3) ⇔ pure e1 ∧ pure e2 ∧ pure e3)
  ∧
  (pure (Let tra e1 e2) ⇔ pure e1 ∧ pure e2)
  ∧
  (pure (Seq tra e1 e2) ⇔ pure e1 ∧ pure e2)
  ∧
  (pure (Letrec tra _ e) ⇔ pure e)
  ∧
  (pure (Extend_global tra _) ⇔ F)
  ∧
  (pure_list [] ⇔ T)
  ∧
  (pure_list (e::es) ⇔ pure e ∧ pure_list es)`;

val pure_list_EVERY = Q.store_thm("pure_list_EVERY",
  `∀ls. pure_list ls ⇔ EVERY pure ls`,
  Induct >> simp[pure_def])
val _ = export_rewrites["pure_list_EVERY"]

val ground_def = Define `
  (ground n (Raise tra e) ⇔ ground n e)
  ∧
  (ground n (Handle tra e1 e2) ⇔ ground n e1 ∧ ground (n+1) e2)
  ∧
  (ground _ (Lit tra _) ⇔ T)
  ∧
  (ground n (Con tra _ es) ⇔ ground_list n es)
  ∧
  (ground n (Var_local tra k) ⇔ k < n)
  ∧
  (ground _ (Var_global tra _) ⇔ T)
  ∧
  (ground _ (Fun tra _) ⇔ F)
  ∧
  (ground n (App tra _ es) ⇔ ground_list n es)
  ∧
  (ground n (If tra e1 e2 e3) ⇔ ground n e1 ∧ ground n e2 ∧ ground n e3)
  ∧
  (ground n (Let tra e1 e2) ⇔ ground n e1 ∧ ground (n+1) e2)
  ∧
  (ground n (Seq tra e1 e2) ⇔ ground n e1 ∧ ground n e2)
  ∧
  (ground _ (Letrec tra _ _) ⇔ F)
  ∧
  (ground _ (Extend_global tra _) ⇔ T)
  ∧
  (ground_list _ [] ⇔ T)
  ∧
  (ground_list n (e::es) ⇔ ground n e ∧ ground_list n es)`;

val _ = export_rewrites["pure_op_op_def","pure_op_def","pure_def","ground_def"];

val ground_list_EVERY = Q.store_thm("ground_list_EVERY",
  `∀n ls. ground_list n ls ⇔ EVERY (ground n) ls`,
  gen_tac >> Induct >> simp[])
val _ = export_rewrites["ground_list_EVERY"]

val pure_op_op_eqn = Q.store_thm("pure_op_op_eqn",`
  pure_op_op op =
  dtcase op of
    Opref => F
  | Opapp => F
  | Opassign => F
  | Aw8update => F
  | Aw8alloc => F
  | Aw8sub => F
  | Vsub => F
  | Strsub => F
  | Chr => F
  | Aupdate => F
  | Aalloc => F
  | Asub => F
  | Opn Divide => F
  | Opn Modulo => F
  | FFI _ => F
  | _ => T`,
  Cases_on`op`>>fs[]>>
  Cases_on`o'`>>fs[])

val pure_op_op_pmatch = Q.store_thm("pure_op_op_pmatch",`
  pure_op_op op =
  case op of
    Opref => F
  | Opapp => F
  | Opassign => F
  | Aw8update => F
  | Aw8alloc => F
  | Aw8sub => F
  | Vsub => F
  | Strsub => F
  | Chr => F
  | Aupdate => F
  | Aalloc => F
  | Asub => F
  | Opn Divide => F
  | Opn Modulo => F
  | FFI _ => F
  | _ => T`,
  PURE_ONCE_REWRITE_TAC [pure_op_op_eqn]
  >> CONV_TAC(RAND_CONV patternMatchesLib.PMATCH_ELIM_CONV)
  >> REFL_TAC)

val _ = Define `
  sLet t e1 e2 =
  dtcase e2 of
     | Var_local _ 0 => e1
     | _ => 
         if ground 0 e2 then
           if pure e1 then e2
           else Seq t e1 e2
         else Let t e1 e2`;
(* bind elements 0..k of the variable n in reverse order above e (first element
 * becomes most recently bound) *)
val _ = Define`
  (Let_Els _ _ 0 e = e)
  ∧
  (Let_Els t n k e =
   sLet (mk_cons t 1) (App (mk_cons t 2) (El (k-1)) [Var_local (mk_cons t 3) n])
     (Let_Els (mk_cons t 4) (n+1) (k-1) e))`;

(* return an expression that evaluates to whether the pattern matches the most
 * recently bound variable *)
val _ = tDefine"compile_pat"`
  (compile_pat _ (Pvar _) =
   Bool T)
  ∧
  (compile_pat t (Plit l) =
   App (mk_cons t 1) (Op (Op Equality)) [Var_local (mk_cons t 2) 0; Lit (mk_cons t 3) l])
  ∧
  (compile_pat t (Pcon tag []) =
   App (mk_cons t 1) (Tag_eq tag 0) [Var_local (mk_cons t 2) 0])
  ∧
  (compile_pat t (Pcon tag ps) =
   sIf (mk_cons t 1) (App (mk_cons t 2) (Tag_eq tag (LENGTH ps)) [Var_local (mk_cons t 3) 0])
     (Let_Els (mk_cons t 4) 0 (LENGTH ps) (compile_pats (mk_cons t 5) 0 ps))
     (Bool F))
  ∧
  (compile_pat t (Pref p) =
   sLet (mk_cons t 1) (App (mk_cons t 2) (Op (Op Opderef)) [Var_local (mk_cons t
   3) 0])
     (compile_pat (mk_cons t 4) p))
  ∧
(* return an expression that evaluates to whether all the m patterns match the
 * m most recently bound variables; n counts 0..m *)
  (compile_pats _ _ [] = Bool T)
  ∧
  (compile_pats t n (p::ps) =
   sIf (mk_cons t 1) (sLet (mk_cons t 2) (Var_local (mk_cons t 3) n)
   (compile_pat (mk_cons t 4) p))
     (compile_pats (mk_cons t 5) (n+1) ps)
     (Bool F))`
  cheat;
  (*(WF_REL_TAC `inv_image $< (\x. dtcase x of INL p => pat_size p
                                         | INR (n,ps) => pat1_size ps)`);*)

(* given a pattern in a context of bound variables where the most recently
 * bound variable is the value to be matched, return a function that binds new
 * variables (including all the pattern variables) over an expression and the
 * new context of bound variables for the expression as well as the number of
 * newly bound variables *)
val _ = tDefine"compile_row"`
  (compile_row _ (NONE::bvs) (Pvar x) = ((SOME x::bvs), 0, I))
  ∧
  (compile_row _ bvs (Plit _) = (bvs, 0, I))
  ∧
  (*TODO: Consider whether we actually need to mk_cons in the line below or if
  * passing t on, as is, is fine *)
  (compile_row t bvs (Pcon _ ps) = compile_cols (mk_cons t 1) bvs 0 0 ps)
  ∧
  (compile_row t bvs (Pref p) =
   let (bvs,m,f) = (compile_row (mk_cons t 1) (NONE::bvs) p) in
   (bvs,(1+m), (λe. sLet (mk_cons t 2) (App (mk_cons t 3) (Op (Op Opderef)) [Var_local (mk_cons t 4) 0]) (f e))))
  ∧
  (compile_row _ bvs _ = (bvs, 0, I)) (* should not happen *)
  ∧
  (compile_cols _ bvs _ _ [] = (bvs, 0, I))
  ∧
  (compile_cols t bvs n k (p::ps) =
   let (bvs,m,f) = compile_row (mk_cons t 1) (NONE::bvs) p in
   let (bvs,ms,fs) = compile_cols (mk_cons t 2) bvs ((n+1)+m) (k+1) ps in
   (bvs,(1+m)+ms,
    (λe. sLet (mk_cons t 3) (App (mk_cons t 4) (El k) [Var_local (mk_cons t 5) n])
           (f (fs e)))))`
  cheat;
  (* (WF_REL_TAC `inv_image $< (\x. dtcase x of INL (bvs,p) => pat_size p
                                         | INR (bvs,n,k,ps) => pat1_size ps)`); *)

(* translate under a context of bound variables *)
(* compile_pes assumes the value being matched is most recently bound *)
val compile_exp_def = tDefine"compile_exp"`
  (compile_exp bvs (Raise t e) = Raise t (compile_exp bvs e))
  ∧
  (compile_exp bvs (Handle t e1 pes) =
   Handle (mk_cons t 1) (compile_exp bvs e1) (compile_pes (mk_cons t 2) (NONE::bvs) pes))
  ∧
  (compile_exp _ (Lit t l) = Lit t l)
  ∧
  (compile_exp bvs (Con t tag es) = Con t tag (compile_exps bvs es))
  ∧
  (compile_exp bvs (Var_local t x) =
   (dtcase find_index (SOME x) bvs 0 of
    | SOME k => Var_local t k
    | NONE => Lit t (IntLit 0) (* should not happen *)))
  ∧
  (compile_exp _ (Var_global t n) = Var_global t n)
  ∧
  (compile_exp bvs (Fun t x e) = Fun t (compile_exp (SOME x::bvs) e))
  ∧
  (compile_exp bvs (App t op es) = App t (Op op) (compile_exps bvs es))
  ∧
  (compile_exp bvs (Mat t e pes) =
   sLet (mk_cons t 1) (compile_exp bvs e) (compile_pes (mk_cons t 2) (NONE::bvs) pes))
  ∧
  (compile_exp bvs (Let t (SOME x) e1 e2) =
   sLet t (compile_exp bvs e1) (compile_exp (SOME x::bvs) e2))
  ∧
  (compile_exp bvs (Let t NONE e1 e2) =
   Seq t (compile_exp bvs e1) (compile_exp bvs e2))
  ∧
  (compile_exp bvs (Letrec t funs e) =
   let bvs = (MAP (SOME o FST) funs) ++ bvs in
   Letrec t (compile_funs bvs funs) (compile_exp bvs e))
  ∧
  (compile_exp _ (Extend_global t n) = Extend_global t n)
  ∧
  (compile_exps _ [] = [])
  ∧
  (compile_exps bvs (e::es) =
   compile_exp bvs e :: compile_exps bvs es)
  ∧
  (compile_funs _ [] = [])
  ∧
  (compile_funs bvs ((_,x,e)::funs) =
   compile_exp (SOME x::bvs) e :: compile_funs bvs funs)
  ∧
  (compile_pes tra bvs [(p,e)] =
   (dtcase compile_row (mk_cons tra 1) bvs p of (bvs,_,f) => f (compile_exp bvs e)))
  ∧
  (compile_pes tra bvs ((p,e)::pes) =
   sIf (mk_cons tra 1) (compile_pat (mk_cons tra 2) p)
     (dtcase compile_row (mk_cons tra 3) bvs p of (bvs,_,f) => f (compile_exp bvs e) )
     (compile_pes (mk_cons tra 4) bvs pes))
  ∧
  (compile_pes t _ _ = Lit (mk_cons t 1) (IntLit 0))`
  cheat;
  (*(WF_REL_TAC `inv_image $< (\x. dtcase x of INL (bvs,e) => exp_size e
                                         | INR (INL (bvs,es)) => exp6_size es
                                         | INR (INR (INL (bvs,funs))) => exp1_size funs
                                         | INR (INR (INR (bvs,pes))) =>
                                             exp3_size pes)`);*)
val _ = export_rewrites["compile_exp_def"];

val compile_def = Define`
  compile = compile_exp []`;

val compile_funs_map = Q.store_thm("compile_funs_map",
  `∀funs bvs. compile_funs bvs funs = MAP (λ(f,x,e). compile_exp (SOME x::bvs) e) funs`,
  Induct>>simp[pairTheory.FORALL_PROD])

val compile_exps_map = Q.store_thm("compile_exps_map",
  `∀es. compile_exps a es = MAP (compile_exp a) es`,
  Induct >> simp[compile_exp_def])

val compile_exps_reverse = Q.store_thm("compile_exps_reverse",
  `compile_exps a (REVERSE ls) = REVERSE (compile_exps a ls)`,
  rw[compile_exps_map,rich_listTheory.MAP_REVERSE])

val _ = export_theory()
