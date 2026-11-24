# Experiment 03 explained in simple words

*(Follow-up to Experiment 02. Read `../exp02_robustness/plain_language_overview.md` first if you have not.)*

## The question
In Experiment 02 we told the controller that the motor's wire resistance was 30% wrong and it failed. That is a big mistake to test. **How small does the mistake have to be before the controller is safe again?** If a 5% error is already harmful, the controller is far more fragile than it first looked.

## What we did
Same idea as before: the controller uses a "fuel gauge" (the flux calculation) that depends on the resistance. We told it the resistance was 80%, 90%, 105%, 110% or 120% of the real value (in addition to the 70%, 100% and 130% already tested), at two speeds: a medium speed (20 rad/s) and a very slow one (5 rad/s). Both controllers were tested, 20 new simulations.

## Why do the small steps near 100% matter?
Our explanation from the last experiment predicted that **believing the resistance is too high is dangerous even by a little**, because the calculation then feeds on its own error. Believing it is too low should be much milder. This experiment tests that prediction.

## Read the results as a map
- **Believing the resistance is too low (80 to 90%) at medium speed:** the controller still works, but the real magnetic strength is a bit lower than it believes (0.168 and 0.160 instead of 0.175).
- **Believing it is too high by only 5%:** control is lost, even at medium speed.
- **Slow speed (5 rad/s):** control is lost for every error we tried, even 10% too low or 5% too high. The slower the motor turns, the less room for error.

Both controllers behave almost identically, down to a few thousandths of a second.
