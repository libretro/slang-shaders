import numpy as np
from scipy.special import erf
import matplotlib.pyplot as plt

def target_function(t):
    return 0.5 * (t + t * erf(t/np.sqrt(2)) + np.exp(-t**2/2)/np.sqrt(2*np.pi))

# Check behavior
x = np.linspace(-5, 5, 1000)
y = target_function(x)

# Plot function
plt.figure(figsize=(12, 6))
plt.plot(x, y, label='Target Function')
plt.plot(x, np.zeros_like(x), 'k--', alpha=0.3)  # zero line
plt.grid(True)
plt.legend()
plt.title('Target Function Analysis')

# Check monotonicity
dy = np.diff(y)
is_monotonic = np.all(dy >= 0)
print(f"Is monotonic: {is_monotonic}")

# Find zero crossings
zero_crossings = x[:-1][np.where(np.diff(np.signbit(y)))[0]]
print(f"Zero crossings at x ≈ {zero_crossings}")

plt.show()
