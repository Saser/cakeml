open preamble bvlTheory bviTheory;
open backend_commonTheory
local open bvl_inlineTheory bvl_constTheory bvl_handleTheory bvi_letTheory dataLangTheory in end;

val _ = new_theory "bvl_to_bvi";

val destLet_def = Define `
  (destLet ((Let xs b):bvl$exp) = (xs,b)) /\
  (destLet _ = ([],Var 0))`;

val large_int = ``268435457:int`` (* 2**28-1 *)

val compile_int_def = tDefine "compile_int" `
  compile_int (i:int) =
    if 0 <= i then
      if i <= ^large_int then
        (Op (Const i) []:bvi$exp)
      else
        let x = compile_int (i / ^large_int) in
        let y = Op (Const (i % ^large_int)) [] in
        let n = Op (Const ^large_int) [] in
          Op Add [Op Mult [x; n]; y]
    else
      if -^large_int <= i then
        Op (Const i) []
      else
        let i = 0 - i in
        let x = compile_int (i / ^large_int) in
        let y = Op (Const (0 - (i % ^large_int))) [] in
        let n = Op (Const (0 - ^large_int)) [] in
          Op Add [Op Mult [x; n]; y]`
 (WF_REL_TAC `measure (Num o ABS)`
  \\ REPEAT STRIP_TAC \\ intLib.COOPER_TAC)

val alloc_glob_count_def = tDefine "alloc_glob_count" `
  (alloc_glob_count [] = 0:num) /\
  (alloc_glob_count (x::y::xs) =
     alloc_glob_count [x] + alloc_glob_count (y::xs) /\
  (alloc_glob_count [(Var _):bvl$exp] = 0) /\
  (alloc_glob_count [If x y z] =
     alloc_glob_count [x] +
     alloc_glob_count [y] +
     alloc_glob_count [z]) /\
  (alloc_glob_count [Handle x y] =
     alloc_glob_count [x] +
     alloc_glob_count [y]) /\
  (alloc_glob_count [Tick x] = alloc_glob_count [x]) /\
  (alloc_glob_count [Raise x] = alloc_glob_count [x]) /\
  (alloc_glob_count [Let xs x] = alloc_glob_count (x::xs)) /\
  (alloc_glob_count [Call _ _ xs] = alloc_glob_count xs) /\
  (alloc_glob_count [Op op xs] =
     if op = AllocGlobal then 1 + alloc_glob_count xs
                         else alloc_glob_count xs) /\
  (alloc_glob_count [_] = 0))`
  (WF_REL_TAC `measure exp1_size`)

val AllocGlobal_location_def = Define`
  AllocGlobal_location = data_num_stubs`;
val CopyGlobals_location_def = Define`
  CopyGlobals_location = AllocGlobal_location+1`;
val InitGlobals_location_def = Define`
  InitGlobals_location = CopyGlobals_location+1`;
val ListLength_location_def = Define`
  ListLength_location = InitGlobals_location+1`;

val AllocGlobal_location_eq = save_thm("AllocGlobal_location_eq",
  ``AllocGlobal_location`` |> EVAL);
val CopyGlobals_location_eq = save_thm("CopyGlobals_location_eq",
  ``CopyGlobals_location`` |> EVAL);
val InitGlobals_location_eq = save_thm("InitGlobals_location_eq",
  ``InitGlobals_location`` |> EVAL);
val ListLength_location_eq = save_thm("ListLength_location_eq",
  ``ListLength_location`` |> EVAL);

val AllocGlobal_code_def = Define`
  AllocGlobal_code = (0:num,
    Let [Op GlobalsPtr []]
     (Let [Op Deref [Op (Const 0) []; Var 0]]
       (Let [Op Update [Op Add [Var 0; Op(Const 1)[]]; Op (Const 0) []; Var 1]]
         (Let [Op Length [Var 2]]
           (If (Op Less [Var 0; Var 2]) (Var 1)
               (Let [Op RefArray [Op (Const 0) []; Op Add [Var 0; Var 0]]]
                 (Let [Op SetGlobalsPtr [Var 0]]
                   (Call 0 (SOME CopyGlobals_location) [Var 1; Var 5; Op Sub [Op (Const 1) []; Var 4]] NONE))))))))`;

val CopyGlobals_code_def = Define`
  CopyGlobals_code = (3:num, (* ptr to new array, ptr to old array, index to copy *)
    Let [Op Update [Op Deref [Var 2; Var 1]; Var 2; Var 0]]
      (If (Op Equal [Op(Const 0)[]; Var 3]) (Var 0)
        (Call 0 (SOME CopyGlobals_location) [Var 1; Var 2; Op Sub [Op(Const 1)[];Var 3]] NONE)))`;

val InitGlobals_max_def = Define`
  InitGlobals_max = 10000n`;

val InitGlobals_code_def = Define`
  InitGlobals_code start n = (0:num,
    let n = MIN (MAX n 1) InitGlobals_max in
      Let [Op RefArray [Op (Const 0) []; Op (Const (&n)) []]]
        (Let [Op Update [Op (Const 1) []; Op (Const 0) []; Var 0]]
          (Let [Op SetGlobalsPtr [Var 1]]
             (Call 0 (SOME start) [] (SOME (Var 0))))))`;

val ListLength_code_def = Define `
  ListLength_code = (2n, (* ptr to array, accumulated length *)
    If (Op (TagLenEq nil_tag 0) [Var 0])
      (Var 1) (Call 0 (SOME ListLength_location)
                [Op El [Op (Const 1) []; Var 0];
                 Op Add [Var 1; Op (Const 1) []]] NONE))`

val stubs_def = Define `
  stubs start n = [(AllocGlobal_location, AllocGlobal_code);
                   (CopyGlobals_location, CopyGlobals_code);
                   (InitGlobals_location, InitGlobals_code start n);
                   (ListLength_location, ListLength_code)]`;

val _ = temp_overload_on ("num_stubs", ``backend_common$bvl_num_stubs``)

val compile_op_def = Define `
  compile_op op c1 =
    case op of
    | Const i => (case c1 of [] => compile_int i
                  | _ => Let [Op (Const 0) c1] (compile_int i))
    | Global n => Op Deref (c1++[compile_int(&(n+1)); Op GlobalsPtr []])
    | SetGlobal n => Op Update (c1++[compile_int(&(n+1)); Op GlobalsPtr []])
    | AllocGlobal =>
        (case c1 of [] => Call 0 (SOME AllocGlobal_location) [] NONE
         | _ => Let [Op (Const 0) c1] (Call 0 (SOME AllocGlobal_location) [] NONE))
    | (FromList n) => Let (if NULL c1 then [Op (Const 0) []] else c1)
                        (Op (FromList n)
                        [Var 0; Call 0 (SOME ListLength_location)
                                   [Var 0; Op (Const 0) []] NONE])
    | _ => Op op c1`

val _ = temp_overload_on("++",``SmartAppend``);

val compile_aux_def = Define`
  compile_aux (k,args,p) =
    List[(num_stubs + 2 * k + 1, args, bvi_let$compile_exp p)]`;

val compile_exps_def = tDefine "compile_exps" `
  (compile_exps n [] = ([],Nil,n)) /\
  (compile_exps n ((x:bvl$exp)::y::xs) =
     let (c1,aux1,n1) = compile_exps n [x] in
     let (c2,aux2,n2) = compile_exps n1 (y::xs) in
       (c1 ++ c2, aux1 ++ aux2, n2)) /\
  (compile_exps n [Var v] = ([(Var v):bvi$exp], Nil, n)) /\
  (compile_exps n [If x1 x2 x3] =
     let (c1,aux1,n1) = compile_exps n [x1] in
     let (c2,aux2,n2) = compile_exps n1 [x2] in
     let (c3,aux3,n3) = compile_exps n2 [x3] in
       ([If (HD c1) (HD c2) (HD c3)],aux1++aux2++aux3,n3)) /\
  (compile_exps n [Let xs x2] =
     if NULL xs (* i.e. a marker *) then
       let (args,x0) = destLet x2 in
       let (c1,aux1,n1) = compile_exps n args in
       let (c2,aux2,n2) = compile_exps n1 [x0] in
       let n3 = n2 + 1 in
         ([Call 0 (SOME (num_stubs + 2 * n2 + 1)) c1 NONE],
          aux1++aux2++compile_aux(n2,LENGTH args,HD c2), n3)
     else
       let (c1,aux1,n1) = compile_exps n xs in
       let (c2,aux2,n2) = compile_exps n1 [x2] in
         ([Let c1 (HD c2)], aux1++aux2, n2)) /\
  (compile_exps n [Raise x1] =
     let (c1,aux1,n1) = compile_exps n [x1] in
       ([Raise (HD c1)], aux1, n1)) /\
  (compile_exps n [Tick x1] =
     let (c1,aux1,n1) = compile_exps n [x1] in
       ([Tick (HD c1)], aux1, n1)) /\
  (compile_exps n [Op op xs] =
     let (c1,aux1,n1) = compile_exps n xs in
       ([compile_op op c1],aux1,n1)) /\
  (compile_exps n [Handle x1 x2] =
     let (args,x0) = destLet x1 in
     let (c1,aux1,n1) = compile_exps n args in
     let (c2,aux2,n2) = compile_exps n1 [x0] in
     let (c3,aux3,n3) = compile_exps n2 [x2] in
     let aux4 = compile_aux(n3,LENGTH args,HD c2) in
     let n4 = n3 + 1 in
       ([Call 0 (SOME (num_stubs + 2 * n3 + 1)) c1 (SOME (HD c3))],
        aux1++aux2++aux3++aux4, n4)) /\
  (compile_exps n [Call ticks dest xs] =
     let (c1,aux1,n1) = compile_exps n xs in
       ([Call ticks
              (case dest of
               | NONE => NONE
               | SOME n => SOME (num_stubs + 2 * n)) c1 NONE],aux1,n1))`
 (WF_REL_TAC `measure (exp1_size o SND)`
  \\ REPEAT STRIP_TAC \\ TRY DECIDE_TAC
  \\ TRY (Cases_on `x1`) \\ fs [destLet_def]
  \\ TRY (Cases_on `x2`) \\ fs [destLet_def]
  \\ SRW_TAC [] [bvlTheory.exp_size_def] \\ DECIDE_TAC);

val compile_exps_ind = theorem"compile_exps_ind";

val compile_exps_LENGTH_lemma = Q.prove(
  `!n xs. (LENGTH (FST (compile_exps n xs)) = LENGTH xs)`,
  HO_MATCH_MP_TAC compile_exps_ind \\ REPEAT STRIP_TAC
  \\ SIMP_TAC std_ss [compile_exps_def] \\ SRW_TAC [] []
  \\ FULL_SIMP_TAC (srw_ss()) [] \\ SRW_TAC [] [] \\ DECIDE_TAC);

val compile_exps_LENGTH = Q.store_thm("compile_exps_LENGTH",
  `(compile_exps n xs = (ys,aux,n1)) ==> (LENGTH ys = LENGTH xs)`,
  REPEAT STRIP_TAC \\ MP_TAC (SPEC_ALL compile_exps_LENGTH_lemma) \\ fs [])

val compile_exps_SING = Q.store_thm("compile_exps_SING",
  `(compile_exps n [x] = (c,aux,n1)) ==> ?y. c = [y]`,
  REPEAT STRIP_TAC \\ IMP_RES_TAC compile_exps_LENGTH
  \\ Cases_on `c` \\ fs [LENGTH_NIL]);

val inline_def = tDefine "inline" `
  (inline cs [] = []) /\
  (inline cs (x::y::xs) =
     HD (inline cs [x]) :: inline cs (y::xs)) /\
  (inline cs [Var v] = [Var v]) /\
  (inline cs [If x1 x2 x3] =
     [If (HD (inline cs [x1]))
         (HD (inline cs [x2]))
         (HD (inline cs [x3]))]) /\
  (inline cs [Let xs x2] =
     [Let (inline cs xs)
           (HD (inline cs [x2]))]) /\
  (inline cs [Raise x1] =
     [Raise (HD (inline cs [x1]))]) /\
  (inline cs [Op op xs] =
     [Op op (inline cs xs)]) /\
  (inline cs [Tick x] =
     [Tick (HD (inline cs [x]))]) /\
  (inline cs [Call ticks dest xs handler] =
     let ys = inline cs xs in
     let default = [Call ticks dest ys handler] in
       case handler of SOME h => default | NONE =>
       case dest of NONE => default | SOME n =>
       case lookup n cs of
       | NONE => default
       | SOME code => [Let ys (mk_tick (ticks+1) code)])`
  (WF_REL_TAC `measure (exp2_size o SND)`);

val LENGTH_inline = Q.store_thm("LENGTH_inline",
  `!cs xs. LENGTH (inline cs xs) = LENGTH xs`,
  recInduct (fetch "-" "inline_ind") \\ REPEAT STRIP_TAC
  \\ fs [Once inline_def,LET_DEF] \\ rw [] \\ every_case_tac \\ fs []);

val HD_inline = Q.store_thm("HD_inline[simp]",
  `[HD (inline cs [x])] = inline cs [x]`,
  `LENGTH (inline cs [x]) = LENGTH [x]` by SRW_TAC [] [LENGTH_inline]
  \\ Cases_on `inline cs [x]` \\ FULL_SIMP_TAC std_ss [LENGTH]
  \\ Cases_on `t` \\ FULL_SIMP_TAC std_ss [LENGTH,HD] \\ `F` by DECIDE_TAC);

val inline_x_def = Define `
  inline_x cs Nil = Nil /\
  inline_x cs (List ys) = List (MAP (\(n,a,c). (n,a,HD (inline cs [c]))) ys) /\
  inline_x cs (Append x y) = Append (inline_x cs x) (inline_x cs y)`;

val compile_single_def = Define `
  compile_single n (name,arg_count,exp) =
    let (c,aux,n1) = compile_exps n [exp] in
    let a = num_stubs + 2 * name in
    let c = HD c in
      (inline_x (insert a c LN) aux ++ List [(a,arg_count,c)],n1)`

val compile_list_def = Define `
  (compile_list n [] = (List [],n)) /\
  (compile_list n (p::progs) =
     let (code1,n1) = compile_single n p in
     let (code2,n2) = compile_list n1 progs in
       (code1 ++ code2,n2))`

val compile_prog_def = Define `
  compile_prog start n prog =
    let k = alloc_glob_count (MAP (\(_,_,p). p) prog) in
    let (code,n1) = compile_list n prog in
      (InitGlobals_location, bvl_to_bvi$stubs (num_stubs + 2 * start) k ++ append code, n1)`;

val optimise_def = Define `
  optimise split_seq cut_size ls =
    MAP (λ(name,arity,exp).
          (name,arity,bvl_handle$compile_any split_seq cut_size arity exp)) ls`;

val _ = Datatype`
  config = <| inline_size_limit : num (* zero disables inlining *)
            ; exp_cut : num (* huge number effectively disables exp splitting *)
            ; split_main_at_seq : bool (* split main expression at Seqs *)
            |>`;

val default_config_def = Define`
  default_config =
    <| inline_size_limit := 10
     ; exp_cut := 1000
     ; split_main_at_seq := T
     |>`;

val compile_def = Define `
  compile start n c prog =
    compile_prog start n
      (optimise c.split_main_at_seq c.exp_cut
         (bvl_inline$compile_prog c.inline_size_limit prog))`;

val _ = export_theory();
