// Задание 23. AVX, вариант 3. Поэлементное умножение массивов float.
#include <array>
#include <cstddef>
#include <iomanip>
#include <immintrin.h>
#include <iostream>

using Floats = std::array<float, 19>;
constexpr Floats array1{
    1.5f, -2.5f, 0.0f, 4.0f, -5.25f, 6.5f, 7.0f, -8.0f, 0.125f,
    -0.5f, 10.0f, 12.25f, -13.5f, 14.0f, 15.75f, -16.0f, 17.5f, 18.0f, -19.25f
};
constexpr Floats array2{
    2.0f, 3.0f, -4.0f, -0.5f, 1.25f, -2.0f, 0.25f, 8.0f, -0.125f,
    0.5f, -10.0f, 2.0f, 3.5f, -4.0f, 0.5f, 16.0f, -1.5f, 0.25f, 4.0f
};

[[gnu::target("avx")]]
void multiply_avx(const Floats& a, const Floats& b, Floats& result) {
    std::size_t i = 0;
    for (; i + 8 <= result.size(); i += 8) {
        const __m256 left = _mm256_loadu_ps(a.data() + i);
        const __m256 right = _mm256_loadu_ps(b.data() + i);
        _mm256_storeu_ps(result.data() + i, _mm256_mul_ps(left, right));
    }
    for (; i < result.size(); ++i) {
        result[i] = a[i] * b[i];
    }
}

int main() {
    if (!__builtin_cpu_supports("avx")) {
        std::cerr << "AVX is required\n";
        return 1;
    }
    Floats result{};
    multiply_avx(array1, array2, result);

    std::cout << std::setprecision(9) << "AVX:";
    for (float value : result) {
        std::cout << ' ' << value;
    }
    std::cout << '\n';
}
