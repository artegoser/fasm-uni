Variant 3 solutions from `FPU сопроцессор 8087.docx` continue the previous numbering.
Each lab is a standalone FASM source using `use16` and `org 100h`.

| File | Lab | Results |
| --- | --- | --- |
| `20.asm` | FPU: 10 equally spaced points on `[1, 3]` | Console table; `xs`, `results`, `valid` |
| `21.asm` | MMX: high 16 bits of signed word products | `result_scalar`, `result_mmx`, `ticks_scalar`, `ticks_mmx` |
| `22.asm` | SSE: multiplication of float arrays | `result_scalar`, `result_sse`, `ticks_scalar`, `ticks_sse` |
| `23.asm` | AVX: multiplication of float arrays | `result_avx` |

See the [line-by-line explanations](explanations/) in Russian for each FASM and
C++ source file.

The function in task 20 is:

```text
F(x) = (2^(1/x - 1) - sin(x - 1)) * (3 - x)
       / (cos²(1 - x) + log2(2 + |1 - x|))
```

Its domain is `x != 0`: the denominator is at least 1. Invalid points print
`Значение аргумента не входит в ОДЗ` in DOS CP866. The table includes both endpoints.

Tasks 21 and 22 contain both implementations and measure 1,000 complete passes
without console I/O. Their 64-bit timing fields contain TSC ticks, including loop,
call and serialization overhead. Emulator timings do not measure host performance.
The example arrays contain 19 elements, exercising both vector and remainder loops.
When editing the inputs, keep `count` within the allocated array capacity.

Tasks 22 and 23 require real-mode DOS with a suitable CPU, without EMM386 or another
virtual-8086 monitor. Task 22 enables SSE and restores CR0/CR4 afterward. Task 23
briefly enters **16-bit protected mode**, enables XMM/YMM, computes the result, and
returns to DOS, restoring CR0, CR4, XCR0, GDTR, segments and interrupt flags.
AVX instructions cannot execute in real mode; they support 16-bit protected mode.
[Intel's explanation](https://community.intel.com/t5/Intel-ISA-Extensions/Why-AVX-do-not-support-real-V86-mode/m-p/851837)
describes this execution-mode restriction. All task 23 code is assembled with `use16`.

From the repository root, build any lab with:

```sh
fasm var3/20.asm /tmp/20.com
fasm var3/21.asm /tmp/21.com
fasm var3/22.asm /tmp/22.com
fasm var3/23.asm /tmp/23.com
```

Run the COM files in an appropriate DOS environment. Verify all old and new labs with:

```sh
python3 var3/verify.py
```

Verification requires FASM, Python Unicorn (tested with 2.1.4), and
`qemu-system-i386` with AVX emulation (tested with QEMU 10.2.2). It checks the actual
assembled programs, including empty arrays, every remainder length, signed extrema,
floating-point special values, domain errors, stack balance and restored CPU state.
The AVX tests boot the COM file at a nonzero DOS segment and exercise its full mode
transition in QEMU. `tests/avx_boot.asm` only supplies the test environment.

The four standalone C++ versions are in `cpp/` with the same lab numbers and sample
inputs. They use Intel syntax in `__asm { ... }` blocks, as in the handout.
Tasks 21 and 22 time the same 1,000 passes with `std::chrono::steady_clock` in
nanoseconds. Task 23 requires AVX support from the CPU and operating system.

Use Clang with `-fasm-blocks` on x86-64 Linux. The fixed array addresses in the
assembly blocks require a non-PIE build on this target.
Microsoft documents support through Pentium 4 and AMD Athlon for its inline
assembler, so use Clang for the handout's AVX mnemonics.
[MSVC inline instruction set](https://learn.microsoft.com/en-us/cpp/assembler/inline/instruction-set-for-inline-assembly)

```sh
for n in 20 21 22 23; do
    clang++ -std=c++20 -O2 -fasm-blocks -fno-pie -no-pie \
        -fno-vectorize -fno-slp-vectorize -Wall -Wextra \
        "var3/cpp/$n.cpp" -o "/tmp/lab$n" || break
    "/tmp/lab$n" || break
done
```
