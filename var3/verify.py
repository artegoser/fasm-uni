#!/usr/bin/env python3
"""Build and execute all existing exercises: python3 var3/verify.py.

Requires fasm on PATH and the Python package unicorn (tested with 2.1.4).
The emulator supplies the DOS console calls used by these COM programs.
Generated binaries and symbol probes are kept in a temporary directory.
"""

import math
from pathlib import Path
import random
import struct
import subprocess
from tempfile import TemporaryDirectory
import unittest

from unicorn import Uc, UC_ARCH_X86, UC_HOOK_INTR, UC_MODE_16
from unicorn.x86_const import (
    UC_X86_REG_AL,
    UC_X86_REG_AX,
    UC_X86_REG_BP,
    UC_X86_REG_CS,
    UC_X86_REG_CX,
    UC_X86_REG_DS,
    UC_X86_REG_DX,
    UC_X86_REG_EFLAGS,
    UC_X86_REG_ES,
    UC_X86_REG_SP,
    UC_X86_REG_SS,
)


ROOT = Path(__file__).resolve().parent
SYMBOLS = {
    "3": "a b c k",
    "3_add": "num1_lo num1_hi num2_lo num2_hi res",
    "4": "a b c k",
    "5": "n result",
    "6": "count arr1 arr2",
    "7": "x y",
    "8": "count arr1 arr2",
    "9": "arr",
    "10": "mystr len",
    "11": "result",
    "12": "arr1 count1 arr2 count2 arr3 count3 avg1 avg2 avg3",
    "13": "arr count",
    "14": "result input_buffer",
    "15": "msg",
    "16": "radius1 radius2 radius3 area1 area2 area3",
    "17": "radius1 radius2 radius3 area1 area2 area3",
    "18": "buffer",
    "19": "a b c d e f result1 result2 result3",
}


def assemble(source, target):
    result = subprocess.run(
        ["fasm", str(source), str(target)], capture_output=True, text=True
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return target.read_bytes()


class Program:
    def __init__(self, code, symbols, patches=(), console=b"", flags=None):
        self.symbols = symbols
        self.uc = Uc(UC_ARCH_X86, UC_MODE_16)
        self.uc.mem_map(0, 0x10000)
        self.uc.mem_write(0x100, code)
        for register in (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS):
            self.uc.reg_write(register, 0)
        self.uc.reg_write(UC_X86_REG_SP, 0xFFFE)
        self.uc.reg_write(UC_X86_REG_BP, 0x5678)
        for name, data in patches:
            self.uc.mem_write(symbols[name], data)
        if flags is not None:
            # Task 15's initial ADD establishes the default example flags.
            # Replace only that setup so every CF/SF/ZF combination is tested.
            self.uc.mem_write(0x100, b"\x90" * 6)
            self.uc.reg_write(UC_X86_REG_EFLAGS, flags | 2)
        self.console = console
        self.output = bytearray()
        self.exit_code = None
        self.uc.hook_add(UC_HOOK_INTR, self.interrupt)
        self.uc.emu_start(0x100, 0x10000, count=100_000)
        if self.exit_code is None:
            raise AssertionError(
                "Program did not terminate within 100,000 instructions"
            )
        if self.uc.reg_read(UC_X86_REG_SP) != 0xFFFE:
            raise AssertionError("Program did not restore SP")

    def interrupt(self, uc, number, _):
        if number != 0x21:
            raise AssertionError(f"Unexpected interrupt {number:02X}h")
        ax = uc.reg_read(UC_X86_REG_AX)
        dx = uc.reg_read(UC_X86_REG_DX)
        function = ax >> 8
        if function == 0x4C:
            self.exit_code = ax & 0xFF
            uc.emu_stop()
            return
        if function == 0x09:
            data = bytes(uc.mem_read(dx, 0x10000 - dx))
            end = data.find(b"$")
            if end == -1:
                raise AssertionError("DOS string has no '$' terminator")
            self.output.extend(data[:end])
            uc.reg_write(UC_X86_REG_AL, ord("$"))
        elif function == 0x02:
            self.output.append(dx & 0xFF)
            uc.reg_write(UC_X86_REG_AL, dx & 0xFF)
        elif function == 0x40:
            count = uc.reg_read(UC_X86_REG_CX)
            self.output.extend(uc.mem_read(dx, count))
            uc.reg_write(UC_X86_REG_AX, count)
        elif function == 0x0A:
            maximum = uc.mem_read(dx, 1)[0]
            data = self.console[: maximum - 1]
            uc.mem_write(dx + 1, bytes([len(data)]) + data + b"\r")
        else:
            raise AssertionError(f"Unsupported DOS function {function:02X}h")
        # Console services provide no arithmetic flag preservation guarantee.
        uc.reg_write(UC_X86_REG_EFLAGS, uc.reg_read(UC_X86_REG_EFLAGS) ^ 0xC1)

    def read(self, name, size):
        return bytes(self.uc.mem_read(self.symbols[name], size))

    def unpack(self, name, fmt):
        return struct.unpack("<" + fmt, self.read(name, struct.calcsize("<" + fmt)))


def pack(fmt, *values):
    return struct.pack("<" + fmt, *values)


def quotient(a, b):
    result = abs(a) // abs(b)
    return -result if (a < 0) != (b < 0) else result


class Exercises(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = TemporaryDirectory(prefix="fasm-var3-")
        cls.addClassCleanup(cls.temp.cleanup)
        directory = Path(cls.temp.name)
        cls.programs = {}
        sources = {p.stem for p in ROOT.glob("*.asm")}
        if sources != set(SYMBOLS):
            raise AssertionError(
                f"Update verification coverage for: {sources ^ set(SYMBOLS)}"
            )
        for task, names in SYMBOLS.items():
            source = ROOT / f"{task}.asm"
            code = assemble(source, directory / f"{task}.com")
            # Ask FASM for label addresses; never guess offsets from opcodes.
            probe = directory / "symbols.asm"
            probe.write_text(
                f"include '{source.as_posix()}'\ndw {','.join(names.split())}\n"
            )
            binary = assemble(probe, directory / "symbols.bin")
            size = len(names.split()) * 2
            addresses = struct.unpack("<" + "H" * len(names.split()), binary[-size:])
            cls.programs[task] = code, dict(zip(names.split(), addresses))

    def run_task(self, task, patches=(), **options):
        program = Program(*self.programs[task], patches=patches, **options)
        self.assertEqual(program.exit_code, 0)
        return program

    def test_03_signed_formula(self):
        pairs = [
            (12, 4),
            (4, 12),
            (-12, -4),
            (12, -4),
            (-12, 4),
            (32767, 32767),
            (-32768, -32768),
            (30000, -15000),
        ]
        rng = random.Random(3)
        pairs += [
            (rng.randint(-32768, 32767), rng.randint(-32768, 32767)) for _ in range(100)
        ]
        for a, b in pairs:
            patches = [("a", pack("h", a)), ("b", pack("h", b))]
            c = quotient(a * b, a + b) if a + b else None
            valid = c is not None and -32768 <= c <= 32767 and a * c != 0
            k = quotient(a - b, a * c) if valid else None
            valid = valid and -32768 <= k <= 32767
            with self.subTest(a=a, b=b):
                p = Program(*self.programs["3"], patches=patches)
                self.assertEqual(p.exit_code, 0 if valid else 1)
                if valid:
                    self.assertEqual(p.unpack("c", "h"), (c,))
                    self.assertEqual(p.unpack("k", "h"), (k,))
        for a, b in [(0, 0), (12, -12), (1, 1), (32767, -32766)]:
            p = Program(
                *self.programs["3"], patches=[("a", pack("h", a)), ("b", pack("h", b))]
            )
            self.assertEqual(p.exit_code, 1)

    def test_03_unsigned_multiplication(self):
        rng = random.Random(33)
        pairs = [(196613, 131075), (0, 0xFFFFFFFF), (0xFFFFFFFF, 0xFFFFFFFF)]
        pairs += [(rng.getrandbits(32), rng.getrandbits(32)) for _ in range(100)]
        for a, b in pairs:
            p = self.run_task(
                "3_add", [("num1_lo", pack("I", a)), ("num2_lo", pack("I", b))]
            )
            self.assertEqual(p.unpack("res", "Q"), (a * b,))

    def test_04_mixed_sizes(self):
        cases = [
            (-6, 100, 50),
            (-128, -32768, 32767),
            (127, 32767, -32766),
            (127, 32767, 32767),
            (-128, -32768, -32768),
        ]
        rng = random.Random(4)
        cases += [
            (
                rng.randint(-128, 127),
                rng.randint(-32768, 32767),
                rng.randint(-32768, 32767),
            )
            for _ in range(100)
        ]
        for a, b, c in cases:
            p = self.run_task(
                "4", [("a", pack("b", a)), ("b", pack("h", b)), ("c", pack("h", c))]
            )
            self.assertEqual(p.unpack("k", "i"), (quotient(a * b, b + c),))
        p = Program(
            *self.programs["4"], patches=[("b", pack("h", 5)), ("c", pack("h", -5))]
        )
        self.assertEqual(p.exit_code, 1)

    def test_05_product(self):
        for n in range(1, 7):
            p = self.run_task("5", [("n", pack("H", n))])
            expected = math.prod(k * (k + 1) // 2 for k in range(2, n + 1))
            self.assertEqual(p.unpack("result", "H"), (expected,))
        self.assertEqual(expected, 56700)
        self.assertGreater(expected * 28, 65535)

    def test_06_array_ordinals(self):
        values = (10, -20, 30, -40, 50)
        for count in range(6):
            p = self.run_task(
                "6", [("count", bytes([count])), ("arr1", pack("5h", *values))]
            )
            expected = tuple(
                x - (i + 1) * 3 if i < count else x for i, x in enumerate(values)
            )
            self.assertEqual(p.unpack("arr1", "5h"), expected)
            self.assertEqual(p.unpack("arr2", "5h"), (5, 15, 25, 35, 45))

    def test_07_bit_masks(self):
        for x in (0, 0xFFFFFFFF, 0xABCDEF12, 0x12345678):
            p = self.run_task("7", [("x", pack("I", x))])
            self.assertEqual(p.unpack("y", "I"), (((x ^ 0xC8) & 0xFFFFFF00) | 0x7F8,))
            self.assertEqual(p.unpack("x", "I"), (x ^ 0xFFFFFFFF,))

    def test_08_array_comparison(self):
        for count in range(6):
            p = self.run_task("8", [("count", bytes([count]))])
            self.assertEqual(p.output, b"Arrays are equal")
        for i in range(5):
            values = [1, 2, 3, 4, 5]
            values[i] = 0
            p = self.run_task("8", [("arr2", pack("5H", *values))])
            self.assertEqual(p.output, b"Arrays are NOT equal")

    def test_09_logical_shifts(self):
        for values in [(0xFFFF,) * 7, (1, 2, 3, 4, 5, 6, 7)]:
            p = self.run_task("9", [("arr", pack("7H", *values))])
            expected = tuple(
                (x << (1 + i // 2)) & 0xFFFF if i % 2 == 0 else x >> (1 + i // 2)
                for i, x in enumerate(values)
            )
            self.assertEqual(p.unpack("arr", "7H"), expected)

    def test_10_cipher_roundtrip(self):
        for original in (b"Hello World!", b"ABCHefghijkl"):
            p = self.run_task("10", [("mystr", original + b"$")])
            encrypted = bytearray()
            for i, x in enumerate(original):
                shift = (i // 2) % 8
                value = (
                    ((x << shift) | (x >> (8 - shift)))
                    if i % 2 == 0
                    else ((x >> shift) | (x << (8 - shift)))
                )
                encrypted.append(value & 0xFF)
            expected = (
                b"Original: "
                + original
                + b"\r\nEncrypted: "
                + encrypted
                + b"\r\nDecrypted: "
                + original
            )
            self.assertEqual(p.output, expected)
            self.assertEqual(p.read("mystr", 12), original)

    def test_11_reverse_stack(self):
        p = self.run_task("11")
        self.assertEqual(p.read("result", 7), b"Hello!$")
        self.assertEqual(p.output, b"Hello!")

    def test_12_averages(self):
        p = self.run_task("12")
        for name, expected in [("avg1", 20), ("avg2", 300), ("avg3", 20)]:
            self.assertEqual(p.unpack(name, "H"), (expected,))
        p = self.run_task(
            "12", [("arr2", pack("5H", *([65535] * 5))), ("count1", pack("H", 0))]
        )
        self.assertEqual(p.unpack("avg1", "H"), (0,))
        self.assertEqual(p.unpack("avg2", "H"), (65535,))

    def test_13_decimal_output(self):
        p = self.run_task("13")
        self.assertEqual(p.output, b"-128, 0, 255, -32768, 1234, -1\r\n")
        p = self.run_task("13", [("count", pack("H", 0))])
        self.assertEqual(p.output, b"\r\n")

    def test_14_binary_input(self):
        for value in range(256):
            p = self.run_task("14", console=f"{value:08b}".encode())
            self.assertEqual(p.read("result", 1), bytes([value]))
            self.assertTrue(p.output.endswith(f"Result (hex): {value:02X}h".encode()))
        for invalid in (
            b"",
            b"0",
            b"1111111",
            b"111111111",
            b"00000002",
            b"-0000001",
            b"000 0000",
            b"abcdefgh",
        ):
            p = self.run_task("14", console=invalid)
            self.assertIn(b"Error:", p.output)

    def test_15_flag_sum_and_carry(self):
        for bits in range(8):
            flags = (bits & 1) | ((bits & 2) << 5) | ((bits & 4) << 5)
            p = self.run_task("15", flags=flags)
            total = bits.bit_count()
            self.assertIn(f"Sum of CF+ZF+SF = {total}".encode(), p.output)
            expected = flags ^ (1 if total > 1 else 0)
            self.assertEqual(p.uc.reg_read(UC_X86_REG_EFLAGS) & 0xC1, expected)

    def test_16_17_circle_areas(self):
        for task in ("16", "17"):
            for radii in [(1.0, 2.5, 4.0), (0.0, 0.125, 123.5)]:
                patches = [(f"radius{i}", pack("f", r)) for i, r in enumerate(radii, 1)]
                p = self.run_task(task, patches)
                for i, radius in enumerate(radii, 1):
                    self.assertAlmostEqual(
                        p.unpack(f"area{i}", "f")[0],
                        3.14 * radius * radius,
                        delta=max(1e-6, radius * radius * 1e-6),
                    )
                self.assertEqual(p.uc.reg_read(UC_X86_REG_BP), 0x5678)

    def test_18_binary_output(self):
        p = self.run_task("18")
        self.assertEqual(p.output, b"10101011")

    def test_19_signed_maximum(self):
        p = self.run_task("19")
        for i, expected in enumerate((20, 3, -50), 1):
            self.assertEqual(p.unpack(f"result{i}", "h"), (expected,))
        p = self.run_task(
            "19",
            [
                ("a", pack("h", 32767)),
                ("b", pack("h", -32768)),
                ("c", pack("h", -1)),
                ("d", pack("h", -1)),
            ],
        )
        self.assertEqual(p.unpack("result1", "h"), (32767,))
        self.assertEqual(p.unpack("result2", "h"), (-1,))


if __name__ == "__main__":
    unittest.main(verbosity=2)
