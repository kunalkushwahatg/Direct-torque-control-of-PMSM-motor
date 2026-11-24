# Experiment 02 results in simple words

*(Read `plain_language_overview.md` first for what the experiment is. Numbers come from `results/metrics_summary.csv`; pictures are in `figures/`.)*

## The one-sentence answer
**When the controller is told the wrong electrical resistance, both controllers can lose control completely, and they fail in almost exactly the same places.** The smoother controller (SVM-DTC) is not more fragile than the classical one, but it is not safer either. The weak point is the part they share: the "fuel gauge" that calculates the motor's magnetic strength (flux).

## What happened, test by test

**With the correct resistance (the normal case)** both controllers worked at every speed, including the very slow 2 rad/s and the reversal from +5 to -5 rad/s. The smooth controller was about 10 times smoother in torque (for example 0.033 vs 0.443 N·m of wobble at 2 rad/s). *This confirms Experiment 01 also holds at low speed.*

**With the controller believing the resistance is 30% too high (130%)**: both controllers **lost control in every test**, even at the medium speed of 20 rad/s. The calculated flux "ran away" to values like 16 to 24 (the correct value is 0.175), the real flux in the motor rose to about three times its normal value, and the speed swung wildly or stalled. Picture a driver who thinks the car is lighter than it is, keeps adding more throttle to compensate, and ends up much faster than intended: the correction makes the problem worse instead of better.

**With the controller believing the resistance is 30% too low (70%)**:
- At 20 rad/s both controllers kept control, but the real flux settled at 0.147 instead of 0.175 (about 16% too low) while the controller still *believed* it was 0.175. It is wrong and does not know it.
- At 5 and 2 rad/s (slow) both controllers **lost control**: the speed could not be held (the error was around 12 to 13 rad/s).

**The reversal from +5 to -5 rad/s** (with the correct resistance) was fine for both controllers, with no loss of flux while passing through standstill.

## A scoreboard (green = kept control, red = lost it)
See `figures/fig05_control_kept_map.png`. Of the 9 cases per controller, **both controllers fail in the same 5** (all three 130% cases and the two slow 70% cases) and pass the same 4 (the three correct-resistance cases and the 70% case at medium speed). In short: failures come from the resistance error, not from the choice of controller.

## What this means for the research
1. The **smooth controller's advantage** (low torque ripple) only holds while the resistance is known accurately.
2. A 30% resistance error is realistic (copper resistance changes by about 40% between a cold and a hot motor), so this weakness would matter in a real machine.
3. Because **both** controllers fail the same way, the problem is not in the part we changed (the modulation) but in the **flux calculation**. This points to a clear research direction: *make the flux calculation tolerate a wrong resistance* (for example, by letting the controller correct its own resistance estimate while running).

## What we do not know yet
- **Where exactly it breaks.** We only tested 70% and 130%. The true limit could be 85% or 110%. A finer test (80% to 120%) would find it.
- **Why exactly the 130% case runs away.** Our explanation (the correction feeding on itself) is a reasonable idea but not yet proven by a separate test.
- **Other imperfections** (sensor offset, inverter dead time) have not been tested yet; they are planned as separate experiments.
- Only one motor and one load level were used.

## Suggested next steps
1. Run a finer resistance sweep (80%, 90%, 110%, 120%) to find the exact limit.
2. Search the literature for flux estimators that tolerate resistance errors, and check which ones are already published.
3. Choose one to build and test against the numbers in this experiment.
