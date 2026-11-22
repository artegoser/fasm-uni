// Задание 21. MMX, вариант 3. Старшие 16 бит знаковых произведений.
#include <array>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <iostream>

using Words = std::array<std::int16_t, 19>;
Words array1{
    -32768, 32767, -32768, 32767, -1, 0, 1, 256, -256,
    1000, -1000, 12345, -12345, 30000, -30000, 7, -7, 20000, -20000
};
Words array2{
    -32768, 32767, 32767, -32768, 1, -32768, -1, 256, 256,
    -1000, -1000, -23456, -23456, 30000, 30000, -7, -7, 20000, 20000
};
constexpr int repetitions = 1000;

void multiply_elements(Words& result, std::size_t first) {
    for (std::size_t i = first; i < result.size(); ++i) {
        const std::int32_t product = std::int32_t{array1[i]} * array2[i];
        result[i] = static_cast<std::int16_t>(product >> 16);
    }
}

void multiply_scalar(Words& result) {
    multiply_elements(result, 0);
}

void multiply_mmx(Words& result) {
    std::size_t i = 0;
    for (; i + 4 <= result.size(); i += 4) {
        asm volatile(
            "movq (%[a]), %%mm0\n\t"
            "pmulhw (%[b]), %%mm0\n\t"
            "movq %%mm0, (%[out])"
            :
            : [a] "r"(array1.data() + i), [b] "r"(array2.data() + i),
              [out] "r"(result.data() + i)
            : "mm0", "memory");
    }
    asm volatile("emms" ::: "memory");
    multiply_elements(result, i);
}

auto measure(void (*multiply)(Words&), Words& result) {
    const auto start = std::chrono::steady_clock::now();
    for (int i = 0; i < repetitions; ++i) {
        multiply(result);
        asm volatile("" ::: "memory"); // Сохранить запись результата каждого прохода.
    }
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - start).count();
}

void print(const char* label, const Words& result) {
    std::cout << label;
    for (auto value : result) {
        std::cout << ' ' << value;
    }
    std::cout << '\n';
}

int main() {
    if (!__builtin_cpu_supports("mmx")) {
        std::cerr << "MMX is required\n";
        return 1;
    }
    Words scalar{}, mmx{};
    const auto scalar_time = measure(multiply_scalar, scalar);
    const auto mmx_time = measure(multiply_mmx, mmx);

    print("Scalar:", scalar);
    print("MMX:", mmx);
    std::cout << "Time (ns) for " << repetitions << " passes: scalar="
              << scalar_time << ", MMX=" << mmx_time << '\n';
}
