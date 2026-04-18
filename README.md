# micropython-template
Template repository for MicroPython-based projects.

Use this template to easily create projects that rely on MicroPython. With the help of this template\
you can easily build, deploy and test your application with the included MicroPython toolchain.

This project relies on GNU Make, implementing various automations in the included Makefile to cross-compile,\
and upload your application to a device with mpremote. Check the below steps for more details.

Additionally, you can host your package in the repository itself with the help of ```package.json```, allowing\
you to install the package from GitHub with the mip package manager. Use the ```publish``` rule to cross-compile\
and host modules under the ```dist``` directory.

# Prerequisites

## Setup virtual environment
```bash
python3 -m venv venv
source venv/bin/activate
python3 -m pip install -r requirements.txt
```

# Build and run example application

## Run on unix port

```bash
make toolchain          # Setup mpy-cross and micropython
make build              # Cross-compile, create build artifacts
make test-unix          # Run functional tests on the unix port
```

## Deploy to a device

```bash
make toolchain          # Setup mpy-cross and micropython
make build              # Cross-compile, create build artifacts
make deploy             # Upload build artifacts to device using mpremote
make run-device         # Optional: Reset the device and connect through REPL
```
```deploy``` and ```run-device``` uses the DEVICE argument
set to ```u0``` (/dev/ttyUSB0) by default, passed to mpremote.

Override the DEVICE argument to select a different device, e.g.
```make DEVICE=a0 run-device``` for /dev/ttyACM0. Check mpremote --help
for additional shortcuts.

## Redeploy

When changing the source code, run the below rule for redeploying to the device.

```bash
make redeploy           # Will run the following rules: clean build clean-device deploy
```

## Unit tests, pylint, functional tests

```bash
make static-checkers    # Run static checkers (Pylint, black formatter)
make unit-test          # Run unit tests
make test-unix          # Run functional tests on the unix port
```
