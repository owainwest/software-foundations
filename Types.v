(** * Types: Type Systems *)

Require Export Smallstep.

Hint Constructors multi.

(** Our next major topic is _type systems_ -- static program
    analyses that classify expressions according to the "shapes" of
    their results.  We'll begin with a typed version of a very simple
    language with just booleans and numbers, to introduce the basic
    ideas of types, typing rules, and the fundamental theorems about
    type systems: _type preservation_ and _progress_.  Then we'll move
    on to the _simply typed lambda-calculus_, which lives at the core
    of every modern functional programming language (including
    Coq). *)

(* ###################################################################### *)
(** * Typed Arithmetic Expressions *)

(** To motivate the discussion of type systems, let's begin as
    usual with an extremely simple toy language.  We want it to have
    the potential for programs "going wrong" because of runtime type
    errors, so we need something a tiny bit more complex than the
    language of constants and addition that we used in chapter
    [Smallstep]: a single kind of data (just numbers) is too simple,
    but just two kinds (numbers and booleans) already gives us enough
    material to tell an interesting story.

    The language definition is completely routine.  The only thing to
    notice is that we are _not_ using the [asnum]/[aslist] trick that
    we used in chapter [HoareList] to make all the operations total by
    forcibly coercing the arguments to [+] (for example) into numbers.
    Instead, we simply let terms get stuck if they try to use an
    operator with the wrong kind of operands: the [step] relation
    doesn't relate them to anything. *)

(* ###################################################################### *)
(** ** Syntax *)

(** Informally:
    t ::= true
        | false
        | if t then t else t
        | 0
        | succ t
        | pred t
        | iszero t
    Formally:
*)

Inductive tm : Type :=
  | ttrue : tm
  | tfalse : tm
  | tif : tm -> tm -> tm -> tm
  | tzero : tm
  | tsucc : tm -> tm
  | tpred : tm -> tm
  | tiszero : tm -> tm.

(** _Values_ are [true], [false], and numeric values... *)

Inductive bvalue : tm -> Prop :=
  | bv_true : bvalue ttrue
  | bv_false : bvalue tfalse.

Inductive nvalue : tm -> Prop :=
  | nv_zero : nvalue tzero
  | nv_succ : forall t, nvalue t -> nvalue (tsucc t).

Definition value (t:tm) := bvalue t \/ nvalue t.

Hint Constructors bvalue nvalue.
Hint Unfold value.
Hint Unfold extend.

(* ###################################################################### *)
(** ** Operational Semantics *)

(** Informally: *)
(**
                    ------------------------------                  (ST_IfTrue)
                    if true then t1 else t2 ==> t1

                   -------------------------------                 (ST_IfFalse)
                   if false then t1 else t2 ==> t2

                              t1 ==> t1'
                      -------------------------                         (ST_If)
                      if t1 then t2 else t3 ==>
                        if t1' then t2 else t3

                              t1 ==> t1'
                         --------------------                         (ST_Succ)
                         succ t1 ==> succ t1'

                             ------------                         (ST_PredZero)
                             pred 0 ==> 0

                           numeric value v1
                        ---------------------                     (ST_PredSucc)
                        pred (succ v1) ==> v1

                              t1 ==> t1'
                         --------------------                         (ST_Pred)
                         pred t1 ==> pred t1'

                          -----------------                     (ST_IszeroZero)
                          iszero 0 ==> true

                           numeric value v1
                      --------------------------                (ST_IszeroSucc)
                      iszero (succ v1) ==> false

                              t1 ==> t1'
                       ------------------------                     (ST_Iszero)
                       iszero t1 ==> iszero t1'
*)

(** Formally: *)

Reserved Notation "t1 '==>' t2" (at level 40).

Inductive step : tm -> tm -> Prop :=
  | ST_IfTrue : forall t1 t2,
      (tif ttrue t1 t2) ==> t1
  | ST_IfFalse : forall t1 t2,
      (tif tfalse t1 t2) ==> t2
  | ST_If : forall t1 t1' t2 t3,
      t1 ==> t1' ->
      (tif t1 t2 t3) ==> (tif t1' t2 t3)
  | ST_Succ : forall t1 t1',
      t1 ==> t1' ->
      (tsucc t1) ==> (tsucc t1')
  | ST_PredZero :
      (tpred tzero) ==> tzero
  | ST_PredSucc : forall t1,
      nvalue t1 ->
      (tpred (tsucc t1)) ==> t1
  | ST_Pred : forall t1 t1',
      t1 ==> t1' ->
      (tpred t1) ==> (tpred t1')
  | ST_IszeroZero :
      (tiszero tzero) ==> ttrue
  | ST_IszeroSucc : forall t1,
       nvalue t1 ->
      (tiszero (tsucc t1)) ==> tfalse
  | ST_Iszero : forall t1 t1',
      t1 ==> t1' ->
      (tiszero t1) ==> (tiszero t1')

where "t1 '==>' t2" := (step t1 t2).

Tactic Notation "step_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "ST_IfTrue" | Case_aux c "ST_IfFalse" | Case_aux c "ST_If"
  | Case_aux c "ST_Succ" | Case_aux c "ST_PredZero"
  | Case_aux c "ST_PredSucc" | Case_aux c "ST_Pred"
  | Case_aux c "ST_IszeroZero" | Case_aux c "ST_IszeroSucc"
  | Case_aux c "ST_Iszero" ].

Hint Constructors step.

(** Notice that the [step] relation doesn't care about whether
    expressions make global sense -- it just checks that the operation
    in the _next_ reduction step is being applied to the right kinds
    of operands.

    For example, the term [succ true] (i.e., [tsucc ttrue] in the
    formal syntax) cannot take a step, but the almost as obviously
    nonsensical term
       succ (if true then true else true)
    can take a step (once, before becoming stuck). *)

(* ###################################################################### *)
(** ** Normal Forms and Values *)

(** The first interesting thing about the [step] relation in this
    language is that the strong progress theorem from the Smallstep
    chapter fails!  That is, there are terms that are normal
    forms (they can't take a step) but not values (because we have not
    included them in our definition of possible "results of
    evaluation").  Such terms are _stuck_. *)

Notation step_normal_form := (normal_form step).

Definition stuck (t:tm) : Prop :=
  step_normal_form t /\ ~ value t.

Hint Unfold stuck.

(** **** Exercise: 2 stars (some_term_is_stuck) *)
Example some_term_is_stuck :
  exists t, stuck t.
Proof.
  exists (tsucc ttrue). unfold stuck. split.
  Case "normal_form".
    unfold normal_form, not. intro Contra. inversion Contra. inversion H. inversion H1.
  Case "~ value".
    unfold not. intro Contra. inversion Contra. inversion H. inversion H. inversion H1.
Qed.
(** [] *)

(** However, although values and normal forms are not the same in this
    language, the former set is included in the latter.  This is
    important because it shows we did not accidentally define things
    so that some value could still take a step. *)

(** **** Exercise: 3 stars, advanced (value_is_nf) *)
(** Hint: You will reach a point in this proof where you need to
    use an induction to reason about a term that is known to be a
    numeric value.  This induction can be performed either over the
    term itself or over the evidence that it is a numeric value.  The
    proof goes through in either case, but you will find that one way
    is quite a bit shorter than the other.  For the sake of the
    exercise, try to complete the proof both ways. *)

Lemma value_is_nf : forall t,
  value t -> step_normal_form t.
Proof.
  intros t Hv; inversion Hv; clear Hv; unfold normal_form, not.
  Case "bvalue".
    inversion H; intros; inversion H1; inversion H2.
  Case "nvalue".
    induction H.
    SCase "tzero".
      intros. inversion H. inversion H0.
    SCase "IH".
      intros. apply IHnvalue. inversion H0. inversion H1. exists t1'. assumption.
Qed.
(** [] *)

(** **** Exercise: 3 stars, optional (step_deterministic) *)
(** Using [value_is_nf], we can show that the [step] relation is
    also deterministic... *)
(*
  Case := "ST_PredSucc" : String.string
  t1 : tm
  H : nvalue t1
  y2 : tm
  H0 : tpred (tsucc t1) ==> y2
  t0 : tm
  t1' : tm
  H2 : tsucc t1 ==> t1'
  H1 : t0 = tsucc t1
  H3 : tpred t1' = y2
  ============================
   t1 = tpred t1'
*)
Lemma nvalue_cannot_succ : forall t t',
  nvalue t -> ~(tsucc t ==> t').
Proof.
  intros t t' Hnv. assert (value t). right. assumption.
  apply value_is_nf in H. unfold normal_form,not in H.
  unfold not. intro. inversion H0. subst. apply H. exists t1'. assumption.
Qed.

Theorem step_deterministic:
  deterministic step.
Proof with eauto.
  unfold deterministic. intros x y1 y2 H1. generalize dependent y2.
  step_cases (induction H1) Case; intros.
  Case "ST_IfTrue". inversion H; subst. reflexivity. inversion H4.
  Case "ST_IfFalse". inversion H; subst. reflexivity. inversion H4.
  Case "ST_If". inversion H; subst. inversion H1. inversion H1. apply IHstep in H5. rewrite H5. reflexivity.
  Case "ST_Succ". inversion H; subst. apply IHstep in H2. rewrite H2. reflexivity.
  Case "ST_PredZero". inversion H.  reflexivity. inversion H1. inversion H0. reflexivity.
    assert (value t1). right. assumption. eapply nvalue_cannot_succ in H. apply H in H2. inversion H2.
  Case "ST_Pred". inversion H; subst. inversion H1. eapply nvalue_cannot_succ in H1. inversion H1. assumption.
    apply IHstep in H2. rewrite H2. reflexivity.
  Case "ST_IszeroZero". inversion H; subst. reflexivity. inversion H1.
  Case "ST_IszeroSucc". inversion H0. reflexivity. apply nvalue_cannot_succ in H2. inversion H2. assumption.
  Case "ST_Iszero". inversion H. rewrite <- H2 in H1. inversion H1. subst. apply nvalue_cannot_succ in H1. inversion H1. assumption.
    apply IHstep in H2. rewrite H2. reflexivity.
Qed.
(** [] *)



(* ###################################################################### *)
(** ** Typing *)

(** The next critical observation about this language is that,
    although there are stuck terms, they are all "nonsensical", mixing
    booleans and numbers in a way that we don't even _want_ to have a
    meaning.  We can easily exclude such ill-typed terms by defining a
    _typing relation_ that relates terms to the types (either numeric
    or boolean) of their final results.  *)

Inductive ty : Type :=
  | TBool : ty
  | TNat : ty.

(** In informal notation, the typing relation is often written
    [|- t \in T], pronounced "[t] has type [T]."  The [|-] symbol is
    called a "turnstile".  (Below, we're going to see richer typing
    relations where an additional "context" argument is written to the
    left of the turnstile.  Here, the context is always empty.) *)
(**
                           ----------------                            (T_True)
                           |- true \in Bool

                          -----------------                           (T_False)
                          |- false \in Bool

             |- t1 \in Bool    |- t2 \in T    |- t3 \in T
             --------------------------------------------                (T_If)
                    |- if t1 then t2 else t3 \in T

                             ------------                              (T_Zero)
                             |- 0 \in Nat

                            |- t1 \in Nat
                          ------------------                           (T_Succ)
                          |- succ t1 \in Nat

                            |- t1 \in Nat
                          ------------------                           (T_Pred)
                          |- pred t1 \in Nat

                            |- t1 \in Nat
                        ---------------------                        (T_IsZero)
                        |- iszero t1 \in Bool
*)

Reserved Notation "'|-' t '\in' T" (at level 40).

Inductive has_type : tm -> ty -> Prop :=
  | T_True :
       |- ttrue \in TBool
  | T_False :
       |- tfalse \in TBool
  | T_If : forall t1 t2 t3 T,
       |- t1 \in TBool ->
       |- t2 \in T ->
       |- t3 \in T ->
       |- tif t1 t2 t3 \in T
  | T_Zero :
       |- tzero \in TNat
  | T_Succ : forall t1,
       |- t1 \in TNat ->
       |- tsucc t1 \in TNat
  | T_Pred : forall t1,
       |- t1 \in TNat ->
       |- tpred t1 \in TNat
  | T_Iszero : forall t1,
       |- t1 \in TNat ->
       |- tiszero t1 \in TBool

where "'|-' t '\in' T" := (has_type t T).

Tactic Notation "has_type_cases" tactic(first) ident(c) :=
  first;
  [ Case_aux c "T_True" | Case_aux c "T_False" | Case_aux c "T_If"
  | Case_aux c "T_Zero" | Case_aux c "T_Succ" | Case_aux c "T_Pred"
  | Case_aux c "T_Iszero" ].

Hint Constructors has_type.

(* ###################################################################### *)
(** *** Examples *)

(** It's important to realize that the typing relation is a
    _conservative_ (or _static_) approximation: it does not calculate
    the type of the normal form of a term. *)

Example has_type_1 :
  |- tif tfalse tzero (tsucc tzero) \in TNat.
Proof.
  apply T_If.
    apply T_False.
    apply T_Zero.
    apply T_Succ.
      apply T_Zero.
Qed.

(** (Since we've included all the constructors of the typing relation
    in the hint database, the [auto] tactic can actually find this
    proof automatically.) *)

Example has_type_not :
  ~ (|- tif tfalse tzero ttrue \in TBool).
Proof.
  intros Contra. solve by inversion 2.  Qed.

(** **** Exercise: 1 star, optional (succ_hastype_nat__hastype_nat) *)
Example succ_hastype_nat__hastype_nat : forall t,
  |- tsucc t \in TNat ->
  |- t \in TNat.
Proof.
  intros. inversion H. assumption.
Qed.
(** [] *)

(* ###################################################################### *)
(** ** Progress *)

(** The typing relation enjoys two critical properties.  The first is
    that well-typed normal forms are values (i.e., not stuck). *)

Theorem progress : forall t T,
  |- t \in T ->
  value t \/ exists t', t ==> t'.

(** **** Exercise: 3 stars (finish_progress) *)
(** Complete the formal proof of the [progress] property.  (Make sure
    you understand the informal proof fragment in the following
    exercise before starting -- this will save you a lot of time.) *)

Proof with auto.
  intros t T HT.
  has_type_cases (induction HT) Case...
  (* The cases that were obviously values, like T_True and
     T_False, were eliminated immediately by auto *)
  Case "T_If".
    right. inversion IHHT1; clear IHHT1.
    SCase "t1 is a value". inversion H; clear H.
      SSCase "t1 is a bvalue". inversion H0; clear H0.
        SSSCase "t1 is ttrue".
          exists t2...
        SSSCase "t1 is tfalse".
          exists t3...
      SSCase "t1 is an nvalue".
        solve by inversion 2.  (* on H and HT1 *)
    SCase "t1 can take a step".
      inversion H as [t1' H1].
      exists (tif t1' t2 t3)...
  Case "T_Succ".
    inversion IHHT; clear IHHT.
    SCase "t1 is a value". inversion H; clear H.
      SSCase "t1 is a bvalue".
        solve by inversion 2.
      SSCase "t1 is an nvalue".
        left. auto.
    SCase "t1 steps".
      inversion H as [t1' Hstep].
      right. exists (tsucc t1'). constructor. assumption.
  Case "T_Pred".
    right. inversion IHHT; clear IHHT.
    SCase "t1 is a value".
      inversion H; clear H. solve by inversion 2.
      inversion H0; clear H0. exists tzero. constructor. exists t. constructor. assumption.
    SCase "t1 steps".
      inversion H; clear H. exists (tpred x). constructor. assumption.
  Case "T_Iszero".
    right; inversion IHHT; clear IHHT.
    SCase "t1 is a value".
      inversion H. solve by inversion 2. inversion H0; clear H0.
      exists ttrue. constructor. exists tfalse. constructor. assumption.
    SCase "t1 steps".
      inversion H. exists (tiszero x). constructor. assumption.
Qed.
(** [] *)

(** **** Exercise: 3 stars, advanced (finish_progress_informal) *)
(** Complete the corresponding informal proof: *)

(** _Theorem_: If [|- t \in T], then either [t] is a value or else
    [t ==> t'] for some [t']. *)

(** _Proof_: By induction on a derivation of [|- t \in T].

      - If the last rule in the derivation is [T_If], then [t = if t1
        then t2 else t3], with [|- t1 \in Bool], [|- t2 \in T] and [|- t3
        \in T].  By the IH, either [t1] is a value or else [t1] can step
        to some [t1'].

            - If [t1] is a value, then it is either an [nvalue] or a
              [bvalue].  But it cannot be an [nvalue], because we know
              [|- t1 \in Bool] and there are no rules assigning type
              [Bool] to any term that could be an [nvalue].  So [t1]
              is a [bvalue] -- i.e., it is either [true] or [false].
              If [t1 = true], then [t] steps to [t2] by [ST_IfTrue],
              while if [t1 = false], then [t] steps to [t3] by
              [ST_IfFalse].  Either way, [t] can step, which is what
              we wanted to show.

            - If [t1] itself can take a step, then, by [ST_If], so can
              [t].

    (* FILL IN HERE *)
[]
*)

(** This is more interesting than the strong progress theorem that we
    saw in the Smallstep chapter, where _all_ normal forms were
    values.  Here, a term can be stuck, but only if it is ill
    typed. *)

(** **** Exercise: 1 star (step_review) *)
(** Quick review.  Answer _true_ or _false_.  In this language...
      - Every well-typed normal form is a value.
        TRUE.

      - Every value is a normal form.
        TRUE.

      - The single-step evaluation relation is
        a partial function (i.e., it is deterministic).
        TRUE.

      - The single-step evaluation relation is a _total_ function.
        FALSE (things can get stuck if they are ill typed).

*)
(** [] *)

(* ###################################################################### *)
(** ** Type Preservation *)

(** The second critical property of typing is that, when a well-typed
    term takes a step, the result is also a well-typed term.

    This theorem is often called the _subject reduction_ property,
    because it tells us what happens when the "subject" of the typing
    relation is reduced.  This terminology comes from thinking of
    typing statements as sentences, where the term is the subject and
    the type is the predicate. *)

Theorem preservation : forall t t' T,
  |- t \in T ->
  t ==> t' ->
  |- t' \in T.

(** **** Exercise: 2 stars (finish_preservation) *)
(** Complete the formal proof of the [preservation] property.  (Again,
    make sure you understand the informal proof fragment in the
    following exercise first.) *)

Proof with auto.
  intros t t' T HT HE.
  generalize dependent t'.
  has_type_cases (induction HT) Case;
         (* every case needs to introduce a couple of things *)
         intros t' HE;
         (* and we can deal with several impossible
            cases all at once *)
         try (solve by inversion);
         (* we need to invert HE in all other cases *)
         inversion HE; subst.
    Case "T_If". (* inversion HE; subst. *)
      SCase "ST_IFTrue". assumption.
      SCase "ST_IfFalse". assumption.
      SCase "ST_If". apply T_If; try assumption.
        apply IHHT1; assumption.
    Case "T_Succ".
      SCase "ST_Succ".
        apply IHHT in H0. apply T_Succ in H0. assumption.
    Case "T_Pred".
      SCase "ST_PredZero".
        constructor.
      SCase "ST_PredSucc".
        inversion HT. assumption.
      SCase "ST_Pred".
        apply IHHT in H0. apply T_Pred in H0. assumption.
    Case "T_Iszero".
      SCase "ttrue". constructor.
      SCase "tfalse". constructor.
      SCase "t1 ==> t1'". apply IHHT in H0. apply T_Iszero in H0. assumption.
Qed.
(** [] *)

(** **** Exercise: 3 stars, advanced (finish_preservation_informal) *)
(** Complete the following proof: *)

(** _Theorem_: If [|- t \in T] and [t ==> t'], then [|- t' \in T]. *)

(** _Proof_: By induction on a derivation of [|- t \in T], for each constructor
        of the 'has_type' inductive type we need to show the objective
        [|- t' \in T] assuming that t was obtained with this constructor and the
        preconditions of the constructor become our inductive hypothesis.

      - The constructors T_False and T_True can be ruled out immediately, because
        there are no t' such that ttrue ==> t' or tfalse ==> t'.

      - If the last rule in the derivation is [T_If], then [t = if t1
        then t2 else t3], with [|- t1 \in Bool], [|- t2 \in T] and [|- t3
        \in T].

        Inspecting the rules for the small-step reduction relation and
        remembering that [t] has the form [if ...], we see that the
        only ones that could have been used to prove [t ==> t'] are
        [ST_IfTrue], [ST_IfFalse], or [ST_If].

           - If the last rule was [ST_IfTrue], then [t' = t2].  But we
             know that [|- t2 \in T], so we are done.

           - If the last rule was [ST_IfFalse], then [t' = t3].  But we
             know that [|- t3 \in T], so we are done.

           - If the last rule was [ST_If], then [t' = if t1' then t2
             else t3], where [t1 ==> t1'].  We know [|- t1 \in Bool] so,
             by the IH, [|- t1' \in Bool].  The [T_If] rule then gives us
             [|- if t1' then t2 else t3 \in T], as required.

      - If the last rule in the derivation of t's type is [T_Succ] then
        t must have the form [succ t1] where [|-t1 \in Nat]. Therefore
        [t ==> t'] must have the form [succ t1 ==> succ t1'] and thus
        must be obtained by [ST_Succ]. By the induction hypothesis
        [|- t1' \in Nat] for any [t1'] such that [t1 ==> t1']. Therefore by
        [T_Succ] [|- t' = succ t1' \in Nat].

      - If the last rule in the derivation of t's type is [T_Pred], [t] must
        have the form [pred 0] ([ST_PredZero]), [pred (succ v1)] ([ST_PredSucc])
        or [pred t1] ([ST_Pred]). In the first case we must show that 0 has
        type Nat, which is trivial. In the second, we must show that given
        v1 has type Nat so has pred (succ v1) ==> v1, which is again trivial.
        In the last case we must show that for t1 ==> t1', pred t1 ==> pred t1'
        has the right type, which follows from an application of the induction
        hypothesis (to show that t1' has type Nat) and an application of ST_Pred.

      - Similar to the previous case.
[]
*)

(** **** Exercise: 3 stars (preservation_alternate_proof) *)
(** Now prove the same property again by induction on the
    _evaluation_ derivation instead of on the typing derivation.
    Begin by carefully reading and thinking about the first few
    lines of the above proof to make sure you understand what
    each one is doing.  The set-up for this proof is similar, but
    not exactly the same. *)

Theorem preservation' : forall t t' T,
  |- t \in T ->
  t ==> t' ->
  |- t' \in T.
Proof with eauto.
  intros t t' T HT HE. generalize dependent HT. generalize dependent T.
  step_cases (induction HE) Case; intros T HT; inversion HT; subst; clear HT; auto.

  Case "ST_PredSucc". inversion H1. assumption.
Qed.
(** [] *)

(* ###################################################################### *)
(** * Aside: the [normalize] Tactic *)

(** When experimenting with definitions of programming languages in
    Coq, we often want to see what a particular concrete term steps
    to -- i.e., we want to find proofs for goals of the form [t ==>*
    t'], where [t] is a completely concrete term and [t'] is unknown.
    These proofs are simple but repetitive to do by hand. Consider for
    example reducing an arithmetic expression using the small-step
    relation [astep]. *)


Definition amultistep st := multi (astep st).
Notation " t '/' st '==>a*' t' " := (amultistep st t t')
  (at level 40, st at level 39).

Example astep_example1 :
  (APlus (ANum 3) (AMult (ANum 3) (ANum 4))) / empty_state
  ==>a* (ANum 15).
Proof.
  apply multi_step with (APlus (ANum 3) (ANum 12)).
    apply AS_Plus2.
      apply av_num.
      apply AS_Mult.
  apply multi_step with (ANum 15).
    apply AS_Plus.
  apply multi_refl.
Qed.

(** We repeatedly apply [multi_step] until we get to a normal
    form. The proofs that the intermediate steps are possible are
    simple enough that [auto], with appropriate hints, can solve
    them. *)

Hint Constructors astep aval.
Example astep_example1' :
  (APlus (ANum 3) (AMult (ANum 3) (ANum 4))) / empty_state
  ==>a* (ANum 15).
Proof.
  eapply multi_step. auto. simpl.
  eapply multi_step. auto. simpl.
  apply multi_refl.
Qed.

(** The following custom [Tactic Notation] definition captures this
    pattern.  In addition, before each [multi_step] we print out the
    current goal, so that the user can follow how the term is being
    evaluated. *)

Tactic Notation "print_goal" := match goal with |- ?x => idtac x end.
Tactic Notation "normalize" :=
   repeat (print_goal; eapply multi_step ;
             [ (eauto 10; fail) | (instantiate; simpl)]);
   apply multi_refl.

Example astep_example1'' :
  (APlus (ANum 3) (AMult (ANum 3) (ANum 4))) / empty_state
  ==>a* (ANum 15).
Proof.
  normalize.
  (* At this point in the proof script, the Coq response shows
     a trace of how the expression evaluated.

   (APlus (ANum 3) (AMult (ANum 3) (ANum 4)) / empty_state ==>a* ANum 15)
   (multi (astep empty_state) (APlus (ANum 3) (ANum 12)) (ANum 15))
   (multi (astep empty_state) (ANum 15) (ANum 15))
*)
Qed.

(** The [normalize] tactic also provides a simple way to calculate
    what the normal form of a term is, by proving a goal with an
    existential variable in it. *)

Example astep_example1''' : exists e',
  (APlus (ANum 3) (AMult (ANum 3) (ANum 4))) / empty_state
  ==>a* e'.
Proof.
  eapply ex_intro. normalize.

(* This time, the trace will be:

    (APlus (ANum 3) (AMult (ANum 3) (ANum 4)) / empty_state ==>a* ??)
    (multi (astep empty_state) (APlus (ANum 3) (ANum 12)) ??)
    (multi (astep empty_state) (ANum 15) ??)

   where ?? is the variable ``guessed'' by eapply.
*)
Qed.


(** **** Exercise: 1 star (normalize_ex) *)
Theorem normalize_ex : exists e',
  (AMult (ANum 3) (AMult (ANum 2) (ANum 1))) / empty_state
  ==>a* e'.
Proof.
  eexists. normalize.
Qed.
(** [] *)

(** **** Exercise: 1 star, optional (normalize_ex') *)
(** For comparison, prove it using [apply] instead of [eapply]. *)

Theorem normalize_ex' : exists e',
  (AMult (ANum 3) (AMult (ANum 2) (ANum 1))) / empty_state
  ==>a* e'.
Proof.
  eexists.
  apply multi_step with (AMult (ANum 3) (ANum 2)). apply AS_Mult2. apply av_num. apply AS_Mult.
  apply multi_step with (ANum 6). apply AS_Mult. apply multi_refl.
Qed.
(** [] *)

(* ###################################################################### *)
(** ** Type Soundness *)

(** Putting progress and preservation together, we can see that a
    well-typed term can _never_ reach a stuck state.  *)

Definition multistep := (multi step).
Notation "t1 '==>*' t2" := (multistep t1 t2) (at level 40).

Corollary soundness : forall t t' T,
  |- t \in T ->
  t ==>* t' ->
  ~(stuck t').
Proof.
  intros t t' T HT P. induction P; intros [R S].
  destruct (progress x T HT); auto.
  apply IHP. apply (preservation x y T HT H).
  unfold stuck. split; auto.   Qed.

(* ###################################################################### *)
(** ** Additional Exercises *)

(** **** Exercise: 2 stars (subject_expansion) *)
(** Having seen the subject reduction property, it is reasonable to
    wonder whether the opposity property -- subject _expansion_ --
    also holds.  That is, is it always the case that, if [t ==> t']
    and [|- t' \in T], then [|- t \in T]?  If so, prove it.  If
    not, give a counter-example.  (You do not need to prove your
    counter-example in Coq, but feel free to do so if you like.)

    (* FILL IN HERE *)
[]
*)
Theorem not_preservation_inv : forall t T,
  |- t \in T -> exists t', t' ==> t /\ ~ (|- t' \in T).
Proof.
  intros t T HT. destruct T.
  Case "TBool". exists (tif ttrue t tzero).
    split. auto. unfold not. intro. inversion H. subst. inversion H6.
  Case "TNat". exists (tif ttrue t ttrue).
    split. auto. unfold not. intro. inversion H. subst. inversion H6.
Qed.

(*
Determinism: stepping is deterministic
Progress: Each well-typed term is either a value or can be reduced.
Preservation: The type of a term is perserved when it steps.
*)

(** **** Exercise: 2 stars (variation1) *)
(** Suppose, that we add this new rule to the typing relation:
      | T_SuccBool : forall t,
           |- t \in TBool ->
           |- tsucc t \in TBool
   Which of the following properties remain true in the presence of
   this rule?  For each one, write either "remains true" or
   else "becomes false." If a property becomes false, give a
   counterexample.
      - Determinism of [step]
        remains true (no overlap in the requirements of constructors).

      - Progress
        becomes false, because no terms typecheck which can not be
        reduced to values, e.g. (tsucc ttrue).

      - Preservation
        remains true because terms of type bool reduce to terms of type
        bool which will still typecheck with this new rule.
[]
*)

(** **** Exercise: 2 stars (variation2) *)
(** Suppose, instead, that we add this new rule to the [step] relation:
      | ST_Funny1 : forall t2 t3,
           (tif ttrue t2 t3) ==> t3
   Which of the above properties become false in the presence of
   this rule?  For each one that does, give a counter-example.

       - Determinism no longer holds (tif ttrue 0 1 ==> 0 /\ tif true 0 1 ==> 1)
       - Progress still holds.
       - Preservation still holds.
[]
*)

(** **** Exercise: 2 stars, optional (variation3) *)
(** Suppose instead that we add this rule:
      | ST_Funny2 : forall t1 t2 t2' t3,
           t2 ==> t2' ->
           (tif t1 t2 t3) ==> (tif t1 t2' t3)
   Which of the above properties become false in the presence of
   this rule?  For each one that does, give a counter-example.

       - Determinism no longer holds
          (tif (tiszero 0) (tsucc 0) 0 ==> tif ttrue (tsucc 0) 0 /\
           tif (tiszero 0) (tsucc 0) 0 ==> tif (tiszero 0) 1 0)
       - Progress still holds.
       - Preservation still holds.
[]
*)

(** **** Exercise: 2 stars, optional (variation4) *)
(** Suppose instead that we add this rule:
      | ST_Funny3 :
          (tpred tfalse) ==> (tpred (tpred tfalse))
   Which of the above properties become false in the presence of
   this rule?  For each one that does, give a counter-example.
   - Determinism still holds (no overlapping preconditions)
   - Progress still holds (because tpred tfalse is not well-typed)
   - Preservation still holds

   I think the thing that doesn't hold in this case anymore is that
   progress for example only works for well typed terms.
[]
*)

(** **** Exercise: 2 stars, optional (variation5) *)
(** Suppose instead that we add this rule:

      | T_Funny4 :
            |- tzero \in TBool
   ]]
   Which of the above properties become false in the presence of
   this rule?  For each one that does, give a counter-example.
   - Determinism is still OK
   - Porgress no longer holds (e.g. tif tzero ...)
   - Preservation still holds? I mean we can get terms that
     are first of type TNat and then have both type TNat and TBool
     but they still have TNat (among others).
[]
*)

(** **** Exercise: 2 stars, optional (variation6) *)
(** Suppose instead that we add this rule:

      | T_Funny5 :
            |- tpred tzero \in TBool
   ]]
   Which of the above properties become false in the presence of
   this rule?  For each one that does, give a counter-example.

   - Determinism still holds
     (always when we introduce typing rules?)

   - Progress ... still holds (?) While the terms are still well-typed
     we can still make progress, we may only obtain an ill-typed term
     which will prevent us from further making progress. But this term
     is now ill-typed so the precedent of the progress theorem is not
     given.

   - Preservation doesn't hold, because
     |- tpred tzero \in TBool,
     tpred tzero ==> tzero,
     ~ (|- tzero \in TBool)
[]
*)

(** **** Exercise: 3 stars, optional (more_variations) *)
(** Make up some exercises of your own along the same lines as
    the ones above.  Try to find ways of selectively breaking
    properties -- i.e., ways of changing the definitions that
    break just one of the properties and leave the others alone.

    (a)
      | ST_IfFunny :
        tif t1 t2 t2 ==> t2
    - Determinism doesn't hold, there are two ways to reduce
        tif (tiszero tzero) tzero tzero.
    - Progress holds
    - Preservation holds

    (b)
    - Determinism holds
    - Progress doesn't hold (well-typed terms can get stuck)
    - Preservation holds (if we can reduce the type stays the same)

      -> One way to do this is to introduce a typing rule for something
         where progress isn't possible.

      | T_TrueNat :
        |- ttrue \in TNat

    (c)
    - Determinims holds
    - Progress holds (well-typed terms can't get stuck)
    - Preservation doesn't hold (type of terms change as we reduce)

    -> one way to do this is to add an additional type to something
       that reduces to something else, like
       [|- tif t1 t2 t3 \in TNat] regardless of what types t2 and t3 have.
    []
*)

(** **** Exercise: 1 star (remove_predzero) *)
(** The evaluation rule [E_PredZero] is a bit counter-intuitive: we
    might feel that it makes more sense for the predecessor of zero to
    be undefined, rather than being defined to be zero.  Can we
    achieve this simply by removing the rule from the definition of
    [step]?  Would doing so create any problems elsewhere?

    Terms could get stuck (progress doesn't hold anymore), because
    tpred tzero is not a value but cannot be reduced. (defining
    values for tpreds in the same way as for tsuccs would be tricky,
    because we have to rule out that there is no (tpred (tsucc tzero)).
[] *)

(** **** Exercise: 4 stars, advanced (prog_pres_bigstep) *)
(** Suppose our evaluation relation is defined in the big-step style.
    What are the appropriate analogs of the progress and preservation
    properties?

Theorem progress' : forall t T,
  |- t \in T ->
  exists t',  t ==>* t' /\ value t'.

Theorem preservation' : forall t t' T,
  |- t \in T -> t ==>* t' -> |- t' \in T.
[]
*)

(* $Date: 2013-07-17 16:19:11 -0400 (Wed, 17 Jul 2013) $ *)
