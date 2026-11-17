# Unregistered probe workloads (scratch; not part of the gate): inputs the
# registered workloads do not reach, run through the committed parity
# machinery by probe_runner.R.
probe_slice4 <- list(
  # A lifetime end effective before the first pulse: disposed on pulse 1.
  p_terminal_first = function() s4_run("p_terminal_first", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_life("A", 1L)),
    s4_exp(s4_strategy(s4_plan(list(2L, c(B = 3)))), positions = c(A = 10, B = 10), cost_basis = c(A = 10, B = 20))),
  # The same under held_terminal_position = "refuse": stopped on pulse 1.
  p_stop_first = function() s4_run("p_stop_first", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_life("A", 1L)),
    s4_exp(s4_strategy(list()), positions = c(A = 10, B = 10), cost_basis = c(A = 10, B = 20),
      corporate_action_policy = s4_policy(held_terminal_position = "refuse"))),
  # A cash acquisition entitled and effective on pulse 1 (the run-start bind).
  p_acq_first = function() s4_run("p_acq_first", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_ca(s4_acq("a1", "cash_acquisition", "A", 1L, cash = 12))),
    s4_exp(s4_strategy(s4_plan(list(3L, c(C = 2)))), positions = c(A = 10), cost_basis = c(A = 10))),
  # Many facts on one pulse (day 4): a membership change, a halt, a
  # lifetime end, a dividend and two acquisitions, beside fills.
  p_many_facts = function() s4_run("p_many_facts", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B", "C", "D", "E"), "4" = c("B", "C", "E"))),
      ledgr::ledgr_facts_trading_status(rbind(s4_trading("A", "active", 1L), s4_trading("B", "active", 1L),
        s4_trading("C", "active", 1L, 4L), s4_trading("C", "halted", 4L), s4_trading("D", "active", 1L),
        s4_trading("E", "active", 1L))),
      s4_life("D", 4L, "merged"),
      s4_ca(s4_acq("d1", "ordinary_cash_dividend", "B", 4L, cash = 0.5, effective = 5L),
        s4_acq("a1", "cash_acquisition", "A", 4L, cash = 12), s4_acq("a2", "stock_acquisition", "E", 4L, recipient = "B",
          ratio = 0.5))),
    s4_members_exp(s4_strategy(s4_plan(list(3L, c(B = 6, E = 4)), list(4L, c(B = 8)), list(6L, c(E = 2)))),
      positions = c(A = 10, B = 4, C = 5, D = 6, E = 2), cost_basis = c(A = 10, B = 20, C = 30, D = 40, E = 50))),
  # An empty context on the first pulses, members from day 3.
  p_empty_first = function() s4_run("p_empty_first", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = character(), "3" = c("B", "D")))),
    s4_members_exp(s4_state_strategy, portfolio_state = list(n = 0L), asset_state = list(cnt = 0))),
  # A one-worker sweep over a membership universe with a lifetime end.
  p_sweep_terminal = function() s4_ca_sweep("p_sweep_terminal", s4_facts_closes(),
    ledgr::ledgr_facts(s4_sessions(10L), s4_universe(list("1" = c("A", "B", "C"), "5" = c("B", "C"))), s4_life("A", 6L)),
    s4_members_exp(s4_strategy(s4_plan(list(2L, c(A = 3, B = 2)))))
  )
)
