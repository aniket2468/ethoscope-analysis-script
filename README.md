# Ethoscope sleep analysis

Automated pipeline for Ethoscope sleep deprivation experiments: extract raw data, bin sleep, plot paired actograms (focal vs yoked), and summarise daily sleep.

## Quick start

| Step | What you do | Command (from project root) |
|------|-------------|----------------------------|
| **1** | Add `.db` data to `ethoscope_data/` (see below) | — |
| **2** | Run the pipeline | `Rscript run_ethoscope_analysis.r` |
| **3** | Open outputs in `analysis_output/` (actogram PDF + sleep summary) | — |

That is the full workflow for most experiments. Stage 2 below is **optional** — only if you reviewed the actogram and need to drop bad pairs (dead fly, poor yoking, artefact).

### Optional — exclude bad pairs and replot

| Step | What you do | Command (from project root) |
|------|-------------|----------------------------|
| **1** | Note bad pair numbers from the actogram PDF | — |
| **2** | Edit `analysis_scripts/exclude_pairs.r` | — |
| **3** | Re-run plot + summary with exclusions | `Rscript run_ethoscope_analysis_stage2.r` |

**Windows:** use `Rscript.exe` instead of `Rscript`.

Always run commands from the **project root** — the folder that contains `run_ethoscope_analysis.r`, `ethoscope_data/`, and `analysis_output/`.

---

## Project folder layout

```
Ethoscope/                          ← open terminal HERE
├── run_ethoscope_analysis.r        ← Stage 1: run this first
├── run_ethoscope_analysis_stage2.r ← Stage 2: run after editing exclude_pairs.r
├── README.md
│
├── ethoscope_data/                 ← INPUT: raw Ethoscope .db files
│   └── results/
│       └── ...
│
├── analysis_output/                ← OUTPUT: plots and tables appear here
│   ├── Paired_Actogram_....pdf
│   ├── daily_sleep_summary_....txt
│   └── Sleep_EthXXX_Focal.txt  ...
│
└── analysis_scripts/               ← pipeline code (usually no need to open)
    ├── exclude_pairs.r             ← EDIT THIS for Stage 2
    └── ...
```

---

## Input data: `ethoscope_data/` structure

Copy your Ethoscope result folders into `ethoscope_data/results/`. The pipeline expects the **standard Ethoscope folder layout** produced when you download or sync results from the machine:

```
ethoscope_data/
└── results/
    └── <device-uuid>/                    ← unique ID for each Ethoscope unit
        └── ETHOSCOPE_XXX/                ← device name (e.g. ETHOSCOPE_007)
            └── <session-datetime>/       ← one recording session
                └── <session>_<uuid>.db   ← SQLite database (required)
```

### Example (four ethoscopes)

```
ethoscope_data/
└── results/
    ├── 007de0cc18864faf8b57d0b48667f276/
    │   └── ETHOSCOPE_007/
    │       └── 2026-05-19_18-39-32/
    │           └── 2026-05-19_18-39-32_007de0cc18864faf8b57d0b48667f276.db
    ├── 009296ca151e496f960017fd28d763b3/
    │   └── ETHOSCOPE_009/
    │       └── 2026-05-19_18-44-30/
    │           └── 2026-05-19_18-44-30_009296ca151e496f960017fd28d763b3.db
    └── ... (one folder per ethoscope)
```

**Tips**

- Copy the whole `results` folder from your Ethoscope PC, or merge multiple devices under `ethoscope_data/results/`.
- Each `.db` file must sit **four levels deep**: `results / uuid / ETHOSCOPE_XXX / session / file.db`.
- The pipeline auto-detects all `.db` files under `ethoscope_data/results/`.
- In plots and output files, ethoscopes appear as **Eth007**, **Eth009**, etc. (from `ETHOSCOPE_007`, `ETHOSCOPE_009`, …).

---

## Requirements

- [R](https://cran.r-project.org/) (4.0+ recommended)
- R packages install automatically on first run: `scopr`, `sleepr`, `data.table`, `ggplot2`, `RSQLite`, `stringr`

---

## Stage 1 — full pipeline

```bash
cd /path/to/Ethoscope          # project root
Rscript run_ethoscope_analysis.r
```

### Prompts

**1. Crop to 24h before sleep deprivation? (y/N)**

| Answer | Meaning |
|--------|---------|
| `n` or Enter | Keep the **full recording** (outputs tagged `_uncropped`) |
| `y` | Keep only **24 h before sleep deprivation** |

**2. Sleep bin size — enter 1, 2, or 3**

| Choice | Bin size | Use when |
|--------|----------|----------|
| `1` | 5 min | High-resolution actograms |
| `2` | 30 min | Medium resolution |
| `3` or Enter | 60 min | Default overview |

The pipeline runs automatically (several minutes for large experiments).

### Where to find Stage 1 outputs

Open the **`analysis_output/`** folder at the project root.

| File | What it is |
|------|------------|
| `Paired_Actogram_uncropped_<date>_<N>min.pdf` | **Open this first** — paired actogram (focal = solid red, yoked = dashed blue) |
| `daily_sleep_summary_uncropped_<date>_<N>min.txt` | Mean sleep per day (baseline, SD, recovery) |
| `Sleep_Eth007_Focal.txt`, `Sleep_Eth007_Yoked.txt`, … | Per-ethoscope sleep data |
| `all_ethoscopes_merged.txt` | Merged raw extract |

Each row in the PDF is labelled **`Eth007 Pair 1`**, **`Eth007 Pair 2`**, etc. Write down any pair numbers that look bad (dead fly, poor yoking, artefact).

---

## Stage 2 — exclude bad pairs and replot

Do this **after** Stage 1, once you have reviewed the actogram PDF.

### Step-by-step

**1. Stay in the project root** (same folder as Stage 1).

**2. Open the config file** in any text editor:

```
analysis_scripts/exclude_pairs.r
```

**3. Add ethoscopes and pair numbers to remove.** Only list pairs you want to drop; all others stay included.

```r
EXCLUDE_PAIRS <- list(
  Eth007 = c(2, 4),   # remove pair 2 and 4 on Eth007
  Eth009 = c(1)       # remove pair 1 on Eth009
)
```

Use the **same names** as on the actogram (`Eth007`, not `ETHOSCOPE_007`).

**Pair reference** (tube numbers on the Ethoscope):

| Pair | Focal tube | Yoked tube |
|------|------------|------------|
| 1 | T1 | T12 |
| 2 | T3 | T14 |
| 3 | T5 | T16 |
| 4 | T7 | T18 |
| 5 | T9 | T20 |

**4. Save the file**, then run Stage 2 from the **project root**:

```bash
Rscript run_ethoscope_analysis_stage2.r
```

Answer the **same two prompts** (crop and bin size) as in Stage 1 — use the same choices unless you deliberately want a different resolution.

**5. Find filtered outputs** in `analysis_output/`:

| File | Description |
|------|-------------|
| `Paired_Actogram_uncropped_filtered_<date>_<N>min.pdf` | Actogram with bad pairs removed |
| `daily_sleep_summary_uncropped_filtered_<date>_<N>min.txt` | Summary with bad pairs removed |

Stage 1 files are **not** overwritten. You can edit `exclude_pairs.r` and run Stage 2 again as many times as needed.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `Run from the project root` | `cd` to the folder containing `run_ethoscope_analysis.r` |
| `No .db files` | Check folder depth under `ethoscope_data/results/` (see structure above) |
| Stage 2 says no exclusions | Edit `analysis_scripts/exclude_pairs.r` — `EXCLUDE_PAIRS` must not be empty `list()` |
| Prompts don't wait for input | Use a real terminal (Terminal on Mac, cmd/PowerShell on Windows) |
| Missing R packages | `Rscript analysis_scripts/install_dependencies.r` |

---

## Pipeline steps (reference)

| Step | Script | Stage |
|------|--------|-------|
| Extract `.db` files | `extract_ethoscope_data.r` | 1 |
| 10-second bins | `ethoscope_10sec_bins.r` | 1 |
| Focal/yoked sleep files | `create_sleep_files.r` | 1 (and 2 if bin size changes) |
| Actogram PDF | `plot_wavy_actogram.r` | 1 & 2 |
| Daily sleep summary | `daily_sleep_summary.r` | 1 & 2 |

All scripts live in `analysis_scripts/` — you normally only run the two entry points at the project root.
