# The Security Researcher’s Guide to Mathematics

> **Source**: Bernhard Mueller (Nov 2025)

You can be a successful security researcher without knowing much about math. But if you want to see the matrix, you need to get math-pilled.

## 1. Linear Algebra: The Matrix of Reality

**Key Concept**: "Linear" means $L(u+v) = L(u) + L(v)$ and $L(c \cdot v) = c \cdot L(v)$. It preserves the grid structure.

### Applications in Security:

1.  **Zero-Knowledge Proofs (R1CS)**:

    - ZK proofs reduce computation to checking linear equations over finite fields ("arithmetization").
    - **R1CS**: Proving you know a secret vector $s$ such that $(s \cdot a) \times (s \cdot b) = s \cdot c$.
    - _Audit Tip_: When reviewing Groth16/Plonk circuits, you are effectively checking if the constraint matrices correctly encode the program logic.

2.  **DeFi Invariants (Logarithmic Linearization)**:

    - Most DeFi invariants (Uniswap $x \cdot y = k$, Balancer weights) are non-linear.
    - **Trick**: Use Logarithms to linearize them.
      - $x_a^{0.5} \cdot x_b^{0.5} = k \rightarrow 0.5 \ln(x_a) + 0.5 \ln(x_b) = \ln(k)$.
    - _Audit Tip_: Use spreadsheets! Linearize the invariant and check for edge cases using simple matrix math.

3.  **Risk Engines (Perps/Lending)**:
    - Solvency check is a matrix inequality: $C \cdot (P \cdot p) \ge m$.
      - $p$: Position vector
      - $P$: Price matrix (diagonal)
      - $C$: Margin requirement matrix
    - _Audit Tip_: Write out the risk engine as a matrix operation. Check if rounding errors accumulate across the matrix multiply.

## 2. Non-Linearity: The Complexity Layer

**Key Concept**: XOR Problem. A single linear layer cannot separate XOR inputs. You need non-linearity (ReLU, Sigmoid) to "fold" the space.

### Applications:

- **Neural Networks**: Stacks of matrices separated by non-linearities.
- _Audit Tip_: If a protocol claims to "learn" or "adapt" using only linear weights (simple weighted averages), it cannot solve complex classification problems.

## 3. Abstract Algebra: The Language of Crypto

**Key Structures**:

- **Group**: Set with closure, associativity, identity, inverses. (e.g., Elliptic Curve points).
- **Field**: Ring where you can divide. (e.g., Integers mod prime $p$).

### Applications:

- **Homomorphisms** ($f(a \cdot b) = f(a) \cdot f(b)$):
  - Allows computing on hidden values (Pedersen Commitments).
  - _Audit Tip_: Check if the protocol relies on additive properties of commitments ($Commit(A) + Commit(B) = Commit(A+B)$).
- **Symmetry Breaking**:
  - An exploit is often a "symmetry breaking" event—violating an invariant that should hold under all valid transformations.

### The Playstation 3 Hack (ECDSA Failure):

- Using the same random nonce $k$ for two signatures allows solving for the private key using simple algebra.
- $k = (z_1 - z_2) / (s_1 - s_2)$.

## 4. Number Theory: The Bedrock

**Key Concepts**:

- **Fermat's Little Theorem**: $a^{p-1} \equiv 1 \pmod p$.
- **Schwartz-Zippel Lemma**: "Non-zero polynomials have very few roots relative to field size."
  - _Impact_: Allows probabilistic verification of ZK proofs. Use random $r$, check $P(r) = 0$. If true, $P(x)$ is likely zero everywhere.

## 5. Mathematical Logic & Formal Verification

**Key Concepts**:

- **Halting Problem**: You cannot write a program that checks if _any_ program halts.
- **Rice's Theorem**: Non-trivial semantic properties are undecidable.
  - _Implication_: Static analysis tools will ALWAYS have false positives or false negatives.

### Symbolic Execution:

- Instead of `x = 5`, use `x = alpha`.
- Run the code to generate Path Constraints (algebraic formulas).
- Use SMT Solver (Z3) to find values of `alpha` that violate safety properties (`balance_after < 0`).
- _Audit Tip_: Use tools like **Halmos** for symbolic testing in Foundry.

## Summary Checklist for Math-Pilled Auditing

1.  **Linearize It**: Can you turn the AMM curve into a linear equation using logs? Do it in a spreadsheet.
2.  **Matrix the Risk**: Write the lending protocol's solvency check as $C \cdot P \cdot p$. Look for gaps in $C$.
3.  **Check the Group**: Is the crypto relying on a Group Homomorphism? Are the generators public?
4.  **Symbolic Check**: Don't just fuzz. Write a Halmos test that solves for the exploit.
