# BV300 Benchmark Reference

The canonical BV300 lifecycle benchmark dataset supplied for this project is stored locally at:

`assets/bv300_lifecycle_benchmarks.json`

It is used by `BV300BenchmarkRepository` and the Standards Calendar to map a flock's start date to its age/day/week and display the corresponding benchmark values.

The dataset contains 72 weekly performance rows, vaccination schedule data, environmental correction data, and diagnostic/management thresholds.

Do not replace or invent benchmark values in application code when the supplied JSON contains the applicable value. Update this JSON when the canonical benchmark source changes.
