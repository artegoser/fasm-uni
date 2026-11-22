// Задание 21. MMX, вариант 3. Старшие 16 бит знаковых произведений.
#include <atomic>
#include <chrono>
#include <cstdint>
#include <iostream>

constexpr int count = 19;
constexpr int repetitions = 1000;
std::int16_t array1[count]{
    -32768, 32767, -32768, 32767, -1, 0, 1, 256, -256,
    1000, -1000, 12345, -12345, 30000, -30000, 7, -7, 20000, -20000
};
std::int16_t array2[count]{
    -32768, 32767, 32767, -32768, 1, -32768, -1, 256, 256,
    -1000, -1000, -23456, -23456, 30000, 30000, -7, -7, 20000, 20000
};
std::int16_t scalar[count];
std::int16_t mmx[count];

std::int16_t high_word(int i) {
    const std::int32_t product = std::int32_t{array1[i]} * array2[i];
    return static_cast<std::int16_t>(product >> 16);
}

void multiply_scalar() {
    for (int i = 0; i < count; ++i) {
        scalar[i] = high_word(i);
    }
}

void multiply_mmx() {
    int i = 0;
    for (; i + 4 <= count; i += 4) {
        __asm {
            mov eax, i
            movq mm0, qword ptr [array1 + eax*2]
            movq mm1, qword ptr [array2 + eax*2]
            pmulhw mm0, mm1
            movq qword ptr [mmx + eax*2], mm0
        }
    }
    __asm { emms }
    for (; i < count; ++i) {
        mmx[i] = high_word(i);
    }
}

auto measure(void (*multiply)()) {
    const auto start = std::chrono::steady_clock::now();
    for (int i = 0; i < repetitions; ++i) {
        multiply();
        // Не дать компилятору объединить одинаковые проходы.
        std::atomic_signal_fence(std::memory_order_acq_rel);
    }
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - start).count();
}

void print(const char* label, const std::int16_t (&result)[count]) {
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
    const auto scalar_time = measure(multiply_scalar);
    const auto mmx_time = measure(multiply_mmx);

    print("Scalar:", scalar);
    print("MMX:", mmx);
    std::cout << "Time (ns) for " << repetitions << " passes: scalar="
              << scalar_time << ", MMX=" << mmx_time << '\n';
}
