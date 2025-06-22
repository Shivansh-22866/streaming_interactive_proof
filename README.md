# Interactive and non-interactive Protocols in OCaml

This repository contains OCaml implementation of the different interactive and non-interactive protocols, based on the research paper:

> *Practical Verified Computation with Streaming Interactive Proofs*  
> by Graham Cormode, Michael Mitzenmacher, and Justin Thaler  
> [arXiv link (2011)](https://arxiv.org/abs/1105.2003)

This implementation was adapted and rewritten in OCaml from an original C++ reference implementation by Justin Thaler (May 7, 2011).

---

## 📘 About the Protocols

The **F₂ moment** of a data stream is defined as:

`F₂ = ∑ frequency(x)²`

This protocol allows a **verifier** with limited memory to efficiently check a **prover’s** claim about the F₂ moment, even for very large datasets, using:
- Modular arithmetic over a large prime field
- Lagrange interpolation
- Low-degree polynomial extrapolation

It’s useful in the context of:
- Streaming algorithms
- Verifiable computation
- Cryptographic protocols

---

## 🧠 Features

- Written entirely in OCaml
- Uses 64-bit integer arithmetic and efficient modular reductions
- Implements Lagrange interpolation and fast evaluation of polynomials
- Fully functional prover and verifier logic
- Randomized testing of protocol correctness
- Timing and performance measurement

---

## 🚀 Running the Code

### Prerequisites
- OCaml (version ≥ 4.12 recommended)
- Dune (optional, for building)

### Compile & Run
```bash
ocamlopt -o f2 f2.ml
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

## 📚 References & Resources
This implementation was based on concepts and techniques described in:

[Cormode, Mitzenmacher, Thaler: Practical Verified Computation with Streaming Interactive Proofs](https://arxiv.org/abs/1105.2003)

OCaml documentation:
- [`Int64` module](https://ocaml.org/api/Int64.html)
- [`Array` module](https://ocaml.org/api/Array.html)
- [`Printf` formatting](https://ocaml.org/api/Printf.html)
