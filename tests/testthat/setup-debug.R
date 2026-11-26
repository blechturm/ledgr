# Cut 24 decision 6 (LDG-3262): the suite runs with ledgr's internal debug
# flag on, so every admitted feature cell is also computed by the general
# path and compared. testthat sources setup files inside eval(), whose exit
# would restore the flag at once; the setter is given testthat's teardown
# environment, which is no function frame, so the flag stays on until the
# test process ends. The value it replaced is kept for the witness in
# test-debug-flag.R.
ledgr_test_debug_prior <- ledgr:::local_ledgr_debug(TRUE, frame = testthat::teardown_env())
