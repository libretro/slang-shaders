import numpy as np
from scipy.optimize import minimize
import matplotlib.pyplot as plt

def get_b_c(a):
    # b = -a/2 - 1
    # c = 2 - 2a
    return -a/2 - 1, 2 - 2*a

def polynomial(x, a):
    b, c = get_b_c(a)
    return a * x**4 + b * x**3 + c * x**2

def target_function(x):
    from scipy.special import erf
    return 0.5 * (x * erf(x / np.sqrt(2)) + np.exp(-x**2 / 2) / np.sqrt(2 * np.pi) + x)


def loss(a):
    x_vals = np.linspace(-1, 1, 100)
    y_poly = polynomial(x_vals, a)
    y_target = target_function(x_vals)
    return np.sum((y_poly - y_target)**2)

# Optimize
initial_guess = [0]
result = minimize(loss, initial_guess)
a_opt = result.x[0]
b_opt, c_opt = get_b_c(a_opt)

# Plot results
x_plot = np.linspace(-1, 1, 100)
y_poly = polynomial(x_plot, a_opt)
y_target = target_function(x_plot)

print(f"Optimal parameters: a={a_opt:.6f}, b={b_opt:.6f}, c={c_opt:.6f}")

plt.figure(figsize=(10, 6))
plt.plot(x_plot, y_poly, label='Fitted Polynomial')
plt.plot(x_plot, y_target, '--', label='Target Function')
plt.legend()
plt.grid(True)
plt.title('Polynomial Fit with Constraints')
plt.xlabel('x')
plt.ylabel('y')
plt.show()

# Verify constraints
print(f"y(1) = {polynomial(1, a_opt):.6f}")
h = 1e-5
derivative_at_1 = (polynomial(1 + h, a_opt) - polynomial(1, a_opt)) / h
print(f"y'(1) = {derivative_at_1:.6f}")
