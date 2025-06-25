(* Interactive F2 Protocol Implementation in OCaml *)
(* Functional implementation following the paper by Cormode, Thaler, and Yi *)

open Printf

(* Constants *)
let mask = 4294967295L (* 2^32 - 1 *)
let prime = 2305843009213693951L (* 2^61 - 1 *)

(* Efficient modular arithmetic for p = 2^61 - 1 *)
let my_mod x =
  Int64.add (Int64.shift_right_logical x 61) (Int64.logand x prime)

(* Efficient modular multiplication mod 2^61 - 1 *)
let my_mod_mult x y =
  let hi_x = Int64.shift_right_logical x 32 in
  let hi_y = Int64.shift_right_logical y 32 in
  let low_x = Int64.logand x mask in
  let low_y = Int64.logand y mask in
  
  let piece1 = my_mod (Int64.shift_left (Int64.mul hi_x hi_y) 3) in
  let z = Int64.add (Int64.mul hi_x low_y) (Int64.mul hi_y low_x) in
  let hi_z = Int64.shift_right_logical z 32 in
  let low_z = Int64.logand z mask in
  
  let piece2 = my_mod (Int64.add (Int64.shift_left hi_z 3) 
                      (my_mod (Int64.shift_left low_z 32))) in
  let piece3 = my_mod (Int64.mul low_x low_y) in
  my_mod (Int64.add piece1 (Int64.add piece2 piece3))

(* Functional power function *)
let rec my_pow x = function
  | 0 -> 1L
  | n -> Int64.mul x (my_pow x (n - 1))

(* Generate random vector of dimension d *)
let choose_r d =
  Random.self_init ();
  Array.init d (fun _ -> 
    let r = Random.bits () land 0x3FFFFFFF in
    my_mod (Int64.of_int r))


(* Binary characteristic vector function *)
let chi e d v r =
  let rec loop i v acc =
    if i >= d then acc
    else
      let new_acc = 
        if Int64.logand v 1L = 1L then
          my_mod_mult acc r.(i)
        else
          my_mod_mult acc (my_mod (Int64.add 1L (Int64.sub prime r.(i))))
      in
      loop (i + 1) (Int64.shift_right_logical v 1) new_acc
  in
  loop e v 1L

(* Build lookup table of chi values *)
let make_chi w rd d r =
  let rw = Int64.to_int (my_pow 2L w) in
  let rec build_block j lo hi acc =
    if j >= rd then List.rev acc
    else
      let block = Array.init rw (fun i -> chi lo (min hi d) (Int64.of_int i) r) in
      let new_hi = if hi + w > d then d else hi + w in
      build_block (j + 1) hi new_hi (block :: acc)
  in
  Array.of_list (build_block 0 0 w [])

(* Extrapolate global vector to location r *)
let extrap r d u a =
  let w = 8 in
  let rw = Int64.to_int (my_pow 2L w) in
  let mask = Int64.of_int (rw - 1) in
  let rd = (d + w - 1) / w in (* ceiling division *)
  let chilook = make_chi w rd d r in
  
  let rec compute_sum i acc =
    if i >= u then acc
    else
      let delta = ref a.(i) in
      let k = ref (Int64.of_int i) in
      for j = 0 to rd - 1 do
        let idx = Int64.to_int (Int64.logand !k mask) in
        delta := my_mod_mult !delta chilook.(j).(idx);
        k := Int64.shift_right_logical !k w
      done;
      compute_sum (i + 1) (my_mod (Int64.add acc !delta))
  in
  compute_sum 0 0L

(* Central part of chi function *)
let min_chi j v c =
  if Int64.logand (Int64.shift_right_logical v j) 1L = 1L then c
  else my_mod (Int64.add 1L (Int64.sub prime c))

(* Fast computation of g_j(c) for c = 0, 1, 2 *)
let fcomp_gjc d j a =
  let top = Int64.to_int (my_pow 2L (d - j)) in
  let rec loop k (r0, r1, r2) =
    if k >= top then [|r0; r1; r2|]
    else
      let ak = a.(k) in
      let ak1 = a.(k + 1) in
      let new_r0 = my_mod (Int64.add r0 (my_mod_mult ak ak)) in
      let new_r1 = my_mod (Int64.add r1 (my_mod_mult ak1 ak1)) in
      (* chi_1(2) = 2, chi_0(2) = -1 *)
      let val_2 = my_mod (Int64.add (my_mod (Int64.mul 2L ak1)) 
                                   (Int64.sub prime ak)) in
      let new_r2 = my_mod (Int64.add r2 (my_mod_mult val_2 val_2)) in
      loop (k + 2) (new_r0, new_r1, new_r2)
  in
  loop 0 (0L, 0L, 0L)

(* Update array by compacting adjacent values *)
let compact_a d j rj a =
  let top = Int64.to_int (my_pow 2L (d - j - 1)) in
  let new_a = Array.make top 0L in
  for i = 0 to top - 1 do
    let k = i * 2 in
    (* chi_1(rj) = rj, chi_0(rj) = 1 - rj *)
    new_a.(i) <- my_mod (Int64.add a.(k) 
                        (my_mod_mult rj (my_mod (Int64.add a.(k + 1) 
                                               (Int64.sub prime a.(k))))))
  done;
  new_a

(* Lagrange interpolation: evaluate quadratic at rj given f(0), f(1), f(2) *)
let interp y rj =
  let term1 = my_mod_mult (my_mod_mult (Int64.sub rj 1L) (Int64.sub rj 2L)) y.(0) in
  let term2 = my_mod_mult (my_mod (Int64.mul 2L (my_mod_mult rj (Int64.sub rj 2L)))) y.(1) in
  let term3 = my_mod_mult (my_mod_mult rj (Int64.sub rj 1L)) y.(2) in
  my_mod (Int64.add term1 (Int64.add (Int64.sub prime term2) term3))

(* Main protocol rounds - functional approach *)
let rounds d r a fr f2 =
  let start_time = Sys.time () in
  
  (* Generate all prover messages *)
  let rec generate_messages j current_a acc =
    if j >= d then List.rev acc
    else
      let msg = fcomp_gjc d j current_a in
      let new_a = compact_a d j r.(j) current_a in
      generate_messages (j + 1) new_a (msg :: acc)
  in
  
  let messages = generate_messages 0 a [] in
  let prover_time = Sys.time () -. start_time in
  
  (* Verify messages *)
  let start_check = Sys.time () in
  
  (* Check claimed F2 *)
  let first_msg = List.hd messages in
  if Int64.add first_msg.(0) first_msg.(1) <> f2 then
    printf "Claimed f2 does not equal real f2!\n";
  
  (* Verify message consistency *)
  let rec verify_messages msgs j prev_check =
    match msgs with
    | [] -> prev_check
    | msg :: rest ->
        if j > 0 then (
          let sum = my_mod (Int64.add msg.(0) msg.(1)) in
          let expected = my_mod (Int64.mul 2L sum) in
          let diff = my_mod (Int64.add expected (Int64.sub prime prev_check)) in
          if diff <> 0L && diff <> prime then
            printf "Check failed at round %d\n" j
        );
        let new_check = interp msg r.(j) in
        verify_messages rest (j + 1) new_check
  in
  
  let final_check = verify_messages messages 0 0L in
  
  (* Final verification *)
  let expected_final = my_mod_mult (Int64.mul 2L fr) fr in
  let final_diff = my_mod (Int64.add expected_final (Int64.sub prime final_check)) in
  if final_diff <> 0L && final_diff <> prime then
    printf "Final check failed\n";
  
  let check_time = Sys.time () -. start_check in
  (prover_time, check_time)

(* Main function *)
let main () =
  let d = 
    if Array.length Sys.argv < 2 then (
      printf "Usage: %s <dimension>\n" Sys.argv.(0);
      exit 1
    ) else
      max 8 (int_of_string Sys.argv.(1))
  in
  
  let u = Int64.to_int (my_pow 2L d) in
  
  (* Generate random vector *)
  Random.self_init ();
  let a = Array.init u (fun _ -> Int64.of_int (Random.int 1000)) in
  
  (* Compute exact F2 *)
  let f2 = Array.fold_left (fun acc x -> 
    Int64.add acc (Int64.mul x x)) 0L a in
  
  (* Choose random point and extrapolate *)
  let r = choose_r d in
  let start_verif = Sys.time () in
  let fr = extrap r d u a in
  let verif_time = Sys.time () -. start_verif in
  
  (* Run protocol *)
  let (prover_time, check_time) = rounds d r a fr f2 in
  
  (* Output results *)
  printf "N\tVerifT\tProveT\tCheckT\tVerifS\tProofS\n";
  printf "%d\t%.10f\t%.10f\t%.10f\t%d\t%d\n" 
    u verif_time prover_time check_time (d + 1) (3 * d + 1)

let () = main ()
