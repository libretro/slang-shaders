import numpy as np
import matplotlib.pyplot as plt

# Define constants
blur = 0.3
t1 = -0.35

def func1(x):
    x = (x - t1) / blur
    return x * x * x * (blur - (x * blur) * 0.5)

def func2(x):
    x = x - t1
    return x**2 / (2 * blur)

# Generate x values
x_values = np.linspace(-0.4, 0.0, 500)

# Compute y values for both functions
y1_values = [func1(x) for x in x_values]
y2_values = [func2(x) for x in x_values]

# Create the plot
plt.figure(figsize=(8, 6))
plt.plot(x_values, y1_values, label='quart', color='blue')
plt.plot(x_values, y2_values, label='quad', color='red')
plt.title('Overlay of Two Functions')
plt.xlabel('x')
plt.ylabel('y')
plt.legend()
plt.grid(True)
plt.show()
