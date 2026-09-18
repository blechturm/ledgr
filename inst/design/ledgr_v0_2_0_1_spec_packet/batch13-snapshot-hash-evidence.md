# Batch 13 Snapshot-Hash Timestamp Deduplication Evidence

Status: implementation evidence pending independent Stage N review.

- Source base: `f3b6e2a87a4b075bb0b5f92f55149b40536ac2e4` plus the uncommitted Batch 13 candidate.
- Environment: R 4.6.1; ledgr 0.2.0.1; duckdb 1.5.2; collapse 2.1.8.
- Fixture: 500 instruments by 1,260 daily bars, 630,000 rows; default 10,000-row fetch chunks.
- Frozen fixture hash: `ed05aa170e93af7e2f229f9d920882faad844e91b03397b1293a0722fcac7bb5`.
- Clock: complete `ledgr_snapshot_hash()` only; fixture creation and opening are outside the clock.
- Peak working set: external Windows process sampling every 200 ms; runs were serial with no intentional concurrent benchmark workload.
- Method: `within_chunk_distinct_timestamp_v001`.

An initial provisional pass used the Stage M `PEER_` instrument prefix. Source
review caught that its hash did not match the frozen Stage L fixture, so those
files were replaced. The runner now refuses a fixture whose stored hash is not
the frozen `ed05aa17...c7bb5` value, and the complete eight-run protocol was
repeated. Only that corrected repetition is reported below.

## A. Decision And Scope

Only timestamp-token construction inside each existing fetched hash chunk changes. Query order, chunking, numeric tokens, separators,
hash blocks, rule versions, availability payloads, stored hashes, and verification remain unchanged. No cross-chunk cache exists.

## B. Eligibility

OPT-L01 remains in the exact-parity lane: any byte or hash difference removes it rather than changing a version or expected hash.

## C. Baseline Attribution

The current arm formatted 630000 timestamp inputs. Its measured median complete hash wall was 7.62 seconds.

## D. Semantic Matrix

Focused tests compare tokens and emitted bytes for repeated and unique timestamps at row counts below, at, and above chunk sizes 1, 2, 17,
9,999, 10,000, 10,001, and 50,000. Full hashes cover rules 1 and 2, missing volume, every canonical bar field, and every registered size.

## E. Identity And Persistence

All measured and stored hashes are identical. A snapshot sealed through the retained old formatter reopens and verifies under production.
Timestamp, price, and stored-hash mutations still fail, including the public run guard. Hash algorithm and rule versions are unchanged.

## F. Numerical Comparison

No numerical tolerance is used. Byte and hash identity are absolute.

## G. Structural Regression Gate

The candidate formatted 79380 inputs (ratio 0.126000; ceiling 0.20). A no-dedup mutant retained the hash but formatted all 630000 rows and failed.

## H. Performance Result

Complete hash median: 7.62 seconds current, 5.21 seconds candidate; ratio 0.6837 (ceiling 0.80).
Maximum peak working set: 423.0 MiB current, 421.8 MiB candidate; ratio 0.9972 (ceiling 1.15).
Gate disposition: `PASS`.

## I. Verification

The focused identity, boundary, rule, reopen, run-guard, tamper, source, and deliberate-mutant tests pass. This is Stage N evidence, not final
Stage O evidence.

## J. Independent Review

LDG-2743 remains review-pending. The reviewer must reconcile the raw CSVs, rerun focused gates, gut deduplication, and confirm containment.
