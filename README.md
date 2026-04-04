# Floating Point Multiplier (Verilog)

A hardware implementation of a **floating-point multiplier** in **Verilog/SystemVerilog**, designed for simulation and verification with **Verilator**.

This project implements a parameterized floating-point multiplication unit for IEEE-754-style single-precision operands, with support for special-case detection and exception flag generation. The design handles normal multiplication flow as well as corner cases such as **zero, subnormal inputs, infinity, NaN, overflow, underflow, and inexact results**.

## Project Overview

The core of this repository is the `fmul` RTL module, which performs floating-point multiplication by:

- extracting sign, exponent, and mantissa fields from both inputs
- detecting operand classes such as zero, subnormal, infinity, and NaN
- handling special-case combinations before normal arithmetic
- computing the result sign using XOR
- adding exponents and subtracting the bias
- multiplying significands including the hidden leading bit
- normalizing and rounding the mantissa
- generating status flags for exceptional conditions

This project is intended as a practical RTL design and verification exercise, useful for learning and demonstrating:

- floating-point arithmetic hardware design
- bit-level datapath development
- exception handling in digital systems
- simulation and debugging with Verilator

## Features

- Parameterized floating-point format
- IEEE-754-inspired multiplication datapath
- Special-case detection for:
  - zero
  - subnormal values
  - infinity
  - NaN
- Output exception/status flags:
  - `invalid`
  - `overflow`
  - `underflow`
  - `inexact`
- Verilator-friendly project structure
- Modular repository organization for RTL and verification

## Repository Structure

```text
.
├── dv/                 # Verification and testbench-related files
├── rtl/                # RTL source files
├── .gitignore
├── README.md
└── run_verilator.sh    # Script for compiling/running simulation with Verilator
```

## Main Module

### `fmul`

The main RTL block is a parameterized floating-point multiplier:

```verilog
module fmul #(
    parameter EXP  = 8,
    parameter MANT = 23,
    parameter BIAS = 127
)
```

This configuration matches the standard single-precision floating-point format:

- 1 sign bit
- 8 exponent bits
- 23 mantissa bits

## Module Interface

### Inputs

- `a` — first floating-point operand
- `b` — second floating-point operand

### Outputs

- `y` — multiplication result
- `invalid` — asserted for invalid operations
- `overflow` — asserted when exponent exceeds representable range
- `underflow` — asserted when result is too small to be represented normally
- `inexact` — asserted when the result cannot be represented exactly

## Arithmetic Flow

The multiplier follows this general sequence:

1. Extract sign, exponent, and mantissa from both operands
2. Classify each input as:
   - zero
   - subnormal
   - infinity
   - NaN
3. Resolve special cases before entering the normal multiplication path
4. Compute the output sign using XOR of the input signs
5. Compute the working exponent:
   - exponent A + exponent B - bias
6. Multiply the significands including the implicit leading `1`
7. Normalize the product if needed
8. Apply rounding logic to the mantissa
9. Check for overflow and underflow
10. Pack the final result and flags

## Special Case Handling

The design includes dedicated handling for important floating-point corner cases, including:

- `NaN * anything -> NaN`
- `0 * infinity -> NaN`, with `invalid = 1`
- `infinity * finite -> infinity`
- `zero * finite -> zero`
- subnormal inputs handled through dedicated input classification logic

## Notes on Current Behavior

This implementation is focused on a practical RTL realization of floating-point multiplication and exception handling. It follows an IEEE-754-style structure, but it is best described as an **educational / project-oriented implementation**, not yet a complete formally verified IEEE-754 compliant FPU.

In the current version:

- special values are explicitly detected and handled
- exponent calculation and normalization are implemented in RTL
- rounding is included in the mantissa processing path
- overflow and underflow conditions are reported through flags
- subnormal inputs are currently handled through a simplified control path

## How to Run

This project includes a script for running the design with Verilator.

### Example

```bash
chmod +x run_verilator.sh
./run_verilator.sh
```

Make sure **Verilator** is installed on your system before running the script.

## Tools Used

- **Verilog / SystemVerilog**
- **Verilator**

## Learning Goals

This project was built to strengthen practical skills in:

- RTL design of arithmetic units
- floating-point number representation
- exception and corner-case handling
- datapath and control design
- simulation and debugging
- hardware verification workflow

## Possible Future Improvements

Some natural next steps for the project would be:

- full IEEE-754 rounding mode support
- improved handling of subnormal outputs
- extended and automated testbench coverage
- support for additional precisions
- pipelined version for higher throughput
- integration into a larger floating-point unit or processor datapath

## Author

Designed and implemented as a digital design / RTL project focused on floating-point multiplication, special-case handling, and hardware verification.