(* F2 Protocol Implementation in OCaml - Fixed Version
   Based on "Practical Verified Computation with Streaming Interactive Proofs"
   by Cormode, Mitzenmacher, and Thaler
   Original C++ implementation by Justin Thaler, May 7, 2011
*)

open Printf

(* Constants *)
let mask = 4294967295L (* 2^32 - 1 *)
let prime = 2305843009213693951L (* 2^61 - 1 *)

type uint64 = int64

(* Helper function: fold with index *)
let fold_lefti f acc arr =
  let result = ref acc in
  Array.iteri (fun i x -> result := f i !result x) arr;
  !result

(* Functional power function *)
let rec my_pow x e =
  if e <= 0 then 1L
  else Int64.mul x (my_pow x (e - 1))

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
  my_mod (Int64.add (Int64.add piece1 piece2) piece3)

(* Extended Euclidean Algorithm using mutable references *)
let ext_euclidean_alg u =
  let u1 = ref 1L in
  let u2 = ref 0L in
  let u3 = ref u in
  let v1 = ref 0L in
  let v2 = ref 1L in
  let v3 = ref prime in
  
  while !v3 <> 0L && !v3 <> prime do
    let q = Int64.div !u3 !v3 in
    let t1 = my_mod (Int64.add !u1 (Int64.sub prime (my_mod_mult q !v1))) in
    let t2 = my_mod (Int64.add !u2 (Int64.sub prime (my_mod_mult q !v2))) in
    let t3 = my_mod (Int64.add !u3 (Int64.sub prime (my_mod_mult q !v3))) in
    u1 := !v1; u2 := !v2; u3 := !v3;
    v1 := t1; v2 := t2; v3 := t3
  done;
  (!u1, !u2, !u3)

(* Compute modular multiplicative inverse *)
let inv a =
  let (u1, _, u3) = ext_euclidean_alg a in
  if u3 = 1L then my_mod u1 else 0L

(* Generate lookup table of multiplicative inverses using functional approach *)
let gen_inv n =
  let n_int = Int64.to_int n in
  
  (* Build ifact_plus using imperative style for performance *)
  let ifact_plus = Array.make n_int 1L in
  for i = 1 to n_int - 1 do
    ifact_plus.(i) <- my_mod_mult (inv (Int64.of_int i)) ifact_plus.(i - 1)
  done;
  
  (* Build ifact_minus *)
  let ifact_minus = Array.make n_int 1L in
  for i = 1 to n_int - 1 do
    ifact_minus.(i) <- my_mod_mult (inv (Int64.sub prime (Int64.of_int i))) 
                                   ifact_minus.(i - 1)
  done;
  
  (* Combine results functionally *)
  Array.init n_int (fun i ->
    my_mod_mult ifact_plus.(i) ifact_minus.(n_int - i - 1))

(* Generate r-table for Lagrange polynomials *)
let gen_rtab n r =
  let n_int = Int64.to_int n in
  if r < n then
    (* Fallback to direct computation for r < n *)
    let lookup = Array.init n_int (fun i -> 
      my_mod (Int64.add (Int64.sub r (Int64.of_int i)) prime)) in
    Array.init n_int (fun i ->
      fold_lefti (fun j acc x -> 
        if i <> j then my_mod_mult acc x else acc) 1L lookup)
  else
    (* Efficient computation for r >= n *)
    let table = Array.make n_int 0L in
    let mult = ref 1L in
    
    for j = 1 to n_int - 1 do
      mult := my_mod_mult !mult (Int64.sub r (Int64.of_int j))
    done;
    table.(0) <- !mult;
    
    for i = 1 to n_int - 1 do
      table.(i) <- my_mod_mult (my_mod_mult table.(i - 1) 
                                           (Int64.add (Int64.sub r (Int64.of_int i)) 1L))
                               (inv (Int64.sub r (Int64.of_int i)))
    done;
    table

(* Tabulated extrapolation using lookup tables *)
let tab_extrap vec n r itab rtab =
  let n_int = Int64.to_int n in
  let acc = ref 0L in
  for i = 0 to n_int - 1 do
    acc := my_mod (Int64.add !acc 
                   (my_mod_mult (my_mod_mult rtab.(i) itab.(i)) vec.(i)))
  done;
  !acc

(* Generate random data and compute exact F2 *)
let gen_data h v =
  let h_int = Int64.to_int h in
  let v_int = Int64.to_int v in
  let data = Array.make_matrix v_int (2 * h_int) 0L in
  let f2 = ref 0L in
  
  for i = 0 to v_int - 1 do
    for j = 0 to h_int - 1 do
      let value = Int64.of_int (Random.int 1000) in
      data.(i).(j) <- value;
      f2 := Int64.add !f2 (Int64.mul value value)
    done
  done;
  (data, !f2)

(* Generate check values for verifier *)
let v_check h v r data itab =
  let rtab = gen_rtab h r in
  let v_int = Int64.to_int v in
  let check = ref 0L in
  
  for i = 0 to v_int - 1 do
    let ext = tab_extrap data.(i) h r itab rtab in
    check := my_mod (Int64.add !check (my_mod_mult ext ext))
  done;
  !check

(* Build proof by extrapolating data *)
let build_proof h v facttab itab data =
  let h_int = Int64.to_int h in
  let v_int = Int64.to_int v in
  
  (* Extrapolate data to adjacent columns *)
  for i = 0 to v_int - 1 do
    for j = h_int to (2 * h_int) - 1 do
      data.(i).(j) <- tab_extrap data.(i) h (Int64.of_int j) itab facttab.(j - h_int)
    done
  done;
  
  (* Compute sums of squares *)
  Array.init (2 * h_int) (fun j ->
    let sum = ref 0L in
    for i = 0 to v_int - 1 do
      let value = data.(i).(j) in
      sum := my_mod (Int64.add !sum (my_mod_mult value value))
    done;
    !sum)

let time_it f x =
  let start_time = Sys.time () in
  let result = f x in
  let end_time = Sys.time () in
  (result, end_time -. start_time)

(* Main computation *)
let run_f2_protocol d =
  Random.self_init ();
  let h = Int64.of_int d in
  let v = Int64.of_int d in
  let r = Int64.of_int (Random.int 1000000) in
  
  (* Generate data and compute exact F2 *)
  let (data, cf2) = gen_data h v in
  
  (* Prover generates lookup tables *)
  let (itab, itab_time) = time_it (gen_inv) h in
  let start_time = Sys.time () in
  let facttab = Array.init d (fun k -> gen_rtab h (Int64.add h (Int64.of_int k))) in
  let ptable_time = Sys.time () -. start_time in
  
  (* Verifier generates lookup tables *)
  let start_time = Sys.time () in
  let itab2 = gen_inv (Int64.mul 2L h) in
  let rtab2 = gen_rtab (Int64.mul 2L h) r in
  let check = v_check h v r data itab in
  let vt = Sys.time () -. start_time in
  
  (* Create proof *)
  let (proof_vec, pt) = time_it (build_proof h v facttab itab) data in
  
  (* Verify proof *)
  let (result, ct) = time_it (tab_extrap proof_vec (Int64.mul 2L h) r itab2) rtab2 in
  
  (* Compute claimed F2 value *)
  let f2 = Array.fold_left Int64.add 0L (Array.sub proof_vec 0 d) in
  
  (* Check correctness *)
  let correct = (result = check) && (f2 = cf2) in
  
  (* Print results *)
  if not correct then
    printf "FAIL!\nresult: %Ld check: %Ld\nf2: %Ld cf2: %Ld\n" result check f2 cf2;
  
  printf "N\tVerifT\tProveT\tCheckT\tVerifS\tProofS\n";
  printf "%d\t%.6f\t%.6f\t%.6f\t%d\t%d\n" 
    (d * d) (vt +. itab_time) (pt +. ptable_time) ct d (2 * d);
  
  correct

(* Command line interface *)
let () =
  if Array.length Sys.argv < 2 then (
    printf "Usage: %s <dimension>\n" Sys.argv.(0);
    exit 1
  );
  
  let d = int_of_string Sys.argv.(1) in
  let success = run_f2_protocol d in
  if success then
    printf "Protocol completed successfully!\n"
  else
    printf "Protocol failed!\n"
