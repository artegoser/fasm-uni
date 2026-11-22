// Задание 22. SSE, вариант 3. Поэлементное умножение массивов float.
#include <array>
#include <chrono>
#include <cstddef>
#include <iomanip>
#include <iostream>
#include <xmmintrin.h>

using Floats = std::array<float, 19>;
Floats array1{
    1.5f, -2.5f, 0.0f, 4.0f, -5.25f, 6.5f, 7.0f, -8.0f, 0.125f,
    -0.5f, 10.0f, 12.25f, -13.5f, 14.0f, 15.75f, -16.0f, 17.5f, 18.0f, -19.25f
};
Floats array2{
    2.0f, 3.0f, -4.0f, -0.5f, 1.25f, -2.0f, 0.25f, 8.0f, -0.125f,
    0.5f, -10.0f, 2.0f, 3.5f, -4.0f, 0.5f, 16.0f, -1.5f, 0.25f, 4.0f
};
constexpr int repetitions = 1000;

void multiply_elements(Floats& result, std::size_t first) {
    for (std::size_t i = first; i < result.size(); ++i) {
        // Обычное умножение float могло бы использовать SSE на x86-64.
        asm("flds %1\n\tfmuls %2\n\tfstps %0"
            : "=m"(result[i])
            : "m"(array1[i]), "m"(array2[i])
            : "st");
    }
}

void multiply_scalar(Floats& result) {
    multiply_elements(result, 0);
}

void multiply_sse(Floats& result) {
    std::size_t i = 0;
    for (; i + 4 <= result.size(); i += 4) {
        const __m128 a = _mm_loadu_ps(array1.data() + i);
        const __m128 b = _mm_loadu_ps(array2.data() + i);
        _mm_storeu_ps(result.data() + i, _mm_mul_ps(a, b));
    }
    multiply_elements(result, i);
}

auto measure(void (*multiply)(Floats&), Floats& result) {
    const auto start = std::chrono::steady_clock::now();
    for (int i = 0; i < repetitions; ++i) {
        multiply(result);
        asm volatile("" ::: "memory"); // Сохранить запись результата каждого прохода.
    }
    return std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - start).count();
}

void print(const char* label, const Floats& result) {
    std::cout << label;
    for (float value : result) {
        std::cout << ' ' << value;
    }
    std::cout << '\n';
}

int main() {
    Floats scalar{}, sse{};
    const auto scalar_time = measure(multiply_scalar, scalar);
    const auto sse_time = measure(multiply_sse, sse);

    std::cout << std::setprecision(9);
    print("Scalar:", scalar);
    print("SSE:", sse);
    std::cout << "Time (ns) for " << repetitions << " passes: scalar="
              << scalar_time << ", SSE=" << sse_time << '\n';
}
