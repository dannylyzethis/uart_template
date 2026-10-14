# Run after compile_all.do; reusable from the complete regression.
foreach frequency {100000 400000} {
    foreach stretch {false true} {
        vsim -gSTRETCH=$stretch -gI2C_HZ=$frequency work.i2c_master_tb
        set BreakOnAssertion 2
        onbreak {quit -force -code 1}
        run 10 ms
        if {![string equal -nocase [examine /i2c_master_tb/test_completed] true]} {quit -force -code 1}
        echo "PASS: I2C frequency=$frequency stretch=$stretch"
        quit -sim
    }
}
