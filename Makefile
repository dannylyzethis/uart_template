# Makefile for UART Register Interface Project
# Provides convenient commands for simulation and testing

.PHONY: help compile sim-basic sim-system clean test-python install-python

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

# Synthesis (placeholder - requires Vivado/Quartus)
synth:
	@echo "Synthesis must be run in Vivado or Quartus."
	@echo "Load the project and use constraints/uart_register_interface.xdc"

.DEFAULT_GOAL := help
