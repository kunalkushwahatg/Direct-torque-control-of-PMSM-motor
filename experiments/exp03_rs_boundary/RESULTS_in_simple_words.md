# Experiment 03 results in simple words

## The one-sentence answer
**The controller has almost no safety margin: at medium speed it fails if the assumed resistance is only 5% too high, and at very slow speed it fails for every error we tried (even 10% too low).** The smooth controller (SVM-DTC) and the classical one fail at nearly the same moment, so the weakness belongs to the flux calculation, not to the controller type.

## The map (what happened at each assumed resistance)
| Controller believes resistance is... | Medium speed (20 rad/s) | Very slow (5 rad/s) |
|---|---|---|
| 70% to 90% (too low) | works, flux 15% to 4% too low | **fails** |
| 100% (correct) | works | works |
| 105% to 130% (too high) | **fails** | **fails** |

(A "fail" means the motor speed is no longer held, and the real magnetic strength is far from what the controller thinks.)

## What this tells us
1. **Too high is the dangerous direction.** Even 5% too high fails. This matches our prediction: with a too-high resistance, the calculation errors grow on their own.
2. **Too low is milder, but only at medium speed.** The controller survives but is quietly wrong (the real flux is lower than it believes). At very slow speed even this fails.
3. **The weakness is shared.** The two controllers' failure times differ by only a few thousandths of a second. So improving the modulation will not fix it; the flux calculation needs to be made tolerant.

## What we did NOT confirm
- Our simple formula for **how fast** the error grows is only partly right. The direction (too high is worse) matches, but the speeds of growth measured in the simulations do not match the formula closely. At +5% the error stayed bounded rather than exploding, yet the speed was still lost. So our explanation is incomplete.
- The exact boundary at slow speed is not found (even 10% too low already fails; the true limit could be a few percent).

## Why this is good news for the research
A real motor's resistance changes by tens of percent as it heats up, so a controller this sensitive cannot be used as it is. That is a **clear, measurable weakness** with a clear target for improvement: *make the flux calculation tolerate a wrong resistance*, and then show on this same test map that the improved controller stays green where these two fail.
