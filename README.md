# Acoustic Tracking Turret

A sound-localizing system that detects the direction of a loud acoustic event, such as a hand clap, and rotates to face it in real time.

## Overview

The Acoustic Tracking Turret uses two spatially separated microphones to estimate the sound's direction of arrival (DOA) over a 180° forward field of view via time-difference-of-arrival (TDOA) analysis. All audio capture, event detection, and delay estimation are implemented on an FPGA for low-latency, deterministic processing, while a microcontroller controls the pan servo.

This project demonstrates practical acoustic localization techniques commonly used in robotics and embedded sensing systems.

## Key Features

- **Real-time acoustic localization** via TDOA-based direction estimation
- **FPGA-based signal processing** for deterministic, low-latency audio analysis
- **Two-microphone configuration** eliminating front–back ambiguity
- **180° forward field of view** for robust operation in indoor environments
- **Modular architecture** separating acoustic processing (FPGA) from mechanical control (microcontroller)

## System Architecture

The system consists of three main components:

1. **Acoustic Sensor Array**: Two microphones mounted at fixed positions on the turret base, continuously listening for acoustic events.
2. **FPGA Signal Processing**: Real-time digital signal processing pipeline for event detection and direction estimation.
3. **Mechanical Turret**: Pan-only servo-driven turret that rotates to face detected sound sources.

### Microphone Configuration and Geometry

The acoustic sensor consists of two microphones mounted in a straight line, separated by a known distance and centered on the turret's pan axis. The array is oriented horizontally and is symmetric about the forward-facing direction of the turret.

By restricting localization to a 180° forward-facing region, the system avoids front–back ambiguity while maintaining a simple and robust geometry. Only azimuth (left–right direction) is estimated, assuming the sound source lies in the forward half-plane.

## How It Works

### FPGA Signal Processing Pipeline

**Continuous Sampling**
- Both microphone signals are digitized and streamed into the FPGA at a fixed audio sampling rate.

**Event Detection**
- The FPGA monitors the short-term signal energy to detect loud transient events such as claps. When the energy exceeds a predefined threshold, a localization event is triggered.

**Buffered Audio Capture**
- Upon detection, a short synchronized buffer of audio samples from both microphones is stored in on-chip memory.

**TDOA Estimation via Cross-Correlation**
- The FPGA computes the cross-correlation between the two microphone signals over a bounded range of time lags corresponding to physically possible delays.
- The lag that maximizes the correlation represents the time difference of arrival (Δt) of the sound between the microphones.
- Implementing cross-correlation and peak detection directly in hardware enables deterministic timing and low latency.

**Direction Estimation**
- The estimated time delay is mapped to an azimuth angle using a geometric model of sound propagation in air.
- The FPGA outputs a quantized angle estimate to the control processor.

### Turret Control

A microcontroller receives the direction estimate from the FPGA and drives a pan servo mounted at the base of the turret. A simple proportional control loop rotates the turret until its heading aligns with the estimated sound direction. Visual indicators such as LEDs can be used to show detection and lock-on status.

Separating acoustic signal processing (FPGA) from mechanical control (microcontroller) results in a modular design that is easy to extend and debug.

## Project Structure

```
.
├── CAD/                          # Mechanical design files
│   ├── nerfgun-pivot-holder-plate.SLDPRT
│   ├── nerfgun-servo-holder-plate.SLDPRT
│   └── spacer.SLDPRT
├── firmware/                     # Microcontroller code
│   └── servo_control/
│       └── servo_control.ino
├── rtl/                          # FPGA HDL (Verilog)
│   ├── 7SegmentDisplay.sv
│   ├── SSegDisplayDriver.sv
│   ├── chipInterface.sv
│   ├── constraints.xdc
│   ├── display.sv
│   ├── i2s.sv                    # I2S audio interface
│   ├── lut.coe                   # Look-up table data
│   ├── tdoa.sv                   # TDOA computation core
│   ├── uart.sv                   # UART communication
│   ├── utils.sv
│   └── test/                     # RTL testbenches
│       ├── buffer_test.sv
│       ├── display_test.sv
│       ├── i2s_test.sv
│       └── uart_test.sv
└── sim/                          # Python simulation scripts
    └── sim.py
```

## Design Tradeoffs

- **Two microphones** instead of a larger array reduces hardware complexity and development time while still demonstrating core principles of acoustic localization.
- **180° restriction** eliminates front–back ambiguity and allows the system to operate reliably in noisy indoor environments.
- **FPGA-based processing** provides deterministic behavior and low latency, critical for responsive turret control.
- **Pan-only turret** simplifies mechanical design while focusing on the acoustic localization problem.

## Applications and Extensions

This project demonstrates foundational techniques used in robotics, smart devices, and interactive systems that respond to sound direction.

**Possible Extensions:**
- Add a third microphone for redundancy
- Implement frequency-domain correlation (GCC-PHAT) for improved robustness
- Extend the system to estimate elevation with a second microphone pair
- Add machine learning for sound classification
- Integrate additional sensors (e.g., vision) for multi-modal localization
