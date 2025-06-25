# Interactive and non-interactive Protocols in OCaml

This repository contains OCaml implementation of the different interactive and non-interactive protocols, based on the research paper:

> *Practical Verified Computation with Streaming Interactive Proofs*  
> by Graham Cormode, Michael Mitzenmacher, and Justin Thaler  
> [arXiv link (2011)](https://arxiv.org/abs/1105.2003)

This implementation was adapted and rewritten in OCaml from an original C++ reference implementation by Justin Thaler (May 7, 2011).

---

## 📘 About the Protocols

- ## Non-interactive Naive F₂ Protocol

The **F₂ moment** of a data stream is defined as:

`F₂ = ∑ frequency(x)²`

The protocol allows a **verifier** with limited memory to efficiently check a **prover’s** claim about the F₂ moment, even for very large datasets, using:
- Modular arithmetic over a large prime field
- Lagrange interpolation
- Low-degree polynomial extrapolation

It’s useful in the context of:
- Streaming algorithms
- Verifiable computation
- Cryptographic protocols

---

## Running the Code

### Prerequisites
- OCaml (version ≥ 4.12 recommended)
- Dune (optional, for building)

### Compile & Run
```bash
ocamlopt -o f2 uni.ml
./f2 <dimension>
```

Example:
```
./f2 100
```
This will:
- Generate a 10000 x 10000 matrix of random values
- Compute F₂ directly
- Construct a proof using polynomial extrapolation
- Verify the proof using tabulated values
- Print timing and success/failure

Example Output:
```./f2_protocol 100
N       VerifT  ProveT  CheckT  VerifS  ProofS
10000   0.000158        0.018168        0.000004        100     200
Protocol completed successfully!
```
![image](https://github.com/user-attachments/assets/9a3ef6a4-3c04-4160-a8c4-21045fe3b129)

- ## Interactive F₂ Protocol

The Interactive F₂ Protocol is a more communication-efficient method that allows a prover and a verifier to engage in multiple rounds of interaction to verify the F₂ moment of a large dataset.

Based on the protocol by Cormode, Thaler, and Yi, the interactive version compresses the verifier's memory usage using random linear projections and recursive polynomial checks.
In each round:
- The prover sends evaluations of a low-degree polynomial derived from the frequency vector.
- The verifier uses Lagrange interpolation and modular arithmetic to validate consistency.
- It continues until the data vector is reduced to a single point.

Core Ideas
- Chi functions: Evaluate binary characteristic vectors using random field elements.
- Polynomial reduction: In each round, the prover reduces the dimension by 1 using carefully constructed messages.
- Consistency checks: The verifier checks that the interpolated polynomial matches the extrapolated result from the previous round.

## Running the code

### Prerequisites
- OCaml (version ≥ 4.12 recommended)
- Dune (optional, for building)

### Compile & Run
```bash
ocamlopt -o f2 multi.ml
./f2 <dimension>
```

Example:
```
./f2 10
```
This initiates:
- A stream of size 2^10 = 1024
- Generation of matrix with random values
- Execution of full interactive protocol
- Timing and consistency verification

Example Output:
```./f2_protocol 10
N       VerifT  ProveT  CheckT  VerifS  ProofS
1024    0.0001720000    0.0001780000    0.0000030000    11      31
```
![image](https://github.com/user-attachments/assets/fee030f4-c73c-4145-8ba7-13011022d724)

- VerifT: Time to extrapolate the random point
- ProveT: Time for the prover to compute polynomial messages
- CheckT: Time for the verifier to perform all consistency checks
- VerifS: Number of verifier messages (≈ d + 1)
- ProofS: Number of prover messages (≈ 3 × d + 1)
If all checks pass, the protocol completes successfully.


## 📚 References & Resources
This implementation was based on concepts and techniques described in:

[Cormode, Mitzenmacher, Thaler: Practical Verified Computation with Streaming Interactive Proofs](https://arxiv.org/abs/1105.2003)

OCaml documentation:
- [`Int64` module](https://ocaml.org/api/Int64.html)
- [`Array` module](https://ocaml.org/api/Array.html)
- [`Printf` formatting](https://ocaml.org/api/Printf.html)
