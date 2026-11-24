# Model screenshots

These are top-level screenshots of the canonical Simulink models used in the experiments.
They show the complete model, not a subsystem or a cropped view. Readability copies
(`*_clean.slx`) are not included; unused intermediate wrappers were removed.

Note: exp02 and exp03 reuse the same drive model; only the test matrix differs, so
their model screenshots are intentionally identical.

| Experiment | Model | Screenshot |
|---|---|---|
| exp01 | Classical DTC | <img src="exp01_classic_dtc_final.png" width="420" alt="Classical DTC model"> |
| exp01 | SVM-DTC | <img src="exp01_svm_dtc_final.png" width="420" alt="SVM-DTC model"> |
| exp02 | Classical DTC, Rs robustness | <img src="exp02_classic_dtc_rob.png" width="420" alt="Classical DTC robustness model"> |
| exp02 | SVM-DTC, Rs robustness | <img src="exp02_svm_dtc_rob.png" width="420" alt="SVM-DTC robustness model"> |
| exp03 | Classical DTC, Rs boundary | <img src="exp03_classic_dtc_rs.png" width="420" alt="Classical DTC Rs boundary model"> |
| exp03 | SVM-DTC, Rs boundary | <img src="exp03_svm_dtc_rs.png" width="420" alt="SVM-DTC Rs boundary model"> |
| exp05 | Classical DTC winder | <img src="exp05_classic_winder.png" width="420" alt="Classical DTC winder model"> |
| exp05 | SVM-DTC winder | <img src="exp05_svm_winder.png" width="420" alt="SVM-DTC winder model"> |
| exp05 | Winder plant only | <img src="exp05_winder_plant.png" width="420" alt="Winder plant model"> |

## What you are looking at

- **exp01–exp03**: the PMSM, inverter, sensors, flux estimator, DTC or SVM-DTC
  controller, speed loop, load, and logging blocks.
- **exp05**: the same drive plus the winder/unwinder plant, tension loop,
  line-speed reference, feedforward, and logging.
- **exp05_winder_plant**: the standalone mechanical plant used for validation.

## Regenerate them

From the repository root in MATLAB:

```matlab
addpath('tools')
export_model_screenshots
```

Outputs are written to `docs/screenshots/`.
