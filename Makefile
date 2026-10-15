# Makefile for UART Register Interface Project
# Provides convenient commands for simulation and testing

.PHONY: help compile sim-basic sim-system sim-regression synth check-cdc test-host clean test-python install-python

# Default target
help:
	@echo "=================================================="
	@echo "  UART Register Interface - Make Targets"
	@echo "=================================================="
	@echo ""
	@echo "Simulation targets:"
	@echo "  make compile      - Compile all VHDL sources"
	@echo "  make sim-basic    - Run basic testbench"
	@echo "  make sim-system   - Run comprehensive system test"
	@echo "  make sim-regression - Run all protocol, peripheral and MAX 10 tests"
	@echo "  make synth        - Compile and fit the provisional MAX 10 target"
	@echo "  make test-host    - Run offline Python packet tests"
	@echo "  make sim-gui      - Launch ModelSim GUI"
	@echo ""
	@echo "Python targets:"
	@echo "  make install-python - Install Python dependencies"
	@echo "  make test-python    - Run Python examples (requires hardware)"
	@echo ""
	@echo "Utility targets:"
	@echo "  make clean        - Clean simulation files"
	@echo "  make doc          - Generate documentation"
	@echo "  make help         - Show this help message"
	@echo ""

# Compile all VHDL sources
compile:
	@echo "Compiling VHDL sources..."
	cd simulation && vsim -c -do "do compile_all.do; quit"
	@echo "Compilation complete!"

# Run basic testbench
sim-basic: compile
	@echo "Running basic testbench..."
	cd simulation && vsim -c -do "do run_basic_test.do; quit -f"

# Run comprehensive system testbench
sim-system: compile
	@echo "Running comprehensive system testbench..."
	cd simulation && vsim -c -do "do run_system_test.do; quit -f"

# Launch ModelSim GUI
sim-gui: compile
	@echo "Launching ModelSim GUI..."
	cd simulation && vsim -do "do compile_all.do"

# Install Python dependencies
install-python:
	@echo "Installing Python dependencies..."
	pip install -r python/requirements.txt
	@echo "Python dependencies installed!"

# Run Python test examples
test-python:
	@echo "Note: Ensure FPGA is connected and port is configured correctly"
	@echo "Running Python basic test..."
	python3 python/examples/basic_test.py --port /dev/ttyUSB0

# Clean generated files
clean:
	@echo "Cleaning simulation files..."
	rm -rf simulation/work
	rm -rf simulation/transcript
	rm -rf simulation/*.wlf
	rm -rf simulation/*.vstf
	rm -f simulation/vsim.wlf
	@echo "Clean complete!"

# Generate documentation
doc:
	@echo "Documentation is available in:"
	@echo "  docs/UART_Register_Interface_Specification.md"
	@echo "  readme.md"

# Run protocol, peripheral and MAX 10 integration simulations with assertion/completion checks
sim-regression:
	cd simulation && vsim -c -do "do run_regression.do"

test-host:
	python -B -m unittest discover -s python -p "test_*.py" -v

# Provisional MAX 10 fit; board pins/timing must be confirmed before programming.
synth:
	cd quartus && quartus_sh --flow compile uart_max10_top

# Run after fitting; checks endpoint names and timed synchronizer stages.
check-cdc:
	cd quartus && quartus_sta -t check_cdc.tcl

.DEFAULT_GOAL := help
