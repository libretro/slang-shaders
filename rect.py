import numpy as np
import matplotlib.pyplot as plt

def smooth_transition_regular(x, start, end, blur):
    if blur == 0:
        if x <= start: return 0.0
        if x >= end: return end - start
        return x - start
    
    t1 = start - blur/2
    t2 = start + blur/2
    t3 = end - blur/2
    t4 = end + blur/2
    
    if x <= t1: return 0.0
    if x >= t4: return end - start
    
    if x <= t2:
        x = (x - t1) / blur
        return x * x * x * (blur - (x * blur) * 0.5)
    elif x <= t3:
        return x - start
    else:
        x = (t4 - x) / blur
        return end - start - (x * x * x * (blur - (x * blur) * 0.5))

def plot_transition(start, end, blur):
    x = np.linspace(start - blur, end + blur, 1000)
    y = [smooth_transition_regular(xi, start, end, blur) for xi in x]
    
    plt.figure(figsize=(10, 10))
    plt.plot(x, y, 'b-', label='Transition function')
    
    t_points = [
        start - blur/2,
        start + blur/2,
        end - blur/2,
        end + blur/2
    ]
    t_values = [smooth_transition_regular(t, start, end, blur) for t in t_points]
    plt.plot(t_points, t_values, 'ro', label='Transition points')
    
    plt.grid(True)
    plt.axis('equal')
    plt.title(f'Smooth Transition (start={start}, end={end}, blur={blur})')
    plt.xlabel('x')
    plt.ylabel('y')
    plt.legend()
    plt.show()

# Test the function
plot_transition(-0.2, 1.3, 0.3)
plot_transition(-0.2, 1.3, 0.0)
