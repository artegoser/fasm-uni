// Задание 23. AVX, вариант 3. Поэлементное умножение массивов float.
#include <iomanip>
#include <iostream>

constexpr int count = 19;
float array1[count]{
    1.5f, -2.5f, 0.0f, 4.0f, -5.25f, 6.5f, 7.0f, -8.0f, 0.125f,
    -0.5f, 10.0f, 12.25f, -13.5f, 14.0f, 15.75f, -16.0f, 17.5f, 18.0f, -19.25f
};
float array2[count]{
    2.0f, 3.0f, -4.0f, -0.5f, 1.25f, -2.0f, 0.25f, 8.0f, -0.125f,
    0.5f, -10.0f, 2.0f, 3.5f, -4.0f, 0.5f, 16.0f, -1.5f, 0.25f, 4.0f
};

float result[count];

void multiply_avx() {
    int i = 0;
    for (; i + 8 <= count; i += 8) {
        __asm {
            mov eax, i
            vmovups ymm0, [array1 + eax*4]
            vmovups ymm1, [array2 + eax*4]
            vmulps ymm0, ymm0, ymm1
            vmovups [result + eax*4], ymm0
        }
    }
    __asm { vzeroupper }
    for (; i < count; ++i) {
        result[i] = array1[i] * array2[i];
    }
}

int main() {
    if (!__builtin_cpu_supports("avx")) {
        std::cerr << "AVX is required\n";
        return 1;
    }
    multiply_avx();

    std::cout << std::setprecision(9) << "AVX:";
    for (float value : result) {
        std::cout << ' ' << value;
    }
    std::cout << '\n';
}
