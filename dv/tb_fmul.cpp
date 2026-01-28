// tb_fmul.cpp
//
// Verilator C++ testbench for fmul. Fmul supports only qNaN, denormals are zero and we are flushing to zero.
// Features:
//  - Reference model matching DUT behavior (DAZ/FTZ + constant qNaN)
//  - Optional VCD tracing:        --trace   (writes wave.vcd)
//  - Optional print on PASS too:  --print-ok
//  - Optional check of status flags (invalid/overflow/underflow/inexact):
//                                 --check-flags     (enable checking; default is OFF)
//  - Random test count:           --n <N>
//
// Example runs:
//  1) Quiet (print only FAIL), don't check flags:
//        ./obj_dir/Vfmul --n 200000
//  2) Print every PASS + FAIL, don't check flags:
//        ./obj_dir/Vfmul --n 50 --print-ok
//  3) Trace + print, and check flags:
//        ./obj_dir/Vfmul --n 50 --print-ok --trace --check-flags
//  4) Quiet + trace + check flags:
//        ./obj_dir/Vfmul --n 200000 --trace --check-flags

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <limits>
#include <random>
#include <string>

#include "Vfmul.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

// Global flags
static bool PRINT_OK = false;
static bool CHECK_FLAGS = false;

// Bit/float helpers 
static inline uint32_t f32_to_bits(float f) {
  union { float f; uint32_t u; } v;
  v.f = f;
  return v.u;
}
static inline float bits_to_f32(uint32_t u) {
  union { float f; uint32_t u; } v;
  v.u = u;
  return v.f;
}

// Help to extract sign, exp and mantissa/fraction
static inline uint32_t sign_bit(uint32_t x) { return x >> 31; }
static inline uint32_t exp_field(uint32_t x) { return (x >> 23) & 0xFFu; }
static inline uint32_t frac_field(uint32_t x) { return x & 0x7FFFFFu; }

// Check if NaN
static inline bool is_nan_bits(uint32_t x) {
  return exp_field(x) == 0xFFu && frac_field(x) != 0;
}
// Check if Inf
static inline bool is_inf_bits(uint32_t x) {
  return exp_field(x) == 0xFFu && frac_field(x) == 0;
}
// Check if zero
static inline bool is_zero_bits(uint32_t x) {
  return exp_field(x) == 0 && frac_field(x) == 0;
}
// Check if subnormal
static inline bool is_sub_bits(uint32_t x) {
  return exp_field(x) == 0 && frac_field(x) != 0;
}
// We work only with qNaN
static inline uint32_t qnan_const() { return 0x7FC00000u; }

// Output structure
struct RefOut {
  uint32_t y;
  bool invalid;
  bool overflow;
  bool underflow;
  bool inexact;
};

// Output is zero (signed), helper function to generate signed zero
static inline uint32_t pack_signed_zero(uint32_t sign) {
  return (sign << 31);
}

// -----------------------------------------------------------------
// Reference model, only qNaN, subnormals are zeros
// -----------------------------------------------------------------
static RefOut ref_model(uint32_t a, uint32_t b) {
  RefOut o{};
  o.y = 0;
  o.invalid = o.overflow = o.underflow = o.inexact = false;

  uint32_t s = (sign_bit(a) ^ sign_bit(b)) & 1u;

  // Option B: any NaN input => constant qNaN, no invalid
  if (is_nan_bits(a) || is_nan_bits(b)) {
    o.y = qnan_const();
    return o;
  }

  // We will treat subnormals as zeros
  bool a_eff_zero = is_zero_bits(a) || is_sub_bits(a);
  bool b_eff_zero = is_zero_bits(b) || is_sub_bits(b);
  // Check if infinity
  bool a_inf = is_inf_bits(a);
  bool b_inf = is_inf_bits(b);

  // Special cases: Inf * 0 => invalid case and qNaN case
  if ((a_inf && b_eff_zero) || (b_inf && a_eff_zero)) {
    o.invalid = true;
    o.y = qnan_const();
    return o;
  }
  // Inf * finite => Inf
  if (a_inf || b_inf) {
    o.y = (s << 31) | (0xFFu << 23);
    return o;
  }
  // 0 * anything => signed zero
  if (a_eff_zero || b_eff_zero) {
    o.y = pack_signed_zero(s);
    return o;
  }

  // ----------------------------------
  // Finite normal multiply
  // ----------------------------------
  float fa = bits_to_f32(a);
  float fb = bits_to_f32(b);

  long double exact = (long double)fa * (long double)fb;
  float fres = (float)exact;
  uint32_t fres_bits = f32_to_bits(fres);

  // Overflow to inf
  if (is_inf_bits(fres_bits) && std::isfinite((double)exact)) {
    o.overflow = true;
    o.inexact  = true;
    o.y = (s << 31) | (0xFFu << 23);
    return o;
  }

  // Flush To Zero (FTZ) output for subnormal region (< min normal)
  const long double min_norm = std::ldexp((long double)1.0, -126);
  if (exact != 0.0L && fabsl(exact) < min_norm) {
    o.underflow = true;
    o.inexact   = true;
    o.y = pack_signed_zero(s);
    return o;
  }

  // Normal output, force XOR sign; preserve signed zero if it ever happens
  if ((fres_bits & 0x7FFFFFFFu) == 0) {
    o.y = pack_signed_zero(s);
  } else {
    o.y = (fres_bits & 0x7FFFFFFFu) | (s << 31);
  }

  // Inexact if not exactly representable
  long double back = (long double)bits_to_f32(o.y);
  if (back != exact) o.inexact = true;

  return o;
}

// -----------------------------------------------------------------
// Pretty printing :)
// -----------------------------------------------------------------
static void print_fp(const char* label, uint32_t bits) {
  uint32_t sign = (bits >> 31) & 0x1;
  uint32_t exp  = (bits >> 23) & 0xFF;
  uint32_t man  = bits & 0x7FFFFF;

  if (is_nan_bits(bits)) {
    std::printf(
      "  %-8s : 0x%08x  NaN"
      "  | s=0x%x e=0x%02x m=0x%06x\n",
      label, bits, sign, exp, man
    );
  }
  else if (is_inf_bits(bits)) {
    std::printf(
      "  %-8s : 0x%08x  %sInf"
      "  | s=0x%x e=0x%02x m=0x%06x\n",
      label, bits, (sign ? "-" : "+"), sign, exp, man
    );
  }
  else {
    float f = bits_to_f32(bits);
    std::printf(
      "  %-8s : 0x%08x  %+.10e"
      "  | s=0x%x e=0x%02x m=0x%06x\n",
      label, bits, f, sign, exp, man
    );
  }
}


static void print_case(const char* status, const char* tag,
                       uint32_t a, uint32_t b,
                       uint32_t y_dut, bool inv_dut, bool ovf_dut, bool unf_dut, bool inx_dut,
                       uint32_t y_ref, bool inv_ref, bool ovf_ref, bool unf_ref, bool inx_ref) {
  std::printf("\n================================== %s [%s] ==================================\n", status, tag);

  print_fp("a", a);
  print_fp("b", b);

  std::printf("\n--- DUT ---\n");
  print_fp("y", y_dut);
  std::printf("  flags: invalid=%d overflow=%d underflow=%d inexact=%d\n",
              (int)inv_dut, (int)ovf_dut, (int)unf_dut, (int)inx_dut);

  std::printf("\n--- REF ---\n");
  print_fp("y", y_ref);
  std::printf("  flags: invalid=%d overflow=%d underflow=%d inexact=%d\n",
              (int)inv_ref, (int)ovf_ref, (int)unf_ref, (int)inx_ref);

  std::printf("=================================================================================\n");
}

// -----------------------------------------------------------------
// Eval + optional trace
// -----------------------------------------------------------------
static inline void tick_eval(Vfmul* dut,
                             VerilatedVcdC* tfp,
                             vluint64_t& t) {
  dut->eval();
  if (tfp) tfp->dump(t);
  t++;
}

// -----------------------------------------------------------------
// Single test
// -----------------------------------------------------------------
static bool run_one(Vfmul* dut,
                    VerilatedVcdC* tfp,
                    vluint64_t& t,
                    uint32_t a, uint32_t b,
                    const char* tag,
                    bool verbose_on_fail) {
  dut->a = a;
  dut->b = b;

  // a couple evals gives nicer waveform context
  tick_eval(dut, tfp, t);
  tick_eval(dut, tfp, t);

  uint32_t y_dut = dut->y;
  bool inv_dut = dut->invalid;
  bool ovf_dut = dut->overflow;
  bool unf_dut = dut->underflow;
  bool inx_dut = dut->inexact;

  RefOut r = ref_model(a, b);

  // Always check result bits
  bool ok_y = (y_dut == r.y);

  // Optionally check flags
  bool ok_flags = true;
  if (CHECK_FLAGS) {
    ok_flags = (inv_dut == r.invalid) &&
               (ovf_dut == r.overflow) &&
               (unf_dut == r.underflow) &&
               (inx_dut == r.inexact);
  }

  bool ok = ok_y && ok_flags;

  if ((!ok && verbose_on_fail) || (ok && PRINT_OK)) {
    print_case(ok ? "PASS" : "FAIL", tag,
               a, b,
               y_dut, inv_dut, ovf_dut, unf_dut, inx_dut,
               r.y, r.invalid, r.overflow, r.underflow, r.inexact);

    if (!ok && !CHECK_FLAGS && !ok_y) {
      std::printf("NOTE: Flag checking is disabled (--check-flags not set). "
                  "Failure is due to output y mismatch.\n");
    } else if (!ok && !CHECK_FLAGS && ok_y) {
      std::printf("NOTE: Output y matches, but flags are ignored (flag checking disabled).\n");
    }
  }

  tick_eval(dut, tfp, t);
  tick_eval(dut, tfp, t);

  return ok;
}

// -----------------------------------------------------------------
// Random generator
// -----------------------------------------------------------------
static uint32_t rand_bits(std::mt19937_64& rng) {
  std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFFu);
  uint32_t r = dist(rng);

  std::uniform_int_distribution<int> sel(0, 11);
  switch (sel(rng)) {
    case 0: return 0x00000000u; // +0
    case 1: return 0x80000000u; // -0
    case 2: return 0x7F800000u; // +Inf
    case 3: return 0xFF800000u; // -Inf
    case 4: return 0x7FC00001u; // NaN
    case 5: return (r & 0x807FFFFFu); // exp=0 (subnormal/zero)
    case 6: return (r & 0x807FFFFFu) | (1u << 23); // exp=1
    case 7: return (r & 0x807FFFFFu) | (254u << 23); // exp=254
    default: return r;
  }
}

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);

  bool do_trace = false;
  uint64_t nrand = 200000;
  uint64_t seed  = 0xC001D00Du;

  // Args:
  //  --n <N>           random tests
  //  --trace           enable wave.vcd
  //  --print-ok        print PASS cases too
  //  --check-flags     check invalid/overflow/underflow/inexact
  //  --seed <S>        RNG seed
  for (int i = 1; i < argc; i++) {
    std::string arg = argv[i];
    if (arg == "--trace") do_trace = true;
    else if (arg == "--print-ok") PRINT_OK = true;
    else if (arg == "--check-flags") CHECK_FLAGS = true;
    else if (arg == "--n" && i + 1 < argc) nrand = std::strtoull(argv[++i], nullptr, 10);
    else if (arg == "--seed" && i + 1 < argc) seed = std::strtoull(argv[++i], nullptr, 10);
  }

  auto* dut = new Vfmul;

  VerilatedVcdC* tfp = nullptr;
  vluint64_t t = 0;

  if (do_trace) {
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("wave.vcd");
  }

  uint64_t tests = 0, fails = 0;

  auto check = [&](uint32_t a, uint32_t b, const char* tag, bool verbose_on_fail) {
    tests++;
    bool ok = run_one(dut, tfp, t, a, b, tag, verbose_on_fail);
    if (!ok) fails++;
  };

  // Directed tests
  check(0x7F800000u, 0x00000000u, "Inf*0", true);
  check(0x7FC00001u, 0x3F800000u, "NaN*1", true);
  check(0x00000001u, 0x3F800000u, "subnormal input DAZ", true);
  check(0x00800000u, 0x3F000000u, "min_norm*0.5 => FTZ", true);
  check(0x7F7FFFFFu, 0x40000000u, "max_finite*2 => overflow", true);

  // Random tests
  std::mt19937_64 rng(seed);
  for (uint64_t i = 0; i < nrand; i++) {
    uint32_t a = rand_bits(rng);
    uint32_t b = rand_bits(rng);
    tests++;
    bool ok = run_one(dut, tfp, t, a, b, "rand", /*verbose_on_fail=*/false);
    if (!ok) {
      fails++;
      // Re-run once verbose so you see full numeric info
      run_one(dut, tfp, t, a, b, "rand (verbose)", /*verbose_on_fail=*/true);
      break;
    }
  }

  if (tfp) {
    tfp->close();
    delete tfp;
  }

  std::printf("\n---------------------------------------------------------------------------------\n");
  std::printf("Tests run : %llu\n", (unsigned long long)tests);
  std::printf("Failures  : %llu\n", (unsigned long long)fails);
  std::printf("Flag check: %s\n", CHECK_FLAGS ? "ENABLED (--check-flags)" : "DISABLED");
  std::printf("---------------------------------------------------------------------------------\n");

  delete dut;
  return (fails == 0) ? 0 : 1;
}
