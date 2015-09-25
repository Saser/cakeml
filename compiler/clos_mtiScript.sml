open preamble closLangTheory;

val _ = new_theory "clos_mti";

val collect_args_def = Define `
  (collect_args num_args (Fn loc fvs num_args' e) =
    if num_args + num_args' ≤ max_app then
      collect_args (num_args + num_args') e
    else
      (max_app, Fn loc fvs (num_args + num_args' - max_app) e)) ∧
  (collect_args num_args e = (num_args, e))`;

val collect_args_ind = theorem"collect_args_ind";

val collect_args_size = Q.prove (
  `!num_args e num_args' e'.
    (num_args', e') = collect_args num_args e ⇒
    num_args' + exp_size e' ≤ num_args + exp_size e`,
   ho_match_mp_tac collect_args_ind >>
   rw [collect_args_def, exp_size_def] >>
   rw [exp_size_def] >>
   res_tac >>
   decide_tac);

val collect_args_more = Q.prove (
  `!num_args e num_args' e'.
    num_args ≤ max_app ∧
    (num_args', e') = collect_args num_args e
    ⇒
    num_args' ≤ max_app ∧ num_args ≤ num_args'`,
  ho_match_mp_tac collect_args_ind >>
  rw [collect_args_def] >>
  rw [] >>
  res_tac >>
  decide_tac);

val collect_args_zero = Q.store_thm("collect_args_zero",
  `!num_args e e'.
    collect_args num_args e = (0, e')
    ⇒
    num_args = 0`,
  ho_match_mp_tac collect_args_ind >>
  rw [collect_args_def] >>
  rw [collect_args_def] >>
  fs [max_app_def]);

val intro_multi_def = tDefine "intro_multi"`
  (intro_multi [] = []) ∧
  (intro_multi (e1::e2::es) =
    HD (intro_multi [e1]) :: HD (intro_multi [e2]) :: intro_multi es) ∧
  (intro_multi [Var n] = [Var n]) ∧
  (intro_multi [If e1 e2 e3] =
    [If (HD (intro_multi [e1])) (HD (intro_multi [e2])) (HD (intro_multi [e3]))]) ∧
  (intro_multi [Let es e] =
    [Let (intro_multi es) (HD (intro_multi [e]))]) ∧
  (intro_multi [Raise e] =
    [Raise (HD (intro_multi [e]))]) ∧
  (intro_multi [Handle e1 e2] =
    [Handle (HD (intro_multi [e1])) (HD (intro_multi [e2]))]) ∧
  (intro_multi [Tick e] =
    [Tick (HD (intro_multi [e]))]) ∧
  (intro_multi [Call n es] =
    [Call n (intro_multi es)]) ∧
  (intro_multi [App loc e es] =
    [App loc (HD (intro_multi [e])) (intro_multi es)]) ∧
  (intro_multi [Fn loc fvs num_args e] =
    let (num_args', e') = collect_args num_args e in
      [Fn loc fvs num_args' (HD (intro_multi [e']))]) ∧
  (intro_multi [Letrec loc fvs funs e] =
    [Letrec loc fvs (MAP (\(num_args, e).
                           let (num_args', e') = collect_args num_args e in
                             (num_args', HD (intro_multi [e'])))
                         funs)
        (HD (intro_multi [e]))]) ∧
  (intro_multi [Op op es] =
    [Op op (intro_multi es)])`
  (WF_REL_TAC `measure exp3_size` >>
   srw_tac [ARITH_ss] [exp_size_def] >>
   imp_res_tac collect_args_size >>
   TRY decide_tac >>
   `num_args + exp_size e' ≤ exp1_size funs`
           by (Induct_on `funs` >>
               rw [exp_size_def] >>
               rw [exp_size_def] >>
               res_tac >>
               decide_tac) >>
   decide_tac);

val intro_multi_ind = theorem"intro_multi_ind";

val intro_multi_length = Q.store_thm("intro_multi_length",
  `!es. LENGTH (intro_multi es) = LENGTH es`,
  recInduct intro_multi_ind >>
  rw [intro_multi_def] >>
  rw [intro_multi_def]);

val intro_multi_sing = Q.prove (
  `!e. ?e'. intro_multi [e] = [e']`,
  Cases_on `e` >>
  rw [intro_multi_def] >>
  Cases_on `collect_args n e'` >>
  fs []);

val collect_args_idem = Q.prove (
  `!num_args e num_args' e'.
    collect_args num_args e = (num_args', e')
    ⇒
    collect_args num_args' (HD (intro_multi [e'])) = (num_args', (HD (intro_multi [e'])))`,
  ho_match_mp_tac collect_args_ind >>
  rw [collect_args_def, intro_multi_def] >>
  rw [collect_args_def, intro_multi_def] >>
  fs [NOT_LESS_EQUAL] >>
  `num_args'' = 0` by decide_tac >>
  rw [] >>
  imp_res_tac collect_args_zero >>
  fs [] >>
  `max_app< max_app` by decide_tac >>
  fs []);

val intro_multi_idem = Q.store_thm("intro_multi_idem",
  `!e. intro_multi (intro_multi e) = intro_multi e`,
  ho_match_mp_tac intro_multi_ind >>
  rw [intro_multi_def] >>
  rw [intro_multi_def]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD]
  >- metis_tac [intro_multi_sing, HD, collect_args_idem, PAIR_EQ]
  >- (rw [LET_THM, MAP_MAP_o, combinTheory.o_DEF, UNCURRY] >>
      rw [MAP_EQ_f] >>
      PairCases_on `x` >>
      simp [] >>
      Cases_on `collect_args x0 x1` >>
      simp [] >>
      res_tac >>
      rfs [] >>
      metis_tac [intro_multi_sing, HD, collect_args_idem, PAIR_EQ, FST, SND])
  >- metis_tac [intro_multi_sing, HD]);

val _ = export_theory()
