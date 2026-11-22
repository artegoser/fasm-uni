// Задание 20. FPU, вариант 3. Таблица функции на [1, 3].
#include <cmath>
#include <iomanip>
#include <iostream>

float evaluate(float x) {
    const double angle = double{x} - 1;
    const double exponent = 1.0 / x - 1;
    const double log_argument = 2 + std::abs(angle);
    double power, cosine, sine, logarithm;

    // GNU asm: степень через F2XM1 и FSCALE, синус и косинус через FSINCOS.
    asm(
        "fldl %[exponent]\n\t"
        "fld %%st(0)\n\t"
        "frndint\n\t"
        "fxch %%st(1)\n\t"
        "fsub %%st(1), %%st(0)\n\t"
        "f2xm1\n\t"
        "fld1\n\t"
        "faddp\n\t"
        "fscale\n\t"
        "fstp %%st(1)\n\t"
        "fstpl %[power]\n\t"
        "fldl %[angle]\n\t"
        "fsincos\n\t"
        "fstpl %[cosine]\n\t"
        "fstpl %[sine]\n\t"
        "fld1\n\t"
        "fldl %[log_argument]\n\t"
        "fyl2x\n\t"
        "fstpl %[logarithm]"
        : [power] "=&m"(power), [cosine] "=&m"(cosine),
          [sine] "=&m"(sine), [logarithm] "=m"(logarithm)
        : [exponent] "m"(exponent), [angle] "m"(angle),
          [log_argument] "m"(log_argument)
        : "st", "st(1)", "st(2)");

    return static_cast<float>(
        (power - sine) * (3.0 - x) / (cosine * cosine + logarithm));
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
