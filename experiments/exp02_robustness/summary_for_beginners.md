# Experiment 02 explained in simple words

*(Written so that a student without an electrical background can follow it. Technical details are in `README.md`.)*

## 1. The big picture
We are studying an **electric motor** that is controlled by a small computer program (the **controller**). The controller decides, thousands of times per second, how much voltage to send to the motor so that the motor produces exactly the **turning force (torque)** we ask for.

We built two different controllers and compared them in Experiment 01:
- **Classical DTC**: like a thermostat. It only has "on" or "off" choices, so the torque keeps wobbling up and down.
- **SVM-DTC** (the one we are improving): like a smooth dimmer. It chooses the exact voltage needed, so the torque is much smoother.

In Experiment 01 everything was *perfect*: every number the controller used was exactly right. Real life is never perfect. **Experiment 02 asks: what happens when something is a little bit wrong?** A good controller should keep working. A fragile one will fail.

## 2. The key idea: the controller cannot see inside the motor
The motor has an invisible quantity called **flux** (think of it as the "magnetic strength" inside the motor). The controller needs to know the flux, but there is no sensor for it. So the controller **calculates** it, like a fuel gauge that works by adding up how much fuel went in and how much was used, instead of looking at the tank.

To do that calculation it needs to know the motor's **electrical resistance** (how much the copper wire "resists" the current). If the resistance it assumes is wrong, the calculation slowly goes wrong, like a fuel gauge with a small counting error that grows over time.

## 3. What we test (one thing at a time)
| Test | In everyday words | What we change |
|---|---|---|
| **Resistance error** | The controller uses a *wrong ruler* | The controller thinks the resistance is 70%, 100% or 130% of the real value (the motor itself is unchanged) |
| **Low speed** | Small signals are hard to notice | The motor turns very slowly (2 and 5 radians per second, which is under one turn per second) |
| **Speed reversal** | Changing direction | The motor runs forward and then is told to run backward, passing through standstill |

**Why low speed is the hard case:** at low speed the voltages are tiny, so a small error in the resistance is large *compared to* the signal. The "fuel gauge" error is then bigger than the thing it is trying to measure.

## 4. How we test
Each test is a computer simulation (no real motor is harmed). We run the same test on both controllers, with the same load on the motor (a constant resisting torque, like the motor lifting a weight). The tests that are run are:
1. **Medium speed (20 rad/s)** with the wrong resistance (3 cases).
2. **Low speed (5 and 2 rad/s)** with the wrong resistance (6 cases).
3. **Reversal** from +5 to -5 rad/s (1 case).

Each is done for both controllers, so 20 simulations in total.

## 5. What we measure (and what it means)
- **Did it keep control?** A yes/no flag. "Lost control" means the motor ran away or the flux collapsed.
- **Flux error:** how far the controller's calculated magnetic strength is from the real one. (The simulation can see the real one; the controller cannot.)
- **Torque wobble (ripple):** how smooth the turning force is. Lower is better.
- **Speed error:** how far the motor speed is from the requested speed.

## 6. What we already learned while setting it up
When we told the SVM-DTC controller that the resistance was 30% too high, at 5 radians per second, **it lost control completely**: the calculated flux grew to 6.9 (the correct value is 0.175) and the motor speed swung to 200 rad/s in both directions. With the correct resistance, the same test was fine. So this controller is **fragile to resistance errors at low speed**. This is exactly the kind of weakness that a research project can try to fix.

## 7. Why this matters for the research
A paper that only shows "my controller is smooth in perfect conditions" is not convincing. A paper that shows **where the controller breaks and how to fix it** is a real contribution. This experiment finds the breaking points; the next step is to pick one of them and design a fix.

## 8. Results
See `results_in_simple_words.md` for what happened. In one line: both controllers lose control when the assumed resistance is 30% too high, and the slow cases fail even at 30% too low.
