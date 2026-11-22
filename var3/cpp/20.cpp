// Задание 20. FPU, вариант 3. Таблица функции на [1, 3].
#include <iomanip>
#include <iostream>

float evaluate(float x) {
    const float one = 1.0f;
    const float two = 2.0f;
    const float three = 3.0f;
    float value = 0.0f;

    __asm {
        // 2^z, где z = 1/x - 1. F2XM1 получает только дробную часть.
        fld1
        fdiv x
        fsub one
        fld st(0)
        frndint
        fxch st(1)
        fsub st(0), st(1)
        f2xm1
        fld1
        faddp st(1), st(0)
        fscale
        fstp st(1)

        // Одновременно получаем sin(x-1) и cos(x-1).
        fld x
        fsub one
        fld st(0)
        fsincos
        fmul st(0), st(0)
        fxch st(1)
        fsubp st(3), st(0) // ST(0) = cos², ST(1) = x-1, ST(2) = 2^z - sin

        fxch st(1)
        fabs
        fadd two
        fld1
        fxch st(1)
        fyl2x              // log2(2+|x-1|)
        faddp st(1), st(0)
        fdivp st(1), st(0)
        fld three
        fsub x
        fmulp st(1), st(0)
        fstp value
    }
    return value;
}

int main() {
    constexpr float x1 = 1.0f;
    constexpr float x2 = 3.0f;
    constexpr int points = 10;
    const double step = (double{x2} - x1) / (points - 1);

    std::cout << std::scientific << std::setprecision(6);
    for (int i = 0; i < points; ++i) {
        const float x = i == points - 1 ? x2 : static_cast<float>(x1 + i * step);
        std::cout << x << "  ";
        if (x == 0) {
            std::cout << "Значение аргумента не входит в ОДЗ\n";
        } else {
            const float value = evaluate(x);
            std::cout << (value == 0 ? 0.0f : value) << '\n';
        }
    }
}
