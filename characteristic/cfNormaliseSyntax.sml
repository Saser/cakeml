structure cfNormaliseSyntax :> cfNormaliseSyntax = struct

open Abbrev
open HolKernel boolLib bossLib cfAppTheory
open cfNormaliseTheory

val s1 = HolKernel.syntax_fns1 "cfNormalise"
val s2 = HolKernel.syntax_fns2 "cfNormalise"

val (full_normalise_tm, mk_full_normalise, dest_full_normalise, is_full_normalise) = s2 "full_normalise"
val (full_normalise_prog_tm, mk_full_normalise_prog, dest_full_normalise_prog, is_full_normalise_prog) = s1 "full_normalise_prog"
val (full_normalise_decl_tm, mk_full_normalise_decl, dest_full_normalise_decl, is_full_normalise_decl) = s1 "full_normalise_decl"
val (full_normalise_exp_tm, mk_full_normalise_exp, dest_full_normalise_exp, is_full_normalise_exp) = s1 "full_normalise_exp"

end
