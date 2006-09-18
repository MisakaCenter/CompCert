(** Correctness of the Cminor smart constructors.  This file states
  evaluation rules for the smart constructors, for instance that [add
  a b] evaluates to [Vint(Int.add i j)] if [a] evaluates to [Vint i]
  and [b] to [Vint j].  It then proves that these rules are
  admissible, that is, satisfied for all possible choices of [a] and
  [b].  The Cminor producer can then use these evaluation rules
  (theorems) to reason about the execution of terms produced by the
  smart constructors.
*)

Require Import Coqlib.
Require Import Compare_dec.
Require Import Maps.
Require Import AST.
Require Import Integers.
Require Import Floats.
Require Import Values.
Require Import Mem.
Require Import Events.
Require Import Op.
Require Import Globalenvs.
Require Import Cminor.
Require Import Cmconstr.

Section CMCONSTR.

Variable ge: Cminor.genv.

(** * Lifting of let-bound variables *)

Inductive insert_lenv: letenv -> nat -> val -> letenv -> Prop :=
  | insert_lenv_0:
      forall le v,
      insert_lenv le O v (v :: le)
  | insert_lenv_S:
      forall le p w le' v,
      insert_lenv le p w le' ->
      insert_lenv (v :: le) (S p) w (v :: le').

Lemma insert_lenv_lookup1:
  forall le p w le',
  insert_lenv le p w le' ->
  forall n v,
  nth_error le n = Some v -> (p > n)%nat ->
  nth_error le' n = Some v.
Proof.
  induction 1; intros.
  omegaContradiction.
  destruct n; simpl; simpl in H0. auto. 
  apply IHinsert_lenv. auto. omega.
Qed.

Lemma insert_lenv_lookup2:
  forall le p w le',
  insert_lenv le p w le' ->
  forall n v,
  nth_error le n = Some v -> (p <= n)%nat ->
  nth_error le' (S n) = Some v.
Proof.
  induction 1; intros.
  simpl. assumption.
  simpl. destruct n. omegaContradiction. 
  apply IHinsert_lenv. exact H0. omega.
Qed.

Scheme eval_expr_ind_3 := Minimality for eval_expr Sort Prop
  with eval_condexpr_ind_3 := Minimality for eval_condexpr Sort Prop
  with eval_exprlist_ind_3 := Minimality for eval_exprlist Sort Prop.

Hint Resolve eval_Evar eval_Eop eval_Eload eval_Estore
             eval_Ecall eval_Econdition eval_Ealloc
             eval_Elet eval_Eletvar 
             eval_CEtrue eval_CEfalse eval_CEcond
             eval_CEcondition eval_Enil eval_Econs: evalexpr.

Lemma eval_list_one:
  forall sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_exprlist ge sp le e m1 (a ::: Enil) t m2 (v :: nil).
Proof.
  intros. econstructor. eauto. constructor. traceEq.
Qed.

Lemma eval_list_two:
  forall sp le e m1 a1 t1 m2 v1 a2 t2 m3 v2 t,
  eval_expr ge sp le e m1 a1 t1 m2 v1 ->
  eval_expr ge sp le e m2 a2 t2 m3 v2 ->
  t = t1 ** t2 ->
  eval_exprlist ge sp le e m1 (a1 ::: a2 ::: Enil) t m3 (v1 :: v2 :: nil).
Proof.
  intros. econstructor. eauto. econstructor. eauto. constructor. 
  reflexivity. traceEq.
Qed.

Lemma eval_list_three:
  forall sp le e m1 a1 t1 m2 v1 a2 t2 m3 v2 a3 t3 m4 v3 t,
  eval_expr ge sp le e m1 a1 t1 m2 v1 ->
  eval_expr ge sp le e m2 a2 t2 m3 v2 ->
  eval_expr ge sp le e m3 a3 t3 m4 v3 ->
  t = t1 ** t2 ** t3 ->
  eval_exprlist ge sp le e m1 (a1 ::: a2 ::: a3 ::: Enil) t m4 (v1 :: v2 :: v3 :: nil).
Proof.
  intros. econstructor. eauto. econstructor. eauto. econstructor. eauto. constructor. 
  reflexivity. reflexivity. traceEq.
Qed.

Hint Resolve eval_list_one eval_list_two eval_list_three: evalexpr.

Lemma eval_lift_expr:
  forall w sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  forall p le', insert_lenv le p w le' ->
  eval_expr ge sp le' e m1 (lift_expr p a) t m2 v.
Proof.
  intros w.
  apply (eval_expr_ind_3 ge
    (fun sp le e m1 a t m2 v =>
      forall p le', insert_lenv le p w le' ->
      eval_expr ge sp le' e m1 (lift_expr p a) t m2 v)
    (fun sp le e m1 a t m2 vb =>
      forall p le', insert_lenv le p w le' ->
      eval_condexpr ge sp le' e m1 (lift_condexpr p a) t m2 vb)
    (fun sp le e m1 al t m2 vl =>
      forall p le', insert_lenv le p w le' ->
      eval_exprlist ge sp le' e m1 (lift_exprlist p al) t m2 vl));
  simpl; intros; eauto with evalexpr.

  destruct v1; eapply eval_Econdition;
  eauto with evalexpr; simpl; eauto with evalexpr.

  eapply eval_Elet. eauto. apply H2. apply insert_lenv_S; auto. auto.

  case (le_gt_dec p n); intro. 
  apply eval_Eletvar. eapply insert_lenv_lookup2; eauto.
  apply eval_Eletvar. eapply insert_lenv_lookup1; eauto.

  destruct vb1; eapply eval_CEcondition;
  eauto with evalexpr; simpl; eauto with evalexpr.
Qed.

Lemma eval_lift:
  forall sp le e m1 a t m2 v w,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_expr ge sp (w::le) e m1 (lift a) t m2 v.
Proof.
  intros. unfold lift. eapply eval_lift_expr.
  eexact H. apply insert_lenv_0. 
Qed.
Hint Resolve eval_lift: evalexpr.

(** * Useful lemmas and tactics *)

Ltac EvalOp := eapply eval_Eop; eauto with evalexpr.

Ltac TrivialOp cstr :=
  unfold cstr; intros; EvalOp.

(** The following are trivial lemmas and custom tactics that help
  perform backward (inversion) and forward reasoning over the evaluation
  of operator applications. *)  

Lemma inv_eval_Eop_0:
  forall sp le e m1 op t m2 v,
  eval_expr ge sp le e m1 (Eop op Enil) t m2 v ->
  t = E0 /\ m2 = m1 /\ eval_operation ge sp op nil = Some v.
Proof.
  intros. inversion H. inversion H6. 
  intuition. congruence.
Qed.
  
Lemma inv_eval_Eop_1:
  forall sp le e m1 op t a1 m2 v,
  eval_expr ge sp le e m1 (Eop op (a1 ::: Enil)) t m2 v ->
  exists v1,
  eval_expr ge sp le e m1 a1 t m2 v1 /\
  eval_operation ge sp op (v1 :: nil) = Some v.
Proof.
  intros. 
  inversion H. inversion H6. inversion H18. 
  subst. exists v1; intuition. rewrite E0_right. auto.
Qed.

Lemma inv_eval_Eop_2:
  forall sp le e m1 op a1 a2 t3 m3 v,
  eval_expr ge sp le e m1 (Eop op (a1 ::: a2 ::: Enil)) t3 m3 v ->
  exists t1, exists t2, exists m2, exists v1, exists v2,
  eval_expr ge sp le e m1 a1 t1 m2 v1 /\
  eval_expr ge sp le e m2 a2 t2 m3 v2 /\
  t3 = t1 ** t2 /\
  eval_operation ge sp op (v1 :: v2 :: nil) = Some v.
Proof.
  intros. 
  inversion H. subst. inversion H6. subst. inversion H8. subst.
  inversion H11. subst. 
  exists t1; exists t0; exists m0; exists v0; exists v1.
  intuition. traceEq.
Qed.

Ltac SimplEval :=
  match goal with
  | [ |- (eval_expr _ ?sp ?le ?e ?m1 (Eop ?op Enil) ?t ?m2 ?v) -> _] =>
      intro XX1;
      generalize (inv_eval_Eop_0 sp le e m1 op t m2 v XX1);
      clear XX1;
      intros [XX1 [XX2 XX3]];
      subst t m2; simpl in XX3; 
      try (simplify_eq XX3; clear XX3;
      let EQ := fresh "EQ" in (intro EQ; rewrite EQ))
  | [ |- (eval_expr _ ?sp ?le ?e ?m1 (Eop ?op (?a1 ::: Enil)) ?t ?m2 ?v) -> _] =>
      intro XX1;
      generalize (inv_eval_Eop_1 sp le e m1 op t a1 m2 v XX1);
      clear XX1;
      let v1 := fresh "v" in let EV := fresh "EV" in
      let EQ := fresh "EQ" in
      (intros [v1 [EV EQ]]; simpl in EQ)
  | [ |- (eval_expr _ ?sp ?le ?e ?m1 (Eop ?op (?a1 ::: ?a2 ::: Enil)) ?t ?m2 ?v) -> _] =>
      intro XX1;
      generalize (inv_eval_Eop_2 sp le e m1 op a1 a2 t m2 v XX1);
      clear XX1;
      let t1 := fresh "t" in let t2 := fresh "t" in
      let m := fresh "m" in
      let v1 := fresh "v" in let v2 := fresh "v" in
      let EV1 := fresh "EV" in let EV2 := fresh "EV" in
      let EQ := fresh "EQ" in let TR := fresh "TR" in
      (intros [t1 [t2 [m [v1 [v2 [EV1 [EV2 [TR EQ]]]]]]]]; simpl in EQ)
  | _ => idtac
  end.

Ltac InvEval H :=
  generalize H; SimplEval; clear H.

(** ** Admissible evaluation rules for the smart constructors *)

(** All proofs follow a common pattern:
- Reasoning by case over the result of the classification functions
  (such as [add_match] for integer addition), gathering additional
  information on the shape of the argument expressions in the non-default
  cases.
- Inversion of the evaluations of the arguments, exploiting the additional
  information thus gathered.
- Equational reasoning over the arithmetic operations performed,
  using the lemmas from the [Int] and [Float] modules.
- Construction of an evaluation derivation for the expression returned
  by the smart constructor.
*)

Theorem eval_negint:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (negint a) t m2 (Vint (Int.neg x)).
Proof.
  TrivialOp negint. 
Qed.

Theorem eval_negfloat:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vfloat x) ->
  eval_expr ge sp le e m1 (negfloat a) t m2 (Vfloat (Float.neg x)).
Proof.
  TrivialOp negfloat.
Qed.

Theorem eval_absfloat:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vfloat x) ->
  eval_expr ge sp le e m1 (absfloat a) t m2 (Vfloat (Float.abs x)).
Proof.
  TrivialOp absfloat.
Qed.

Theorem eval_intoffloat:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vfloat x) ->
  eval_expr ge sp le e m1 (intoffloat a) t m2 (Vint (Float.intoffloat x)).
Proof.
  TrivialOp intoffloat.
Qed.

Theorem eval_floatofint:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (floatofint a) t m2 (Vfloat (Float.floatofint x)).
Proof.
  TrivialOp floatofint.
Qed.

Theorem eval_floatofintu:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (floatofintu a) t m2 (Vfloat (Float.floatofintu x)).
Proof.
  TrivialOp floatofintu.
Qed.

Theorem eval_notint:
  forall sp le e m1 a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (notint a) t m2 (Vint (Int.not x)).
Proof.
  unfold notint; intros until x; case (notint_match a); intros.
  InvEval H. FuncInv. EvalOp. simpl. congruence. 
  InvEval H. FuncInv. EvalOp. simpl. congruence. 
  InvEval H. FuncInv. EvalOp. simpl. congruence. 
  eapply eval_Elet. eexact H. 
  eapply eval_Eop.
  eapply eval_Econs. apply eval_Eletvar. simpl. reflexivity.
  eapply eval_Econs. apply eval_Eletvar. simpl. reflexivity.
  apply eval_Enil. reflexivity. reflexivity. 
  simpl. rewrite Int.or_idem. auto. traceEq.
Qed.

Lemma eval_notbool_base:
  forall sp le e m1 a t m2 v b,
  eval_expr ge sp le e m1 a t m2 v ->
  Val.bool_of_val v b ->
  eval_expr ge sp le e m1 (notbool_base a) t m2 (Val.of_bool (negb b)).
Proof. 
  TrivialOp notbool_base. simpl. 
  inversion H0. 
  rewrite Int.eq_false; auto.
  rewrite Int.eq_true; auto.
  reflexivity.
Qed.

Hint Resolve Val.bool_of_true_val Val.bool_of_false_val
             Val.bool_of_true_val_inv Val.bool_of_false_val_inv: valboolof.

Theorem eval_notbool:
  forall a sp le e m1 t m2 v b,
  eval_expr ge sp le e m1 a t m2 v ->
  Val.bool_of_val v b ->
  eval_expr ge sp le e m1 (notbool a) t m2 (Val.of_bool (negb b)).
Proof.
  assert (N1: forall v b, Val.is_false v -> Val.bool_of_val v b -> Val.is_true (Val.of_bool (negb b))).
    intros. inversion H0; simpl; auto; subst v; simpl in H.
    congruence. apply Int.one_not_zero. contradiction.
  assert (N2: forall v b, Val.is_true v -> Val.bool_of_val v b -> Val.is_false (Val.of_bool (negb b))).
    intros. inversion H0; simpl; auto; subst v; simpl in H.
    congruence. 

  induction a; simpl; intros; try (eapply eval_notbool_base; eauto).
  destruct o; try (eapply eval_notbool_base; eauto).

  destruct e. InvEval H. injection XX3; clear XX3; intro; subst v.
  inversion H0. rewrite Int.eq_false; auto. 
  simpl; eauto with evalexpr.
  rewrite Int.eq_true; simpl; eauto with evalexpr.
  eapply eval_notbool_base; eauto.

  inversion H. subst. 
  simpl in H11. eapply eval_Eop; eauto.
  simpl. caseEq (eval_condition c vl); intros.
  rewrite H1 in H11. 
  assert (b0 = b). 
  destruct b0; inversion H11; subst v; inversion H0; auto.
  subst b0. rewrite (Op.eval_negate_condition _ _ H1). 
  destruct b; reflexivity.
  rewrite H1 in H11; discriminate.

  inversion H; eauto 10 with evalexpr valboolof.
  inversion H; eauto 10 with evalexpr valboolof.

  inversion H. subst. eapply eval_Econdition with (t2 := t8). eexact H34.
  destruct v4; eauto. auto.
Qed.

Theorem eval_addimm:
  forall sp le e m1 n a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (addimm n a) t m2 (Vint (Int.add x n)).
Proof.
  unfold addimm; intros until x.
  generalize (Int.eq_spec n Int.zero). case (Int.eq n Int.zero); intro.
  subst n. rewrite Int.add_zero. auto.
  case (addimm_match a); intros.
  InvEval H0. EvalOp. simpl. rewrite Int.add_commut. auto.
  InvEval H0. destruct (Genv.find_symbol ge s); discriminate.
  InvEval H0. 
  destruct sp; simpl in XX3; discriminate.
  InvEval H0. FuncInv. EvalOp. simpl. subst x. 
  rewrite Int.add_assoc. decEq; decEq; decEq. apply Int.add_commut.
  EvalOp. 
Qed. 

Theorem eval_addimm_ptr:
  forall sp le e m1 n t a m2 b ofs,
  eval_expr ge sp le e m1 a t m2 (Vptr b ofs) ->
  eval_expr ge sp le e m1 (addimm n a) t m2 (Vptr b (Int.add ofs n)).
Proof.
  unfold addimm; intros until ofs.
  generalize (Int.eq_spec n Int.zero). case (Int.eq n Int.zero); intro.
  subst n. rewrite Int.add_zero. auto.
  case (addimm_match a); intros.
  InvEval H0. 
  InvEval H0. EvalOp. simpl. 
    destruct (Genv.find_symbol ge s). 
    rewrite Int.add_commut. congruence.
    discriminate.
  InvEval H0. destruct sp; simpl in XX3; try discriminate.
  inversion XX3. EvalOp. simpl. decEq. decEq. 
  rewrite Int.add_assoc. decEq. apply Int.add_commut.
  InvEval H0. FuncInv. subst b0; subst ofs. EvalOp. simpl. 
    rewrite (Int.add_commut n m). rewrite Int.add_assoc. auto.
  EvalOp. 
Qed.

Theorem eval_add:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (add a b) (t1**t2) m3 (Vint (Int.add x y)).
Proof.
  intros until y. unfold add; case (add_match a b); intros.
  InvEval H. rewrite Int.add_commut. apply eval_addimm. 
  rewrite E0_left; assumption.
  InvEval H. FuncInv. InvEval H0. FuncInv. 
    replace (Int.add x y) with (Int.add (Int.add i i0) (Int.add n1 n2)).
    apply eval_addimm. EvalOp. 
    subst x; subst y. 
    repeat rewrite Int.add_assoc. decEq. apply Int.add_permut. 
  InvEval H. FuncInv. 
    replace (Int.add x y) with (Int.add (Int.add i y) n1).
    apply eval_addimm. EvalOp.
    subst x. repeat rewrite Int.add_assoc. decEq. apply Int.add_commut.
  InvEval H0. FuncInv.
    apply eval_addimm. rewrite E0_right. auto.
  InvEval H0. FuncInv. 
    replace (Int.add x y) with (Int.add (Int.add x i) n2).
    apply eval_addimm. EvalOp.
    subst y. rewrite Int.add_assoc. auto.
  EvalOp.
Qed.

Theorem eval_add_ptr:
  forall sp le e m1 a t1 m2 p x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vptr p x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (add a b) (t1**t2) m3 (Vptr p (Int.add x y)).
Proof.
  intros until y. unfold add; case (add_match a b); intros.
  InvEval H. 
  InvEval H. FuncInv. InvEval H0. FuncInv. 
    replace (Int.add x y) with (Int.add (Int.add i i0) (Int.add n1 n2)).
    apply eval_addimm_ptr. subst b0. EvalOp. 
    subst x; subst y.
    repeat rewrite Int.add_assoc. decEq. apply Int.add_permut. 
  InvEval H. FuncInv. 
    replace (Int.add x y) with (Int.add (Int.add i y) n1).
    apply eval_addimm_ptr. subst b0. EvalOp.
    subst x. repeat rewrite Int.add_assoc. decEq. apply Int.add_commut.
  InvEval H0. apply eval_addimm_ptr. rewrite E0_right. auto.
  InvEval H0. FuncInv. 
    replace (Int.add x y) with (Int.add (Int.add x i) n2).
    apply eval_addimm_ptr. EvalOp.
    subst y. rewrite Int.add_assoc. auto.
  EvalOp.
Qed.

Theorem eval_add_ptr_2:
  forall sp le e m1 a t1 m2 p x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vptr p y) ->
  eval_expr ge sp le e m1 (add a b) (t1**t2) m3 (Vptr p (Int.add y x)).
Proof.
  intros until y. unfold add; case (add_match a b); intros.
  InvEval H. 
    apply eval_addimm_ptr. rewrite E0_left. auto.
  InvEval H. FuncInv. InvEval H0. FuncInv. 
    replace (Int.add y x) with (Int.add (Int.add i0 i) (Int.add n1 n2)).
    apply eval_addimm_ptr. subst b0. EvalOp. 
    subst x; subst y.
    repeat rewrite Int.add_assoc. decEq. 
    rewrite (Int.add_commut n1 n2). apply Int.add_permut. 
  InvEval H. FuncInv. 
    replace (Int.add y x) with (Int.add (Int.add y i) n1).
    apply eval_addimm_ptr. EvalOp. 
    subst x. repeat rewrite Int.add_assoc. auto.
  InvEval H0. 
  InvEval H0. FuncInv. 
    replace (Int.add y x) with (Int.add (Int.add i x) n2).
    apply eval_addimm_ptr. EvalOp. subst b0; reflexivity.
    subst y. repeat rewrite Int.add_assoc. decEq. apply Int.add_commut.
  EvalOp.
Qed.

Theorem eval_sub:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (sub a b) (t1**t2) m3 (Vint (Int.sub x y)).
Proof.
  intros until y.
  unfold sub; case (sub_match a b); intros.
  InvEval H0. rewrite Int.sub_add_opp. 
    apply eval_addimm. rewrite E0_right. assumption.
  InvEval H. FuncInv. InvEval H0. FuncInv.
    replace (Int.sub x y) with (Int.add (Int.sub i i0) (Int.sub n1 n2)).
    apply eval_addimm. EvalOp.
    subst x; subst y.
    repeat rewrite Int.sub_add_opp.
    repeat rewrite Int.add_assoc. decEq. 
    rewrite Int.add_permut. decEq. symmetry. apply Int.neg_add_distr.
  InvEval H. FuncInv. 
    replace (Int.sub x y) with (Int.add (Int.sub i y) n1).
    apply eval_addimm. EvalOp.
    subst x. rewrite Int.sub_add_l. auto.
  InvEval H0. FuncInv. 
    replace (Int.sub x y) with (Int.add (Int.sub x i) (Int.neg n2)).
    apply eval_addimm. EvalOp.
    subst y. rewrite (Int.add_commut i n2). symmetry. apply Int.sub_add_r. 
  EvalOp.
Qed.

Theorem eval_sub_ptr_int:
  forall sp le e m1 a t1 m2 p x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vptr p x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (sub a b) (t1**t2) m3 (Vptr p (Int.sub x y)).
Proof.
  intros until y.
  unfold sub; case (sub_match a b); intros.
  InvEval H0. rewrite Int.sub_add_opp. 
    apply eval_addimm_ptr. rewrite E0_right. assumption.
  InvEval H. FuncInv. InvEval H0. FuncInv.
    subst b0.
    replace (Int.sub x y) with (Int.add (Int.sub i i0) (Int.sub n1 n2)).
    apply eval_addimm_ptr. EvalOp.
    subst x; subst y.
    repeat rewrite Int.sub_add_opp.
    repeat rewrite Int.add_assoc. decEq. 
    rewrite Int.add_permut. decEq. symmetry. apply Int.neg_add_distr.
  InvEval H. FuncInv. subst b0.
    replace (Int.sub x y) with (Int.add (Int.sub i y) n1).
    apply eval_addimm_ptr. EvalOp.
    subst x. rewrite Int.sub_add_l. auto.
  InvEval H0. FuncInv. 
    replace (Int.sub x y) with (Int.add (Int.sub x i) (Int.neg n2)).
    apply eval_addimm_ptr. EvalOp.
    subst y. rewrite (Int.add_commut i n2). symmetry. apply Int.sub_add_r. 
  EvalOp.
Qed.

Theorem eval_sub_ptr_ptr:
  forall sp le e m1 a t1 m2 p x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vptr p x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vptr p y) ->
  eval_expr ge sp le e m1 (sub a b) (t1**t2) m3 (Vint (Int.sub x y)).
Proof.
  intros until y.
  unfold sub; case (sub_match a b); intros.
  InvEval H0. 
  InvEval H. FuncInv. InvEval H0. FuncInv.
    replace (Int.sub x y) with (Int.add (Int.sub i i0) (Int.sub n1 n2)).
    apply eval_addimm. EvalOp. 
    simpl; unfold eq_block. subst b0; subst b1; rewrite zeq_true. auto.
    subst x; subst y.
    repeat rewrite Int.sub_add_opp.
    repeat rewrite Int.add_assoc. decEq. 
    rewrite Int.add_permut. decEq. symmetry. apply Int.neg_add_distr.
  InvEval H. FuncInv. subst b0.
    replace (Int.sub x y) with (Int.add (Int.sub i y) n1).
    apply eval_addimm. EvalOp.
    simpl. unfold eq_block. rewrite zeq_true. auto.
    subst x. rewrite Int.sub_add_l. auto.
  InvEval H0. FuncInv. subst b0.
    replace (Int.sub x y) with (Int.add (Int.sub x i) (Int.neg n2)).
    apply eval_addimm. EvalOp.
    simpl. unfold eq_block. rewrite zeq_true. auto.
    subst y. rewrite (Int.add_commut i n2). symmetry. apply Int.sub_add_r. 
  EvalOp. simpl. unfold eq_block. rewrite zeq_true. auto.
Qed.

Lemma eval_rolm:
  forall sp le e m1 a amount mask t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (rolm a amount mask) t m2 (Vint (Int.rolm x amount mask)).
Proof.
  intros until x. unfold rolm; case (rolm_match a); intros.
  InvEval H. eauto with evalexpr. 
  case (Int.is_rlw_mask (Int.and (Int.rol mask1 amount) mask)).
  InvEval H. FuncInv. EvalOp. simpl. subst x. 
  decEq. decEq. 
  replace (Int.and (Int.add amount1 amount) (Int.repr 31))
     with (Int.modu (Int.add amount1 amount) (Int.repr 32)).
  symmetry. apply Int.rolm_rolm. 
  change (Int.repr 31) with (Int.sub (Int.repr 32) Int.one).
  apply Int.modu_and with (Int.repr 5). reflexivity.
  EvalOp. 
  EvalOp.
Qed.

Theorem eval_shlimm:
  forall sp le e m1 a n t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  Int.ltu n (Int.repr 32) = true ->
  eval_expr ge sp le e m1 (shlimm a n) t m2 (Vint (Int.shl x n)).
Proof.
  intros.  unfold shlimm.
  generalize (Int.eq_spec n Int.zero); case (Int.eq n Int.zero); intro.
  subst n. rewrite Int.shl_zero. auto.
  rewrite H0.
  replace (Int.shl x n) with (Int.rolm x n (Int.shl Int.mone n)).
  apply eval_rolm. auto. symmetry. apply Int.shl_rolm. exact H0.
Qed.

Theorem eval_shruimm:
  forall sp le e m1 a n t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  Int.ltu n (Int.repr 32) = true ->
  eval_expr ge sp le e m1 (shruimm a n) t m2 (Vint (Int.shru x n)).
Proof.
  intros.  unfold shruimm.
  generalize (Int.eq_spec n Int.zero); case (Int.eq n Int.zero); intro.
  subst n. rewrite Int.shru_zero. auto.
  rewrite H0.
  replace (Int.shru x n) with (Int.rolm x (Int.sub (Int.repr 32) n) (Int.shru Int.mone n)).
  apply eval_rolm. auto. symmetry. apply Int.shru_rolm. exact H0.
Qed.

Lemma eval_mulimm_base:
  forall sp le e m1 a t n m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (mulimm_base n a) t m2 (Vint (Int.mul x n)).
Proof.
  intros; unfold mulimm_base. 
  generalize (Int.one_bits_decomp n). 
  generalize (Int.one_bits_range n).
  change (Z_of_nat wordsize) with 32.
  destruct (Int.one_bits n).
  intros. EvalOp. 
  destruct l.
  intros. rewrite H1. simpl. 
  rewrite Int.add_zero. rewrite <- Int.shl_mul.
  apply eval_shlimm. auto. auto with coqlib. 
  destruct l.
  intros. apply eval_Elet with t m2 (Vint x) E0. auto.
  rewrite H1. simpl. rewrite Int.add_zero. 
  rewrite Int.mul_add_distr_r.
  rewrite <- Int.shl_mul.
  rewrite <- Int.shl_mul.
  EvalOp. eapply eval_Econs. 
  apply eval_shlimm. apply eval_Eletvar. simpl. reflexivity. 
  auto with coqlib.
  eapply eval_Econs.
  apply eval_shlimm. apply eval_Eletvar. simpl. reflexivity.
  auto with coqlib.
  auto with evalexpr.
  reflexivity. traceEq. reflexivity. traceEq. 
  intros. EvalOp. 
Qed.

Theorem eval_mulimm:
  forall sp le e m1 a n t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (mulimm n a) t m2 (Vint (Int.mul x n)).
Proof.
  intros until x; unfold mulimm.
  generalize (Int.eq_spec n Int.zero); case (Int.eq n Int.zero); intro.
  subst n. rewrite Int.mul_zero. 
  intro. eapply eval_Elet; eauto with evalexpr. traceEq.
  generalize (Int.eq_spec n Int.one); case (Int.eq n Int.one); intro.
  subst n. rewrite Int.mul_one. auto.
  case (mulimm_match a); intros.
  InvEval H1. EvalOp. rewrite Int.mul_commut. reflexivity.
  InvEval H1. FuncInv. 
  replace (Int.mul x n) with (Int.add (Int.mul i n) (Int.mul n n2)).
  apply eval_addimm. apply eval_mulimm_base. auto.
  subst x. rewrite Int.mul_add_distr_l. decEq. apply Int.mul_commut.
  apply eval_mulimm_base. assumption.
Qed.

Theorem eval_mul:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (mul a b) (t1**t2) m3 (Vint (Int.mul x y)).
Proof.
  intros until y.
  unfold mul; case (mul_match a b); intros.
  InvEval H. rewrite Int.mul_commut. apply eval_mulimm. 
  rewrite E0_left; auto.
  InvEval H0. rewrite E0_right. apply eval_mulimm. auto.
  EvalOp.
Qed.

Theorem eval_divs:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  y <> Int.zero ->
  eval_expr ge sp le e m1 (divs a b) (t1**t2) m3 (Vint (Int.divs x y)).
Proof.
  TrivialOp divs. simpl. 
  predSpec Int.eq Int.eq_spec y Int.zero. contradiction. auto.
Qed.

Lemma eval_mod_aux:
  forall divop semdivop,
  (forall sp x y,
   y <> Int.zero ->
   eval_operation ge sp divop (Vint x :: Vint y :: nil) =
   Some (Vint (semdivop x y))) ->
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  y <> Int.zero ->
  eval_expr ge sp le e m1 (mod_aux divop a b) (t1**t2) m3
   (Vint (Int.sub x (Int.mul (semdivop x y) y))).
Proof.
  intros; unfold mod_aux.
  eapply eval_Elet. eexact H0. eapply eval_Elet. 
  apply eval_lift. eexact H1.
  eapply eval_Eop. eapply eval_Econs. 
  eapply eval_Eletvar. simpl; reflexivity.
  eapply eval_Econs. eapply eval_Eop. 
  eapply eval_Econs. eapply eval_Eop.
  eapply eval_Econs. apply eval_Eletvar. simpl; reflexivity.
  eapply eval_Econs. apply eval_Eletvar. simpl; reflexivity.
  apply eval_Enil. reflexivity. reflexivity. 
  apply H. assumption.
  eapply eval_Econs. apply eval_Eletvar. simpl; reflexivity.
  apply eval_Enil. reflexivity. reflexivity. 
  simpl; reflexivity. apply eval_Enil. 
  reflexivity. reflexivity. reflexivity.
  reflexivity. traceEq.
Qed.

Theorem eval_mods:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  y <> Int.zero ->
  eval_expr ge sp le e m1 (mods a b) (t1**t2) m3 (Vint (Int.mods x y)).
Proof.
  intros; unfold mods. 
  rewrite Int.mods_divs. 
  eapply eval_mod_aux; eauto. 
  intros. simpl. predSpec Int.eq Int.eq_spec y0 Int.zero. 
  contradiction. auto.
Qed.

Lemma eval_divu_base:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  y <> Int.zero ->
  eval_expr ge sp le e m1 (Eop Odivu (a ::: b ::: Enil)) (t1**t2) m3 (Vint (Int.divu x y)).
Proof.
  intros. EvalOp. simpl. 
  predSpec Int.eq Int.eq_spec y Int.zero. contradiction. auto.
Qed.

Theorem eval_divu:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  y <> Int.zero ->
  eval_expr ge sp le e m1 (divu a b) (t1**t2) m3 (Vint (Int.divu x y)).
Proof.
  intros until y.
  unfold divu; case (divu_match b); intros.
  InvEval H0. caseEq (Int.is_power2 y). 
  intros. rewrite (Int.divu_pow2 x y i H0).
  apply eval_shruimm. rewrite E0_right. auto.
  apply Int.is_power2_range with y. auto.
  intros. subst n2. eapply eval_divu_base. eexact H. EvalOp. auto.
  eapply eval_divu_base; eauto.
Qed.

Theorem eval_modu:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  y <> Int.zero ->
  eval_expr ge sp le e m1 (modu a b) (t1**t2) m3 (Vint (Int.modu x y)).
Proof.
  intros until y; unfold modu; case (divu_match b); intros.
  InvEval H0. caseEq (Int.is_power2 y). 
  intros. rewrite (Int.modu_and x y i H0).
  rewrite <- Int.rolm_zero. apply eval_rolm. rewrite E0_right; auto.
  intro. rewrite Int.modu_divu. eapply eval_mod_aux. 
  intros. simpl. predSpec Int.eq Int.eq_spec y0 Int.zero.
  contradiction. auto.
  eexact H. EvalOp. auto. auto.
  rewrite Int.modu_divu. eapply eval_mod_aux. 
  intros. simpl. predSpec Int.eq Int.eq_spec y0 Int.zero.
  contradiction. auto.
  eexact H. eexact H0. auto. auto.
Qed.

Theorem eval_andimm:
  forall sp le e m1 n a t m2 x,
  eval_expr ge sp le e m1 a t m2 (Vint x) ->
  eval_expr ge sp le e m1 (andimm n a) t m2 (Vint (Int.and x n)).
Proof.
  intros.  unfold andimm. case (Int.is_rlw_mask n).
  rewrite <- Int.rolm_zero. apply eval_rolm; auto.
  EvalOp. 
Qed.

Theorem eval_and:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (and a b) (t1**t2) m3 (Vint (Int.and x y)).
Proof.
  intros until y; unfold and; case (mul_match a b); intros.
  InvEval H. rewrite Int.and_commut. 
  rewrite E0_left; apply eval_andimm; auto.
  InvEval H0. rewrite E0_right; apply eval_andimm; auto.
  EvalOp.
Qed.

Remark eval_same_expr_pure:
  forall a1 a2 sp le e m1 t1 m2 v1 t2 m3 v2,
  same_expr_pure a1 a2 = true ->
  eval_expr ge sp le e m1 a1 t1 m2 v1 ->
  eval_expr ge sp le e m2 a2 t2 m3 v2 ->
  t1 = E0 /\ t2 = E0 /\ a2 = a1 /\ v2 = v1 /\ m2 = m1.
Proof.
  intros until v2.
  destruct a1; simpl; try (intros; discriminate). 
  destruct a2; simpl; try (intros; discriminate).
  case (ident_eq i i0); intros.
  subst i0. inversion H0. inversion H1. 
  assert (v2 = v1). congruence. tauto.
  discriminate.
Qed.

Lemma eval_or:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (or a b) (t1**t2) m3 (Vint (Int.or x y)).
Proof.
  intros until y; unfold or; case (or_match a b); intros.
  generalize (Int.eq_spec amount1 amount2); case (Int.eq amount1 amount2); intro.
  case (Int.is_rlw_mask (Int.or mask1 mask2)).
  caseEq (same_expr_pure t0 t3); intro.
  simpl. InvEval H. FuncInv. InvEval H0. FuncInv. 
  generalize (eval_same_expr_pure _ _ _ _ _ _ _ _ _ _ _ _ H2 EV EV0).
  intros [EQ1 [EQ2 [EQ3 [EQ4 EQ5]]]]. 
  injection EQ4; intro EQ7. subst.
  EvalOp. simpl. rewrite Int.or_rolm. auto.
  simpl. EvalOp. 
  simpl. EvalOp. 
  simpl. EvalOp. 
  EvalOp.
Qed.

Theorem eval_xor:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (xor a b) (t1**t2) m3 (Vint (Int.xor x y)).
Proof. TrivialOp xor. Qed.

Theorem eval_shl:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  Int.ltu y (Int.repr 32) = true ->
  eval_expr ge sp le e m1 (shl a b) (t1**t2) m3 (Vint (Int.shl x y)).
Proof.
  intros until y; unfold shl; case (shift_match b); intros.
  InvEval H0. rewrite E0_right. apply eval_shlimm; auto.
  EvalOp. simpl. rewrite H1. auto.
Qed.

Theorem eval_shr:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  Int.ltu y (Int.repr 32) = true ->
  eval_expr ge sp le e m1 (shr a b) (t1**t2) m3 (Vint (Int.shr x y)).
Proof.
  TrivialOp shr. simpl. rewrite H1. auto.
Qed.

Theorem eval_shru:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  Int.ltu y (Int.repr 32) = true ->
  eval_expr ge sp le e m1 (shru a b) (t1**t2) m3 (Vint (Int.shru x y)).
Proof.
  intros until y; unfold shru; case (shift_match b); intros.
  InvEval H0. rewrite E0_right; apply eval_shruimm; auto.
  EvalOp. simpl. rewrite H1. auto.
Qed.

Theorem eval_addf:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vfloat x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vfloat y) ->
  eval_expr ge sp le e m1 (addf a b) (t1**t2) m3 (Vfloat (Float.add x y)).
Proof.
  intros until y; unfold addf; case (addf_match a b); intros.
  InvEval H. FuncInv. EvalOp. 
  econstructor; eauto. econstructor; eauto. econstructor; eauto. constructor.
  traceEq. simpl. subst x. reflexivity.
  InvEval H0. FuncInv. eapply eval_Elet. eexact H. EvalOp. 
  econstructor; eauto with evalexpr. 
  econstructor; eauto with evalexpr. 
  econstructor. apply eval_Eletvar. simpl; reflexivity.
  constructor. reflexivity. traceEq.
  subst y. rewrite Float.addf_commut. reflexivity. auto.
  EvalOp.
Qed.
 
Theorem eval_subf:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vfloat x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vfloat y) ->
  eval_expr ge sp le e m1 (subf a b) (t1**t2) m3 (Vfloat (Float.sub x y)).
Proof.
  intros until y; unfold subf; case (subf_match a b); intros.
  InvEval H. FuncInv. EvalOp. 
  econstructor; eauto. econstructor; eauto. econstructor; eauto. constructor.
  traceEq. subst x. reflexivity.
  EvalOp.
Qed.

Theorem eval_mulf:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vfloat x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vfloat y) ->
  eval_expr ge sp le e m1 (mulf a b) (t1**t2) m3 (Vfloat (Float.mul x y)).
Proof. TrivialOp mulf. Qed.

Theorem eval_divf:
  forall sp le e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vfloat x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vfloat y) ->
  eval_expr ge sp le e m1 (divf a b) (t1**t2) m3 (Vfloat (Float.div x y)).
Proof. TrivialOp divf. Qed.

Theorem eval_cast8signed:
  forall sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_expr ge sp le e m1 (cast8signed a) t m2 (Val.cast8signed v).
Proof. 
  intros until v; unfold cast8signed; case (cast8signed_match a); intros.
  replace (Val.cast8signed v) with v. auto. 
  InvEval H. inversion EQ. destruct v0; simpl; auto. rewrite Int.cast8_signed_idem. reflexivity.
  EvalOp.
Qed.

Theorem eval_cast8unsigned:
  forall sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_expr ge sp le e m1 (cast8unsigned a) t m2 (Val.cast8unsigned v).
Proof. 
  intros until v; unfold cast8unsigned; case (cast8unsigned_match a); intros.
  replace (Val.cast8unsigned v) with v. auto. 
  InvEval H. inversion EQ. destruct v0; simpl; auto. rewrite Int.cast8_unsigned_idem. reflexivity.
  EvalOp.
Qed.

Theorem eval_cast16signed:
  forall sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_expr ge sp le e m1 (cast16signed a) t m2 (Val.cast16signed v).
Proof. 
  intros until v; unfold cast16signed; case (cast16signed_match a); intros.
  replace (Val.cast16signed v) with v. auto. 
  InvEval H. inversion EQ. destruct v0; simpl; auto. rewrite Int.cast16_signed_idem. reflexivity.
  EvalOp.
Qed.

Theorem eval_cast16unsigned:
  forall sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_expr ge sp le e m1 (cast16unsigned a) t m2 (Val.cast16unsigned v).
Proof. 
  intros until v; unfold cast16unsigned; case (cast16unsigned_match a); intros.
  replace (Val.cast16unsigned v) with v. auto. 
  InvEval H. inversion EQ. destruct v0; simpl; auto. rewrite Int.cast16_unsigned_idem. reflexivity.
  EvalOp.
Qed.

Theorem eval_singleoffloat:
  forall sp le e m1 a t m2 v,
  eval_expr ge sp le e m1 a t m2 v ->
  eval_expr ge sp le e m1 (singleoffloat a) t m2 (Val.singleoffloat v).
Proof. 
  intros until v; unfold singleoffloat; case (singleoffloat_match a); intros.
  replace (Val.singleoffloat v) with v. auto. 
  InvEval H. inversion EQ. destruct v0; simpl; auto. rewrite Float.singleoffloat_idem. reflexivity.
  EvalOp.
Qed.

Theorem eval_cmp:
  forall sp le c e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (cmp c a b) (t1**t2) m3 (Val.of_bool (Int.cmp c x y)).
Proof. 
  TrivialOp cmp. 
  simpl. case (Int.cmp c x y); auto.
Qed.

Theorem eval_cmp_null_r:
  forall sp le c e m1 a t1 m2 p x b t2 m3 v,
  eval_expr ge sp le e m1 a t1 m2 (Vptr p x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint Int.zero) ->
  (c = Ceq /\ v = Vfalse) \/ (c = Cne /\ v = Vtrue) ->
  eval_expr ge sp le e m1 (cmp c a b) (t1**t2) m3 v.
Proof. 
  TrivialOp cmp. 
  simpl. elim H1; intros [EQ1 EQ2]; subst c; subst v; reflexivity.
Qed.

Theorem eval_cmp_null_l:
  forall sp le c e m1 a t1 m2 p x b t2 m3 v,
  eval_expr ge sp le e m1 a t1 m2 (Vint Int.zero) ->
  eval_expr ge sp le e m2 b t2 m3 (Vptr p x) ->
  (c = Ceq /\ v = Vfalse) \/ (c = Cne /\ v = Vtrue) ->
  eval_expr ge sp le e m1 (cmp c a b) (t1**t2) m3 v.
Proof. 
  TrivialOp cmp. 
  simpl. elim H1; intros [EQ1 EQ2]; subst c; subst v; reflexivity.
Qed.

Theorem eval_cmp_ptr:
  forall sp le c e m1 a t1 m2 p x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vptr p x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vptr p y) ->
  eval_expr ge sp le e m1 (cmp c a b) (t1**t2) m3 (Val.of_bool (Int.cmp c x y)).
Proof. 
  TrivialOp cmp. 
  simpl. unfold eq_block. rewrite zeq_true. 
  case (Int.cmp c x y); auto.
Qed.

Theorem eval_cmpu:
  forall sp le c e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vint x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vint y) ->
  eval_expr ge sp le e m1 (cmpu c a b) (t1**t2) m3 (Val.of_bool (Int.cmpu c x y)).
Proof. 
  TrivialOp cmpu. 
  simpl. case (Int.cmpu c x y); auto.
Qed.

Theorem eval_cmpf:
  forall sp le c e m1 a t1 m2 x b t2 m3 y,
  eval_expr ge sp le e m1 a t1 m2 (Vfloat x) ->
  eval_expr ge sp le e m2 b t2 m3 (Vfloat y) ->
  eval_expr ge sp le e m1 (cmpf c a b) (t1**t2) m3 (Val.of_bool (Float.cmp c x y)).
Proof. 
  TrivialOp cmpf. 
  simpl. case (Float.cmp c x y); auto.
Qed.

Lemma eval_base_condition_of_expr:
  forall sp le a e m1 t m2 v (b: bool),
  eval_expr ge sp le e m1 a t m2 v ->
  Val.bool_of_val v b ->
  eval_condexpr ge sp le e m1 
                (CEcond (Ccompuimm Cne Int.zero) (a ::: Enil))
                t m2 b.
Proof.
  intros. 
  eapply eval_CEcond. eauto with evalexpr. 
  inversion H0; simpl. rewrite Int.eq_false; auto. auto. auto.
Qed.

Lemma eval_condition_of_expr:
  forall a sp le e m1 t m2 v (b: bool),
  eval_expr ge sp le e m1 a t m2 v ->
  Val.bool_of_val v b ->
  eval_condexpr ge sp le e m1 (condexpr_of_expr a) t m2 b.
Proof.
  induction a; simpl; intros;
    try (eapply eval_base_condition_of_expr; eauto; fail).
  destruct o; try (eapply eval_base_condition_of_expr; eauto; fail).

  destruct e. InvEval H. inversion XX3; subst v.
  inversion H0. 
  rewrite Int.eq_false; auto. constructor.
  subst i; rewrite Int.eq_true. constructor.
  eapply eval_base_condition_of_expr; eauto.

  inversion H. subst. eapply eval_CEcond; eauto. simpl in H11.
  destruct (eval_condition c vl); try discriminate.
  destruct b0; inversion H11; subst; inversion H0; congruence.

  inversion H. subst.
  destruct v1; eauto with evalexpr.
Qed.

Theorem eval_conditionalexpr_true:
  forall sp le e m1 a1 t1 m2 v1 t2 a2 m3 v2 a3,
  eval_expr ge sp le e m1 a1 t1 m2 v1 ->
  Val.is_true v1 ->
  eval_expr ge sp le e m2 a2 t2 m3 v2 ->
  eval_expr ge sp le e m1 (conditionalexpr a1 a2 a3) (t1**t2) m3 v2.
Proof.
  intros; unfold conditionalexpr.
  apply eval_Econdition with t1 m2 true t2; auto.
  eapply eval_condition_of_expr; eauto with valboolof.
Qed.

Theorem eval_conditionalexpr_false:
  forall sp le e m1 a1 t1 m2 v1 a2 t2 m3 v2 a3,
  eval_expr ge sp le e m1 a1 t1 m2 v1 ->
  Val.is_false v1 ->
  eval_expr ge sp le e m2 a3 t2 m3 v2 ->
  eval_expr ge sp le e m1 (conditionalexpr a1 a2 a3) (t1**t2) m3 v2.
Proof.
  intros; unfold conditionalexpr.
  apply eval_Econdition with t1 m2 false t2; auto.
  eapply eval_condition_of_expr; eauto with valboolof.
Qed.

Lemma eval_addressing:
  forall sp le e m1 a t m2 v b ofs,
  eval_expr ge sp le e m1 a t m2 v ->
  v = Vptr b ofs ->
  match addressing a with (mode, args) =>
    exists vl,
    eval_exprlist ge sp le e m1 args t m2 vl /\ 
    eval_addressing ge sp mode vl = Some v
  end.
Proof.
  intros until v. unfold addressing; case (addressing_match a); intros.
  InvEval H. exists (@nil val). split. eauto with evalexpr. 
  simpl. auto.
  InvEval H. exists (@nil val). split. eauto with evalexpr. 
  simpl. auto.
  InvEval H. InvEval EV. rewrite E0_left in TR. subst t1. FuncInv. 
    congruence.
    destruct (Genv.find_symbol ge s); congruence.
    exists (Vint i0 :: nil). split. eauto with evalexpr. 
    simpl. subst v. destruct (Genv.find_symbol ge s). congruence.
    discriminate.
  InvEval H. FuncInv. 
    congruence.
    exists (Vptr b0 i :: nil). split. eauto with evalexpr. 
    simpl. congruence.
  InvEval H. FuncInv. 
    congruence.
    exists (Vint i :: Vptr b0 i0 :: nil).
    split. eauto with evalexpr. simpl. 
    rewrite Int.add_commut. congruence.
    exists (Vptr b0 i :: Vint i0 :: nil).
    split. eauto with evalexpr. simpl. congruence.
  exists (v :: nil). split. eauto with evalexpr. 
    subst v. simpl. rewrite Int.add_zero. auto.
Qed.

Theorem eval_load:
  forall sp le e m1 a t m2 v chunk v',
  eval_expr ge sp le e m1 a t m2 v ->
  Mem.loadv chunk m2 v = Some v' ->
  eval_expr ge sp le e m1 (load chunk a) t m2 v'.
Proof.
  intros. generalize H0; destruct v; simpl; intro; try discriminate.
  unfold load. 
  generalize (eval_addressing _ _ _ _ _ _ _ _ _ _ H (refl_equal _)).
  destruct (addressing a). intros [vl [EV EQ]]. 
  eapply eval_Eload; eauto. 
Qed.

Theorem eval_store:
  forall sp le e m1 a1 t1 m2 v1 a2 t2 m3 v2 chunk m4,
  eval_expr ge sp le e m1 a1 t1 m2 v1 ->
  eval_expr ge sp le e m2 a2 t2 m3 v2 ->
  Mem.storev chunk m3 v1 v2 = Some m4 ->
  eval_expr ge sp le e m1 (store chunk a1 a2) (t1**t2) m4 v2.
Proof.
  intros. generalize H1; destruct v1; simpl; intro; try discriminate.
  unfold store.
  generalize (eval_addressing _ _ _ _ _ _ _ _ _ _ H (refl_equal _)).
  destruct (addressing a1). intros [vl [EV EQ]]. 
  eapply eval_Estore; eauto. 
Qed.

Theorem exec_ifthenelse_true:
  forall sp e m1 a t1 m2 v ifso ifnot t2 e3 m3 out,
  eval_expr ge sp nil e m1 a t1 m2 v ->
  Val.is_true v ->
  exec_stmt ge sp e m2 ifso t2 e3 m3 out ->
  exec_stmt ge sp e m1 (ifthenelse a ifso ifnot) (t1**t2) e3 m3 out.
Proof.
  intros. unfold ifthenelse.
  apply exec_Sifthenelse with t1 m2 true t2.
  eapply eval_condition_of_expr; eauto with valboolof.
  auto. auto.
Qed.

Theorem exec_ifthenelse_false:
  forall sp e m1 a t1 m2 v ifso ifnot t2 e3 m3 out,
  eval_expr ge sp nil e m1 a t1 m2 v ->
  Val.is_false v ->
  exec_stmt ge sp e m2 ifnot t2 e3 m3 out ->
  exec_stmt ge sp e m1 (ifthenelse a ifso ifnot) (t1**t2) e3 m3 out.
Proof.
  intros. unfold ifthenelse.
  apply exec_Sifthenelse with t1 m2 false t2.
  eapply eval_condition_of_expr; eauto with valboolof.
  auto. auto.
Qed.

End CMCONSTR.

