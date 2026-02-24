# WaTEM/SEDEM Pascal → Python Migration Plan

## What this document is

This is a handoff document for an AI-assisted migration of the WaTEM/SEDEM erosion model from Free Pascal to Python. It was produced by analyzing the source repository at https://github.com/watem-sedem/watem-sedem (cloned 2025-02-24) and the fork at https://github.com/JoernStoehler/watem-sedem. The intended workflow is: a human operator opens each phase with a Claude Code instance, discusses the plan, greenlights it, then reviews after ~1 hour of autonomous work.

## What WaTEM/SEDEM is

WaTEM/SEDEM is a spatially distributed soil erosion and sediment delivery model. It computes mean annual soil loss on a raster grid using an adapted RUSLE (Revised Universal Soil Loss Equation), routes sediment downhill using a flow algorithm on a DEM, and applies transport capacity limits to determine net erosion vs. deposition at each cell. It was originally developed at KU Leuven (Belgium) starting ~2000.

The model iterates over all grid cells in topologically-sorted order (high to low elevation). At each cell it compares available sediment (incoming + local erosion) against transport capacity. If available < capacity, everything passes through. If available > capacity, excess is deposited. This is the core algorithm — everything else is input preparation and optional extensions.

The code was originally written in Delphi, converted to Free Pascal in 2017 by Fluves (a Belgian consultancy), and has been maintained on GitHub since. The current version is 5.0.2. It is licensed LGPL-3.0. Any Python port is a derivative work and must use LGPL-3.0 or a compatible license.

## Branches and porting base

### Upstream repo (watem-sedem/watem-sedem)

Only has `master` branch plus 3 release tags (5.0.1, 5.0.2, 5.0.3). There were open PRs at time of analysis (could not enumerate due to API rate limit — check manually).

### Fork (JoernStoehler/watem-sedem)

Has 13 branches. The ones with meaningful code changes:

| Branch | vs master | What it does | Action needed |
|---|---|---|---|
| `calibration` | 3 ahead, 0 behind | Changes to `readinparameters.pas` (+5/-5 lines), doc restructuring around calibration parameters | **Cleanest branch.** Ahead of master with no conflicts. Candidate for porting base. |
| `grass_strip_field` | 1 ahead, 2 behind | Routing bugfix: only treat grass strip as parcel if source is a parcel, not e.g. a road | **Substantive routing fix.** Should be merged before porting. Routing is the most bug-prone area. |
| `remove_duplicate_set` | 1 ahead, 22 behind | Removes duplicate `SetRasterBorders` call (already called in `GetGFile`) | **Cleanup.** Merge before porting. |
| `Radar` | 6 ahead, 1560 behind | New rainfall rate interpolation | **Very stale.** Probably dead. Ignore unless instructed otherwise. |
| `iss_73` | 1 ahead, 256 behind | Docs: expand P-factor input info | **Stale docs change.** Ignore. |
| `negative_slopes` | unknown | (API rate limited before could check) | **Investigate in Phase 1.** Name suggests a bugfix that could be important. |
| `outside_modeldomain` | unknown | (API rate limited before could check) | **Investigate in Phase 1.** Name suggests boundary handling changes — relevant to porting. |
| `debian_package2`, `gh-pages`, `ghcr`, `github_remove_artifacts`, `report_version` | — | CI/packaging/docs | Not relevant to model logic. |

### Decision needed before porting starts

**Phase 1 must resolve this:** Determine the porting base by:
1. Check `negative_slopes` and `outside_modeldomain` branches — names suggest they contain bugfixes relevant to core model logic
2. Decide which branches to merge into a consolidated porting base
3. Create a `python-port-base` branch (or similar) from the merged result
4. Verify `make integration_test` passes on this merged branch before any Python work begins

**Epistemic status:** I could not fully analyze `negative_slopes` and `outside_modeldomain` due to GitHub API rate limiting. They could be trivial or they could contain important fixes. The branch names are suggestive — negative slopes in a DEM and outside-model-domain boundary handling are both areas where bugs would be subtle and impactful.

---

## The codebase

### Size and structure

Total Pascal: ~13,750 lines across all directories. But much of this is duplicated GUI code. The actual model logic lives in `common/` (~6,350 lines) plus the entry point `watem_sedem/watem_sedem.lpr` (~100 lines).

```
common/                          # shared model logic (THIS IS WHAT WE PORT)
├── rdata_cn.pas          417 lines  — raster data types, generic Traster<T>, file I/O for .rdc/.rst/.sgrd/.sdat
├── gdata_cn.pas          154 lines  — integer raster type (Graster = Traster<integer>), integer raster I/O
├── readinparameters.pas 1184 lines  — ini file parsing, ~80+ global variable declarations, input loading
├── raster_calculations.pas 1624 lines — slope, aspect, LS-factor, flow routing, upstream area, sediment flux (24 functions)
├── lateralredistribution.pas 907 lines — the main sediment redistribution sweep (5 functions)
├── cn_calculations.pas  1412 lines  — Curve Number extension for runoff/concentration (12 functions)
├── tillage.pas            89 lines  — tillage erosion calculation
├── write_raster.pas      235 lines  — raster output in various formats
├── write_output.pas      168 lines  — summary table output (Total sediment.txt etc.)
├── runmodel.pas          159 lines  — orchestrator: calls the above in the right order

watem_sedem/
├── watem_sedem.lpr       100 lines  — CLI entry point, reads ini path from args, calls runmodel

tests/
├── unit_tests_cnws.lpr    26 lines  — fpcunit test runner
├── test_sgrd.pas         157 lines  — ONLY existing unit test: tests SGRD file reading

testfiles/
├── molenbeek/                       — integration test dataset
│   ├── modelinput/                  — input rasters (.rdc/.rst) and ini file for scenario 1
│   ├── modelinput_sdat/             — same scenario in SAGA format
│   ├── modelinput_ref/              — reference input rasters written by model (slope, aspect)
│   ├── modelinput_ref_sdat/         — same in SAGA format
│   ├── modeloutput_ref/             — reference output rasters and summary tables
│   └── modeloutput_ref_sdat/        — same in SAGA format
├── test.sh                          — shell script that runs the binary on both input variants
├── test_compare_output.py           — pytest: compares outputs against reference
├── test_benchmark.py                — helper functions for raster/table comparison (uses rasterio, numpy, pandas)

watem_sedem_gui/                     # OLD GUI version — NOT IN SCOPE, ignore
watem_sedem_gui_LT/                  # ANOTHER old GUI version — NOT IN SCOPE, ignore
```

### Dependency graph of the common/ units

Based on `Uses` clauses (verified by reading the source):

```
RData_CN                    (no dependencies within common/)
  └─> GData_CN              (uses RData_CN)
       └─> ReadInParameters (uses GData_CN, RData_CN, + stdlib)
            ├─> raster_calculations  (uses GData_CN, RData_CN, ReadInParameters)
            ├─> lateralredistribution (uses GData_CN, RData_CN, ReadInParameters, raster_calculations)
            ├─> cn_calculations       (uses GData_CN, RData_CN, ReadInParameters, raster_calculations)
            ├─> tillage               (uses GData_CN, RData_CN, ReadInParameters, raster_calculations)
            ├─> write_raster          (uses RData_CN, ReadInParameters)
            ├─> write_output          (uses ReadInParameters)
            └─> runmodel              (uses most of the above)
```

Key implication: `RData_CN` → `GData_CN` → `ReadInParameters` is the critical path. Nothing else can be ported until these three are done. After that, `raster_calculations`, `cn_calculations`, `tillage`, `write_raster`, `write_output` can be ported in parallel. `lateralredistribution` depends on `raster_calculations`. `runmodel` depends on everything.

### Global mutable state

This is the single biggest architectural challenge. Pascal units declare global variables in their `Interface` section, which are then visible to all units that `Use` them. The model operates by mutating these globals.

`RData_CN` declares grid-level globals:
- `NROW, NCOL: integer` — grid dimensions
- `RES, MINX, MAXX, MINY, MAXY: double` — spatial extent
- `raster_projection: TRaster_Projection` — enum: plane or LATLONG
- Several bookkeeping arrays (`ncolAR, nrowAR, resAR, lengthAR`) for consistency checking across loaded rasters

`ReadInParameters` declares ~80+ globals including:
- All input rasters: `K_factor, C_factor, P_factor, ktc, ktil` (RUSLE factors), `DTM` (implicitly via loading)
- All output rasters: `WATEREROS, TILEROS, SEDI_EXPORT, SEDI_IN, SEDI_OUT, RUSLE, CAPAC, ...`
- All configuration booleans: `OnlyRouting, curve_number, Include_sewer, Topo, Inc_tillage, est_clay, Include_buffer, Include_ditch, Include_dam, Create_ktc, Create_ktil, Calc_tileros, Outlet_select, Convert_output, segments, adjusted_slope, buffer_reduce_upstream_area, force_routing, river_routing, river_topology`
- All file paths: `DTM_filename, PARCEL_filename, Rainfallfilename, ...`
- Numerical parameters: `Rone, Cfact, Rfactor, alpha, beta, bulk_density, ...`

**Decision: Port globals 1:1 first.** Create a Python module `state.py` or a dataclass that holds all of these. This is ugly but faithful. The alternative — refactoring into proper objects — requires understanding the data flow deeply and risks introducing bugs. We can always refactor later once the integration tests pass. The goal is correctness, not beauty.

### Raster types

The code defines a generic `Traster<T>` class in `RData_CN`:
- `r: array of array of T` — the actual 2D data, 1-indexed with border cells (row 0, col 0, row nrow+1, col ncol+1 are padding)
- Constructor allocates `(nrow+2) × (ncol+2)` — **this 1-indexing with borders is critical to get right in the port**
- `getItem(row, col)` / `setItem(row, col, value)` with `property item[row, col]` default accessor
- `CopyRasterBorders` / `SetRasterBorders` — fills border cells by copying nearest interior cell

Two concrete types:
- `RRaster = Traster<single>` — floating point rasters (single = 32-bit float)
- `GRaster = Traster<integer>` — integer rasters (land use categories, parcels, etc.)

**Python equivalent:** numpy arrays. But the 1-indexing and border padding need careful handling. Options:
1. Use 0-indexed numpy arrays with 1-cell padding on all sides (faithful but every index is offset by 1 from Pascal)
2. Use 0-indexed numpy arrays without padding, handle borders separately
3. Create a wrapper class that translates 1-based indexing

I'd recommend option 1 for faithfulness during initial port. Document the indexing convention prominently.

### Raster I/O formats

The code reads two format families:
- **Idrisi format** (.rdc header + .rst binary data): `ReadRDC()` parses a text header file, then reads binary data (byte, smallint, integer, or float) based on the header's datatype field. The .rdc file contains nrow, ncol, resolution, extent, data type, and a pointer to the .rst binary file.
- **SAGA format** (.sgrd header + .sdat binary data): `ReadSGRD()` parses SAGA's grid header format. Similar structure.

The code dispatches based on file extension. Both paths end up filling a `THeader` record, then reading binary data into the raster array.

**Python equivalent:** `rasterio` handles both formats and is already used by the existing test infrastructure (`test_benchmark.py` uses `rasterio.open()`). The existing `pywatemsedem` wrapper also uses rasterio. So this is solved — but we need to verify that rasterio reads the exact same values as the Pascal code, bit for bit. The integration test does this implicitly.

**Epistemic status:** I have read the I/O code but not tested it. There could be edge cases around endianness, nodata values, or the `toptobottom` flag that rasterio handles differently. The safest approach is to load a raster with both Pascal and Python and do a cell-by-cell comparison early in Phase 3.

### Algorithm complexity

The model is conceptually simple — no iterative solvers, no convergence criteria, no PDEs. It's a single forward pass:

1. Load inputs (DEM, land use, RUSLE factors, config)
2. Compute slope and aspect from DEM (finite differences on the grid)
3. Compute LS-factor (length-slope factor) using upstream contributing area
4. Compute RUSLE erosion: E = R × K × LS × C × P
5. Compute transport capacity: TC = ktc × potential_rill_erosion
6. Route sediment: iterate cells in topological order (high to low), compare available sediment vs. TC, distribute outgoing sediment to 1-2 downslope neighbors
7. Optionally: compute tillage erosion, handle buffers/sewers/ditches/dams, compute CN runoff
8. Write outputs

The routing algorithm (step 6) is the most complex part. It uses a flux decomposition scheme where each cell sends sediment to at most 2 neighbors, weighted by slope direction. The topological sort is implicit — cells are processed in order of their elevation from high to low.

**Epistemic status:** I've read the interface declarations and the documentation but not every line of the implementation. The routing algorithm in particular has had historical bugs (the CHANGELOG mentions several routing bugfixes across versions). The integration test is the primary correctness oracle.

### Existing test infrastructure

**Unit tests:** Minimal. Only `test_sgrd.pas` (157 lines) testing SGRD file reading. No unit tests for any computation functions.

**Integration tests:** Solid. The molenbeek test case:
1. `test.sh` runs the binary on two input variants (Idrisi and SAGA format)
2. `test_compare_output.py` (pytest) compares:
   - All output rasters against reference using `np.allclose()` with per-file tolerances ranging from `(rtol=1e-8, atol=1e-8)` for most files to `(rtol=1e-4, atol=1e-3)` for cumulative quantities like `WATEREROS (kg per gridcel)`
   - Summary tables via pandas `assert_frame_equal`
   - `Total sediment.txt` parsed and compared field by field
3. Also checks that input rasters written by the model (slope, aspect maps) match reference

**Test data:** The molenbeek directory uses Git LFS for the binary raster files. A shallow clone may not fetch them. Need `git lfs pull` or a full clone.

**What's missing for our purposes:** 
- No unit tests for individual computational functions
- No small/synthetic test case for fast iteration
- No Python entry point to the model (only the compiled Pascal binary)

---

## Phase 1: Understand and prepare porting base

### What to do

**Branch resolution (do this FIRST):**
- [ ] Examine branches `negative_slopes` and `outside_modeldomain` — read the diffs, understand what they change. Names suggest bugfixes to core model logic (slope calculation and boundary handling respectively). These could be critical.
- [ ] Examine `grass_strip_field` — confirmed routing bugfix (1 commit). Merge candidate.
- [ ] Examine `remove_duplicate_set` — confirmed cleanup, removes duplicate `SetRasterBorders` call. Merge candidate.
- [ ] Examine `calibration` — confirmed 3 commits: parameter renaming in `readinparameters.pas` (+5/-5 lines) and doc changes. Merge candidate if the parameter changes are compatible.
- [ ] Decide which branches to incorporate. Create a consolidated branch (e.g. `python-port-base`) from master + cherry-picked/merged fixes.
- [ ] Run `make integration_test` on the consolidated branch. Must be green.
- [ ] If any merge conflicts arise, resolve them. Document what was merged and why.
- [ ] Also check the upstream repo for any open PRs that should be incorporated. (API was rate-limited during analysis — check manually at https://github.com/watem-sedem/watem-sedem/pulls)

**Architecture mapping (after branch resolution):**
- [ ] Full clone with LFS: `git clone https://github.com/JoernStoehler/watem-sedem.git && cd watem-sedem && git lfs pull`
- [ ] Install Free Pascal compiler: `apt-get install fpc` (or equivalent)
- [ ] `make integration_test` — must be all green before proceeding. If tests fail: possible causes are missing LFS files, missing Python deps (`rasterio`, `numpy`, `pandas`, `pytest`), fpc version mismatch. The CI Dockerfile in `ci/` shows the expected environment.
- [ ] Auto-generate the dependency graph by parsing `Uses` clauses from all .pas files. Output as text and/or mermaid diagram.
- [ ] For every global variable in `RData_CN` and `ReadInParameters`: document its name, Pascal type, Python equivalent type, and which units read/write it. Output as a table (markdown or CSV).
- [ ] For every public function/procedure in `common/`: document its signature, whether it's pure (output depends only on arguments) or impure (reads/writes globals), and a one-line description. Many function names are in Dutch — translate them.
- [ ] Read the molenbeek .ini file. Document which extensions/flags are enabled. This determines the minimum scope of the port: if molenbeek doesn't use CN or buffers, we can skip those modules initially.
- [ ] Read the Dutch comments in the code. Many contain important context. Google Translate is fine.
- [ ] Find and document the `TRoutingArray` type definition — it was not in the interface sections I read, likely defined in the implementation section of `raster_calculations.pas`. This is the core data structure of the model.

### Gate
Machine-readable artifacts exist:
1. Consolidated porting base branch with `make integration_test` green
2. Dependency graph
3. Global variable catalog
4. Function catalog (including `TRoutingArray` and all routing-related types)
5. Scope determination (which extensions are needed for molenbeek)
6. Document listing which branches were merged and why, which were skipped and why

### Why this phase exists
You cannot delegate porting to an AI agent without the agent having a complete map. If you skip this, the agent will make assumptions about globals, indexing, or module boundaries that silently break things. This phase is ~1 hour of agent time and prevents days of debugging later. The branch resolution is especially important — porting from the wrong base means either missing bugfixes or porting code that will be changed later.

---

## Phase 2: Harden Pascal tests

### What to do
- [ ] Inventory what the existing unit test (`test_sgrd.pas`) actually covers. It's only SGRD reading — nothing about computation.
- [ ] Create a minimal synthetic test case: a small grid (5×5 or similar) with hand-chosen elevation values, uniform RUSLE factors, and a simple parcel map. Write the input files in the format the model expects (.rdc/.rst or .sgrd/.sdat). Create a matching .ini file with minimal extensions enabled.
- [ ] Run the Pascal binary on this synthetic case. Save all outputs as a frozen reference snapshot.
- [ ] Also re-save the molenbeek reference outputs (they're already in the repo under `modeloutput_ref/` but explicitly copy them to ensure we have a bit-identical baseline against our porting base branch, which may differ from upstream master if branches were merged).
- [ ] Optionally: add more fpcunit tests for individual functions if time permits. But this is lower priority than the synthetic integration test because (a) the per-function tests will be written in Python anyway and (b) fpcunit is an unusual framework that the AI agent may struggle with.

### Gate
Two reference datasets exist with saved outputs:
1. molenbeek (real-world, exercises most code paths)
2. synthetic (tiny, fast, exercises core path only, hand-verifiable)

Both generated from the consolidated porting base branch, not from upstream master.

### Why this phase exists
The synthetic test case serves two purposes: (a) fast iteration during porting — runs in milliseconds vs. seconds for molenbeek, and (b) a test case you can reason about by hand if there's a numerical discrepancy. If the slope of cell (3,2) is wrong, you can compute what it should be from the 3×3 stencil of elevation values. You can't do that with molenbeek's real terrain data.

### Risk
Creating synthetic test input files in the right binary format is fiddly. The agent might spend significant time on this. If it takes more than ~30 minutes, skip it and rely solely on molenbeek. The molenbeek test is sufficient for correctness — the synthetic test is a nice-to-have for debugging speed.

---

## Phase 3: Scaffold Python project

### What to do
- [ ] Create Python package structure:
  ```
  watem_sedem_py/          (or whatever name)
  ├── pyproject.toml
  ├── src/
  │   └── watem_sedem/
  │       ├── __init__.py
  │       ├── __main__.py        # CLI entry point
  │       ├── state.py           # all global state
  │       ├── raster.py          # raster types and I/O (replaces rdata_cn + gdata_cn)
  │       ├── parameters.py      # ini parsing (replaces readinparameters)
  │       ├── raster_calc.py     # slope, aspect, LS, routing (replaces raster_calculations)
  │       ├── lateral.py         # sediment redistribution (replaces lateralredistribution)
  │       ├── cn.py              # curve number extension (replaces cn_calculations) — MAYBE OUT OF SCOPE
  │       ├── tillage.py         # tillage erosion
  │       ├── output.py          # raster + table output (replaces write_raster + write_output)
  │       └── model.py           # orchestrator (replaces runmodel)
  └── tests/
      ├── test_integration.py    # molenbeek + synthetic full-model tests
      ├── test_raster_io.py      # raster loading/saving
      ├── test_raster_calc.py    # unit tests for computation functions
      └── ...
  ```
- [ ] Port the global state. Approach: a `ModelState` dataclass (or plain module namespace) containing every global variable from `RData_CN` and `ReadInParameters`. Use the catalog from Phase 1. Types: `nrow: int`, `ncol: int`, rasters as `np.ndarray` (dtype `np.float32` for RRaster, `np.int32` for GRaster), booleans as `bool`, strings as `str`. **Do not refactor the state yet.** 1:1 correspondence with Pascal globals.
- [ ] Port the raster types. The Pascal `Traster<T>` with its 1-indexed, border-padded array maps to a numpy array of shape `(nrow+2, ncol+2)`. Document the indexing convention: `array[i, j]` in Python corresponds to `Z[i, j]` in Pascal, both 1-indexed in the interior, with row 0 / col 0 / row nrow+1 / col ncol+1 as border padding. **Alternatively:** use 0-indexed arrays and adjust all index expressions during porting. This is a critical design decision — pick one approach and document it prominently so all subsequent agents use the same convention.
- [ ] Port raster I/O using rasterio. Load molenbeek input rasters with both Pascal and Python, compare cell-by-cell. Specific things to check:
  - Does rasterio respect the `toptobottom` flag the same way?
  - Are nodata values handled identically?
  - Is the padding/border initialization correct?
  - Are integer rasters loaded as the right dtype?
- [ ] Port ini-file parsing. The Pascal code in `readinparameters.pas` reads a custom .ini format. Load the molenbeek .ini with both implementations, compare all parsed values.
- [ ] Set up pytest with both reference datasets, all tests red

### Gate
- Python package exists and installs (`pip install -e .`)
- Raster I/O produces identical arrays to Pascal (verified on molenbeek inputs)
- Ini parsing produces identical config to Pascal (verified on molenbeek .ini)
- Integration test stubs exist and fail (correctly, because computation isn't ported yet)

### Why this phase exists
This is the foundation layer. Every subsequent module depends on having correct I/O and correct state initialization. If the rasters load differently, or the ini parser misreads a parameter, every computation will be wrong and you'll waste hours debugging the wrong layer.

### Design decisions to make here

**Indexing convention:** The Pascal code is pervasively 1-indexed with border padding. You have three options:
1. **Pad + 1-index in Python:** allocate `(nrow+2, ncol+2)` arrays, loops go `for i in range(1, nrow+1)`. Minimal translation effort, ugly Python, easy to verify against Pascal line-by-line.
2. **Pad + 0-index:** allocate `(nrow+2, ncol+2)` arrays, rewrite all index expressions to subtract 1. Error-prone.
3. **No pad + 0-index:** allocate `(nrow, ncol)` arrays, handle borders separately. Most Pythonic, hardest to verify against Pascal.

**Recommendation:** Option 1 for the initial port. It's the safest path to a correct implementation. Refactor to option 3 later if desired.

**float32 vs float64:** Pascal uses `single` (32-bit float). Python's numpy default is `float64`. Using `float32` maximizes numerical fidelity to Pascal but may accumulate different rounding in long computations. Using `float64` is more numerically stable but will produce slightly different results. The integration tests have tolerances (`rtol=1e-5, atol=1e-3` for the worst case) that should accommodate either choice. **Recommendation:** use `float64` for computation, only convert to `float32` for output if needed. This matches how most scientific Python code works.

---

## Phase 4: Port core modules

### What to do

Port modules in dependency order. For each module:
1. Read the Pascal source in full
2. Port each function/procedure, preserving names and signatures as closely as possible
3. Write a unit test for each function using known input→output pairs (either from Phase 2's synthetic test or from manually computed examples)
4. Run the unit tests, fix bugs
5. Once all functions in the module are ported, run the synthetic integration test if available
6. Commit

### Module-by-module notes

**`raster_calc.py`** (from `raster_calculations.pas`, 1624 lines, 24 functions)

This is the largest and most important module. Key functions:
- `CalculateSlopeAspect()` — finite differences on DEM grid, writes to global slope/aspect rasters
- `CalculateSLOPE(i,j)`, `CalculateASPECT(i,j)` — per-cell slope and aspect
- `Calculate_routing()` — determines flow direction for each cell (which 1-2 neighbors receive outflow)
- `Invert_routing()` — inverts the routing table for upstream traversal
- `Calculate_UpstreamArea()` — accumulates upstream contributing area
- `CalculateLS()` — computes the LS-factor from upstream area and slope
- `DistributeFlux_Sediment(i,j)` — routes sediment from one cell to its targets
- `Apply_Routing()` — the main sediment routing loop
- `Apply_Buffer(i,j)` — buffer basin sediment trapping

The routing data structure `TRoutingArray` is an array of records, each containing target cell indices and flux fractions. This needs to be ported carefully — it's the core data structure of the model.

**Epistemic status on routing:** This is the area most likely to have subtle bugs during porting. The flux decomposition logic involves trigonometric calculations, tie-breaking rules, and special cases for river cells, road cells, and various land use types. The CHANGELOG shows multiple historical routing bugfixes. The `grass_strip_field` branch in the fork contains yet another routing fix. The integration test is the primary correctness check.

**`lateral.py`** (from `lateralredistribution.pas`, 907 lines, 5 functions)

The main sediment redistribution sweep. Iterates over all cells in order and calls `DistributeFlux_Sediment`. Also handles buffer interactions. Depends on routing being correct.

**`tillage.py`** (from `tillage.pas`, 89 lines)

Tillage erosion as a diffusion process. Small, self-contained, can be ported independently. Quick win for morale.

**`cn.py`** (from `cn_calculations.pas`, 1412 lines, 12 functions)

Curve Number extension for estimating surface runoff. **May be out of scope** depending on what the molenbeek .ini enables. Check in Phase 1. If it's not exercised by the integration test, skip it and add a `raise NotImplementedError("CN extension not yet ported")` stub.

**`output.py`** (from `write_raster.pas` + `write_output.pas`, ~400 lines combined)

Writes output rasters and summary tables. Relatively straightforward — rasterio for rasters, string formatting for tables. Can be ported in parallel with the computation modules.

**`model.py`** (from `runmodel.pas`, 159 lines)

Orchestrator. Calls everything in the right order. Port last, once all components work.

### Parallelization opportunity

Once Phase 3 is complete, you can run multiple Claude Code agents:
- Agent A: `raster_calc.py` (the big one)
- Agent B: `tillage.py` + `output.py` (small independent modules)
- Agent C: `cn.py` (if in scope)

`lateral.py` depends on `raster_calc.py` (specifically the routing data structures), so it should wait for Agent A to finish. `model.py` waits for everything.

### Gate
- All unit tests green for each ported module
- Synthetic integration test passes end-to-end (if it exists from Phase 2)

### Risk: silent numerical divergence
The most dangerous failure mode is an agent writing Python code that produces plausible-looking numbers but differs from Pascal in ways that unit tests don't catch. For example: a routing function that sends 51% of flux left and 49% right instead of 49/51. The unit tests would need the exact expected values to catch this.

**Mitigation:** For the most critical functions (routing, LS-factor, sediment distribution), generate test cases by actually running the Pascal code with controlled inputs and recording intermediate values. This requires the Pascal binary to be instrumented or the agent to add temporary `WriteLn` debugging output.

---

## Phase 5: Integration validation

### What to do
- [ ] Wire `model.py` to call all modules in the correct order
- [ ] Run `python -m watem_sedem testfiles/molenbeek/modelinput/ini_molenbeek_scenario_1.ini`
- [ ] Run the existing `test_compare_output.py` against the Python outputs
- [ ] For each failing comparison:
  1. Identify which output raster or table differs
  2. Determine which computation function produces that output
  3. Compare intermediate values between Pascal and Python (may need to add debug output to Pascal)
  4. Fix the Python code
  5. Re-run integration test
- [ ] Also run the SAGA-format variant to verify format-independent correctness
- [ ] All integration tests green with the same tolerances used for Pascal-vs-Pascal comparison

### Expected failure modes (in rough order of likelihood)
1. **Off-by-one indexing** — the border padding or 1-indexing got translated wrong somewhere
2. **Integer truncation** — Pascal's `integer` division truncates toward zero; Python's `//` floors toward negative infinity. Different for negative numbers.
3. **float32 vs float64 accumulation** — if the Pascal code accumulates in `single` and we accumulate in `float64`, results may differ by more than the tolerance for cumulative quantities
4. **Routing tie-breaking** — when two neighbors have equal slope, the Pascal code may break ties differently than the Python code (e.g., due to evaluation order)
5. **Raster border handling** — `CopyRasterBorders` vs `SetRasterBorders` semantics
6. **Ini parsing differences** — whitespace handling, decimal separator (the Pascal code explicitly sets decimal separator to '.'), case sensitivity

### Gate
`pytest testfiles/` passes. Specifically:
- All output rasters match within per-file tolerances
- `Total sediment.txt` values match within `(rtol=1e-8, atol=1e-8)`
- Segment tables match

---

## Phase 6: Package and ship

### What to do
- [ ] Ensure LGPL-3.0 license is present and attribution to original authors (KU Leuven, Fluves, Departement Omgeving, VMM) is in README
- [ ] README.md explaining:
  - What this is (Python port of WaTEM/SEDEM)
  - How to install (`pip install .`)
  - How to run (`python -m watem_sedem <ini_file>`)
  - That outputs should be identical to Pascal version within integration test tolerances
  - What's not ported yet (extensions, GUI)
  - Link to original repo
- [ ] `pyproject.toml` with dependencies: `numpy`, `rasterio`, `pandas` (for table output if needed)
- [ ] ARCHITECTURE.md showing module map and correspondence to Pascal units
- [ ] GitHub Actions CI that runs `pytest` (both unit and integration tests)
- [ ] Clean up any debug code, temporary files, etc.

### Gate
- Fresh clone → `pip install .` → `python -m watem_sedem testfiles/molenbeek/modelinput/ini_molenbeek_scenario_1.ini` → `pytest testfiles/` → all green
- Someone unfamiliar with the project can follow the README and run the model

---

## Explicitly out of scope

- **Extensions not exercised by molenbeek test:** If the molenbeek .ini doesn't enable CN, buffers, dams, ditches, forced routing, river routing, or river topology, those are out of scope. Stub them with `NotImplementedError`. Check this in Phase 1.
- **Performance optimization:** The Pascal code is single-threaded and processes cells in a loop. The Python port should do the same. NumPy vectorization or parallelization is a separate project. The job ad mentions "parallelization for large-scale simulations" as a task — that's future work on top of the port.
- **GUI code:** `watem_sedem_gui/` and `watem_sedem_gui_LT/` are old Delphi GUI variants. Completely out of scope.
- **pywatemsedem wrapper:** The existing Python wrapper (`pywatemsedem`) handles GIS preprocessing and calls the Pascal binary. It will eventually need to call the Python implementation instead, but that's a separate integration task.
- **Architectural refactoring:** The global mutable state pattern is ugly but it's what the Pascal does. Don't refactor during the port. Once the integration tests pass, refactoring is safe and optional.

---

## Risk watchlist

### 1. Silent numerical divergence (HIGH)
Agent writes code that passes self-generated unit tests but diverges from Pascal. The unit tests are only as good as the expected values baked into them.
**Mitigation:** Run molenbeek integration test after EVERY module port, not just at the end. Diff outputs early.

### 2. Git LFS files not fetched (MEDIUM)  
The molenbeek test data uses Git LFS. A shallow clone or a clone without LFS will get placeholder files instead of actual raster data. The integration tests will fail with confusing rasterio errors.
**Mitigation:** Verify test data integrity before starting. Check file sizes — real .rst files are KB to MB, LFS placeholders are ~130 bytes.

### 3. Raster I/O format edge cases (MEDIUM)
The Pascal code has custom readers for .rdc/.rst and .sgrd/.sdat. Rasterio uses GDAL under the hood, which may interpret these files slightly differently (nodata handling, coordinate systems, byte order).
**Mitigation:** Byte-level comparison of loaded arrays in Phase 3.

### 4. Global state initialization order (MEDIUM)
Pascal unit initialization runs in dependency order. If the Python equivalent doesn't initialize state in the same order, some values may be undefined or stale.
**Mitigation:** The Phase 1 global variable catalog explicitly tracks which unit initializes each variable.

### 5. Extensions entanglement (LOW-MEDIUM)
A module that looks optional may have side effects on the core path. For example, buffer handling may modify routing tables even when buffers are disabled.
**Mitigation:** Read the actual code paths, don't just rely on boolean flags. The molenbeek .ini determines the minimum viable port.

### 6. Agent generates tests that test the Python code against itself (LOW but insidious)
If the agent writes a unit test by running the Python function and recording its output, the test is tautological — it only tests that the function produces the same wrong answer consistently.
**Mitigation:** Unit test expected values must come from either (a) the Pascal binary, (b) hand calculation, or (c) the domain documentation. Never from the Python code being tested.

### 7. Porting from wrong branch base (MEDIUM — addressed in Phase 1)
If we port from upstream master and the fork branches contain important bugfixes (especially `negative_slopes`, `outside_modeldomain`, `grass_strip_field`), we'd be porting known-buggy code. If we port from the fork but it contains unfinished/broken experiments, we'd be porting unstable code.
**Mitigation:** Phase 1 branch resolution. Examine every branch, merge deliberately, test the result.

---

## Notes on specific code quirks observed during analysis

- Dutch comments throughout (e.g. "Er wordt geheugen vrijgemaakt voor de matrix Z" = "Memory is allocated for matrix Z"). Google Translate handles this fine.
- The code uses `specialize` for Free Pascal generics: `Graster = specialize Traster<integer>`. This is a Free Pascal-specific syntax, not Delphi-compatible.
- `SetzeroG` uses `Fillword` to zero-initialize integer rasters — relies on the in-memory representation of `0` as all-zero-bytes. Fine for integers, would be wrong for floats, but it's only used on `GRaster` (integer).
- The `Earth_DegToMeter = 111319.444444444` constant is used for lat/lon projection support. Check if molenbeek uses plane or latlong projection.
- Range checking is enabled (`{$R+}`) — the Pascal code will raise runtime errors on array bounds violations. Python numpy will silently produce wrong results on out-of-bounds access unless you use explicit bounds checking.
- The code overrides the system decimal separator to '.' (mentioned in CHANGELOG) — this is relevant for ini parsing and output formatting.
- The `readasciifile` procedure in `gdata_cn.pas` has what looks like a scoping bug: the `if header.toptobottom then irow:=i else irow:=nrow-i+1;` line is outside the inner `For j` loop body in a way that's ambiguous in Pascal. Need to verify actual behavior by testing.
- The routing array (`TRoutingArray`) is not defined in any of the interface sections I read — it's likely defined in the implementation section of `raster_calculations.pas`. The agent needs to find and document this type during Phase 1.
- The `negative_slopes` and `outside_modeldomain` branches could NOT be analyzed (GitHub API rate limited). Their names strongly suggest they contain fixes to slope calculation and domain boundary handling respectively — both of which are areas where porting bugs would be hard to detect. **Do not skip examining these in Phase 1.**
