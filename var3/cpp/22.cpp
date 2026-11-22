// Задание 22. SSE, вариант 3. Поэлементное умножение массивов float.
#include <atomic>
#include <chrono>
#include <iomanip>
#include <iostream>

constexpr int count = 19;
constexpr int repetitions = 1000;
float array1[count]{
    1.5f, -2.5f, 0.0f, 4.0f, -5.25f, 6.5f, 7.0f, -8.0f, 0.125f,
    -0.5f, 10.0f, 12.25f, -13.5f, 14.0f, 15.75f, -16.0f, 17.5f, 18.0f, -19.25f
};
float array2[count]{
    2.0f, 3.0f, -4.0f, -0.5f, 1.25f, -2.0f, 0.25f, 8.0f, -0.125f,
    0.5f, -10.0f, 2.0f, 3.5f, -4.0f, 0.5f, 16.0f, -1.5f, 0.25f, 4.0f
};
float scalar[count];
float sse[count];

void multiply_scalar() {
    for (int i = 0; i < count; ++i) {
        // Скалярный вариант использует только x87 для работы с float.
        __asm {
            mov eax, i
            fld dword ptr [array1 + eax*4]
            fmul dword ptr [array2 + eax*4]
            fstp dword ptr [scalar + eax*4]
        }
    }
}

void multiply_sse() {
    int i = 0;
    for (; i + 4 <= count; i += 4) {
        __asm {
            mov eax, i
            movups xmm0, [array1 + eax*4]
            movups xmm1, [array2 + eax*4]
            mulps xmm0, xmm1
            movups [sse + eax*4], xmm0
        }
    }
    for (; i < count; ++i) {
        sse[i] = array1[i] * array2[i];
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

void print(const char* label, const float (&result)[count]) {
    std::cout << label;
    for (float value : result) {
        std::cout << ' ' << value;
    }
    std::cout << '\n';
}

int main() {
    const auto scalar_time = measure(multiply_scalar);
    const auto sse_time = measure(multiply_sse);

    std::cout << std::setprecision(9);
    print("Scalar:", scalar);
    print("SSE:", sse);
    std::cout << "Time (ns) for " << repetitions << " passes: scalar="
              << scalar_time << ", SSE=" << sse_time << '\n';
}
