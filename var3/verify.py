#!/usr/bin/env python3
"""Build and execute all existing exercises: python3 var3/verify.py.

Requires fasm, unicorn 2.1.4, and qemu-system-i386 (10.2 tested).
Unicorn supplies DOS console calls. QEMU executes the AVX COM program,
including its 16-bit protected-mode transition. Binaries use a temporary directory.
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
    UC_X86_REG_CR0,
    UC_X86_REG_CR4,
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
    "20": "x1 x2 xs results valid",
    "21": "count repetitions array1 array2 result_scalar result_mmx ticks_scalar ticks_mmx",
    "22": "count repetitions array1 array2 result_scalar result_sse ticks_scalar ticks_sse",
    "23": "count array1 array2 result_avx",
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
        # ET is fixed to 1 on the CPUs supporting these instructions.
        self.uc.reg_write(UC_X86_REG_CR0, 0x10)
        self.initial_controls = {
            reg: self.uc.reg_read(reg) for reg in (UC_X86_REG_CR0, UC_X86_REG_CR4)
        }
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
        self.uc.emu_start(0x100, 0x10000, count=2_000_000)
        if self.exit_code is None:
            raise AssertionError(
                "Program did not terminate within 2,000,000 instructions"
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
        covered = set(SYMBOLS)
        if sources != covered:
            raise AssertionError(
                f"Update verification coverage for: {sources ^ covered}"
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

    def test_20_fpu_table_and_domain(self):
        from unicorn.x86_const import UC_X86_REG_FPSW, UC_X86_REG_FPTAG

        domain_message = "Значение аргумента не входит в ОДЗ"
        for x1, x2 in (
            (1.0, 3.0),
            (0.0, 9.0),
            (-3.0, 0.0),
            (0.0, 0.0),
            (1.0, 1.0),
            (3.0, 1.0),
            (0.125, 2.5),
            (-4.0, -1.0),
            (-(2.0**-40), -(2.0**-40)),
            (2.0**40, 2.0**40),
        ):
            with self.subTest(x1=x1, x2=x2):
                p = self.run_task("20", [("x1", pack("f", x1)), ("x2", pack("f", x2))])
                xs = p.unpack("xs", "10f")
                results = p.unpack("results", "10f")
                valid = p.read("valid", 10)
                lines = p.output.decode("cp866").splitlines()
                self.assertEqual(len(lines), 10)
                self.assertEqual(xs[0], x1)
                self.assertEqual(xs[-1], x2)
                for i, (x, result, line) in enumerate(zip(xs, results, lines)):
                    expected_x = struct.unpack("<f", pack("f", x1 + (x2 - x1) * i / 9))[
                        0
                    ]
                    self.assertEqual(x, expected_x)
                    printed_x, printed_result = line.split("  ")
                    self.assertAlmostEqual(
                        float(printed_x), x, delta=max(1e-44, abs(x) * 6e-7)
                    )
                    self.assertEqual(valid[i], int(x != 0))
                    if x == 0:
                        self.assertEqual(printed_result, domain_message)
                        self.assertEqual(result, 0)
                        continue
                    expected = (
                        (2 ** (1 / x - 1) - math.sin(x - 1))
                        * (3 - x)
                        / (math.cos(1 - x) ** 2 + math.log2(2 + abs(1 - x)))
                    )
                    self.assertAlmostEqual(
                        result, expected, delta=max(1e-7, abs(expected) * 2e-6)
                    )
                    self.assertAlmostEqual(
                        float(printed_result),
                        result,
                        delta=max(1e-44, abs(result) * 6e-7),
                    )
                self.assertEqual(p.uc.reg_read(UC_X86_REG_FPSW) & 0x3841, 0)
                self.assertEqual(p.uc.reg_read(UC_X86_REG_FPTAG), 0xFFFF)

    def test_21_mmx_signed_products_and_tails(self):
        rng = random.Random(8087)
        cases = [
            ([-32768, 32767, -1, 0, 1] * 4, [32767, -32768, 1, -1, 0] * 4),
            ([-32768] * 19, [-32768] * 19),
            ([32767] * 19, [32767] * 19),
        ]
        cases += [
            (
                [rng.randint(-32768, 32767) for _ in range(19)],
                [rng.randint(-32768, 32767) for _ in range(19)],
            )
            for _ in range(10)
        ]
        for count in range(20):
            for a, b in cases:
                with self.subTest(count=count, a=a[:count]):
                    p = self.run_task(
                        "21",
                        [
                            ("count", pack("H", count)),
                            ("repetitions", pack("H", 1)),
                            ("array1", pack("19h", *a[:19])),
                            ("array2", pack("19h", *b[:19])),
                            ("result_scalar", b"\x55" * 38),
                            ("result_mmx", b"\x55" * 38),
                        ],
                    )
                    expected = pack(
                        "h" * count,
                        *[x * y >> 16 for x, y in zip(a[:count], b[:count])],
                    ) + b"\x55" * (38 - 2 * count)
                    self.assertEqual(p.read("result_scalar", 38), expected)
                    self.assertEqual(p.read("result_mmx", 38), expected)

    def test_22_sse_float_products_and_tails(self):
        rng = random.Random(128)
        cases = [
            ([0.0, -0.0, 1.0, -1.0, 0.125] * 4, [-1.0, 1.0, -0.0, -1.0, -0.125] * 4),
            (
                [math.inf, -math.inf, math.nan, 1e-40, 1e38] * 4,
                [0.0, -1.0, 2.0, 0.5, 1e38] * 4,
            ),
        ]
        cases += [
            (
                [rng.uniform(-1e10, 1e10) for _ in range(19)],
                [rng.uniform(-1e10, 1e10) for _ in range(19)],
            )
            for _ in range(5)
        ]
        for count in range(20):
            for a, b in cases:
                a = struct.unpack("<19f", pack("19f", *a[:19]))
                b = struct.unpack("<19f", pack("19f", *b[:19]))
                with self.subTest(count=count, a=a[:count]):
                    p = self.run_task(
                        "22",
                        [
                            ("count", pack("H", count)),
                            ("repetitions", pack("H", 1)),
                            ("array1", pack("19f", *a)),
                            ("array2", pack("19f", *b)),
                            ("result_scalar", b"\x55" * 76),
                            ("result_sse", b"\x55" * 76),
                        ],
                    )
                    for name in ("result_scalar", "result_sse"):
                        actual = p.unpack(name, "19f")
                        for x, y, value in zip(a[:count], b[:count], actual):
                            expected = x * y
                            if math.isnan(expected):
                                self.assertTrue(math.isnan(value))
                                continue
                            try:
                                expected_bytes = pack("f", expected)
                            except OverflowError:
                                expected_bytes = pack(
                                    "f", math.copysign(math.inf, expected)
                                )
                            self.assertEqual(pack("f", value), expected_bytes)
                        self.assertEqual(
                            p.read(name, 76)[count * 4 :], b"\x55" * (76 - count * 4)
                        )
                    for reg, initial in p.initial_controls.items():
                        self.assertEqual(p.uc.reg_read(reg), initial)

    def test_21_22_default_benchmarks(self):
        from unicorn.x86_const import UC_X86_REG_FPTAG

        for task, kind in (("21", "mmx"), ("22", "sse")):
            with self.subTest(task=task):
                p = self.run_task(task)
                size = 38 if task == "21" else 76
                self.assertEqual(
                    p.read("result_scalar", size), p.read(f"result_{kind}", size)
                )
                self.assertGreater(p.unpack("ticks_scalar", "Q")[0], 0)
                self.assertGreater(p.unpack(f"ticks_{kind}", "Q")[0], 0)
                self.assertEqual(p.uc.reg_read(UC_X86_REG_FPTAG), 0xFFFF)

    def run_qemu(self, task, result_name, size, patches=(), cpu="max"):
        code, symbols = self.programs[task]
        code = bytearray(code)
        for name, data in patches:
            start = symbols[name] - 0x100
            code[start : start + len(data)] = data
        directory = Path(self.temp.name)
        program = directory / "qemu-case.com"
        program.write_bytes(code)
        disk = directory / "qemu-case.img"
        result = subprocess.run(
            [
                "fasm",
                "-d",
                f"PROGRAM='{program.as_posix()}'",
                "-d",
                f"RESULT={symbols[result_name]}",
                "-d",
                f"RESULT_SIZE={size}",
                str(ROOT / "tests" / "avx_boot.asm"),
                str(disk),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        disk.write_bytes(disk.read_bytes().ljust(1474560, b"\0"))
        output = directory / "qemu-output.bin"
        result = subprocess.run(
            [
                "qemu-system-i386",
                "-accel",
                "tcg",
                "-cpu",
                cpu,
                "-m",
                "16M",
                "-drive",
                f"file={disk},format=raw,if=floppy",
                "-boot",
                "a",
                "-display",
                "none",
                "-monitor",
                "none",
                "-serial",
                "none",
                "-no-reboot",
                "-device",
                "isa-debug-exit,iobase=0xf4,iosize=0x04",
                "-debugcon",
                f"file:{output}",
                "-global",
                "isa-debugcon.iobase=0xe9",
            ],
            capture_output=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 33, result.stderr.decode())
        data = output.read_bytes()
        self.assertEqual(len(data), 35 + size)
        code, ss, ds, es, cs, sp, bp, flags, cr0, cr4, old_gdt, new_gdt = struct.unpack(
            "<B7HII6s6s", data[:35]
        )
        self.assertEqual((ss, ds, es, cs), (0x1000,) * 4)
        self.assertEqual((sp, bp), (0xFFFE, 0x5678))
        self.assertEqual(flags & 0x200, 0x200)
        self.assertEqual((cr0, cr4), (0x10, 0))
        self.assertEqual(old_gdt, new_gdt)
        return code, data[35:]

    def test_21_22_qemu_real_mode_benchmarks(self):
        for task, kind, size in (("21", "mmx", 38), ("22", "sse", 76)):
            with self.subTest(task=task):
                code, data = self.run_qemu(task, "result_scalar", size * 2 + 16)
                self.assertEqual(code, 0)
                self.assertEqual(data[:size], data[size : size * 2])
                self.assertGreater(struct.unpack_from("<Q", data, size * 2)[0], 0)
                self.assertGreater(struct.unpack_from("<Q", data, size * 2 + 8)[0], 0)

    def test_23_avx_com_products_and_all_tails(self):
        rng = random.Random(256)
        cases = [
            (
                [rng.uniform(-1e10, 1e10) for _ in range(19)],
                [rng.uniform(-1e10, 1e10) for _ in range(19)],
            ),
            (
                [0.0, -0.0, math.inf, math.nan, 1e-40] * 4,
                [-1.0, 1.0, 0.0, 2.0, 0.5] * 4,
            ),
        ]
        for count in range(20):
            for a, b in cases:
                a = struct.unpack("<19f", pack("19f", *a[:19]))
                b = struct.unpack("<19f", pack("19f", *b[:19]))
                with self.subTest(count=count, a=a[:count]):
                    code, data = self.run_qemu(
                        "23",
                        "result_avx",
                        76,
                        [
                            ("count", pack("H", count)),
                            ("array1", pack("19f", *a)),
                            ("array2", pack("19f", *b)),
                            ("result_avx", b"\x55" * 76),
                        ],
                    )
                    self.assertEqual(code, 0)
                    actual = struct.unpack("<19f", data)
                    for x, y, value in zip(a[:count], b[:count], actual):
                        expected = x * y
                        if math.isnan(expected):
                            self.assertTrue(math.isnan(value))
                        else:
                            self.assertEqual(pack("f", value), pack("f", expected))
                    self.assertEqual(data[count * 4 :], b"\x55" * (76 - count * 4))

    def test_23_rejects_cpu_without_avx(self):
        code, data = self.run_qemu("23", "result_avx", 76, cpu="qemu32")
        self.assertEqual(code, 1)
        self.assertEqual(data, b"\0" * 76)


if __name__ == "__main__":
    unittest.main(verbosity=2)
