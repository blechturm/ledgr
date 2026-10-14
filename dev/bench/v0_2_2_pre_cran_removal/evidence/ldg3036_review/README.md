# LDG-3036 Review-Profile Record

The final ordinary review-profile run at `c566e433` executed 336 of 336
blocks with zero failures and one pre-existing optional-path skip in 274.06
seconds. The skip is the unavailable-package branch of the Yahoo adapter; the
installed `quantmod` package makes that negative branch inapplicable.

The run used R 4.6.1 and the declared local R 4.6 library. Setting
`R_PROFILE_USER` for the evidence process was necessary so its deliberately
fresh peer-benchmark children used DuckDB 1.5.6.9000 instead of an older
DuckDB 1.5.2 prepended by the user's normal interactive profile. The peer
boundary passed both in isolation and in this complete run.

An earlier invocation used the correct parent library but allowed the normal
user profile to shadow it in fresh children. It stopped with the package's
DuckDB version requirement and wrote no summary. It is an invalid environment
attempt, not a product failure or a passing review record.

`tools/check-release-test-profiles.R` accepts this summary together with the
committed 108.72-second LDG-3036 fast summary and prints
`LEDGR_RELEASE_TEST_PROFILES_OK profiles=fast,review`.
