# Working Data Dictionary

## WDI Inputs

| Indicator | Variable | Definition | Unit |
| --- | --- | --- | --- |
| NY.GDP.MKTP.KD.ZG | gdp_growth | Annual percentage growth of GDP at market prices based on constant local currency | Annual percent |
| NY.GDP.PCAP.KD | gdp_per_capita | GDP divided by midyear population | Constant 2015 US dollars |
| SP.POP.TOTL | population | Total population, using the de facto definition | Persons |

Source: World Bank World Development Indicators, accessed through the `WDI`
R package. Confirm definitions in the source metadata when extending the project.
Configured coverage is BRA, IDN, KEN and VNM, 2010-2023; actual availability
must be checked after download. Missing values remain missing.

## Processed Fields

`wdi_long.csv` contains `country_code` (ISO3), `country_name`, `year` (integer),
`indicator` (WDI code), `variable`, `value` (numeric), `unit` and `source`.
Its intended unique key is country-code, year and indicator.

## ILOSTAT Input and Processed Fields

The selected annual dataset is `EMP_2WAP_SEX_AGE_RT_A`, Employment-to-population
ratio by sex and age, ILO modelled estimates (November 2025). The selection is
total sex (`SEX_T`) and age 15+ (`AGE_YTHADULT_YGE15`), reported as a percent.
These codes and labels were checked in the current ILOSTAT table of contents
and returned data. The configured country/year coverage is BRA, IDN, KEN and
VNM, 2010-2023. The retrieval recorded on 2026-10-15 contained 56 observations:
14 years for each configured country. Future source updates may change coverage.

`ilostat_long.csv` standardizes the selected data to `country_code` (ISO3),
`year` (integer), `indicator` (the ILOSTAT dataset ID), and `value` (numeric).
It also retains `source` (the ILOSTAT source identifier), `status`, source and
classification labels and codes, and `unit`. ILOSTAT does not supply an
observation-status field for this dataset; `status` and `status_label` are
therefore blank, and the cleaning script warns about that absence. The raw
download and retrieval metadata are stored under `data/raw/`; the processed
file is under `data/processed/`. Both locations are excluded from Git.

`analytical.csv` includes the ILO value as `employment_to_population`, joined
by the explicit country-year key, with corresponding source and status
columns. The ratio is a modelled estimate and should not be combined with
other age/sex populations or similarly named series without checking their
metadata.

## WDI-ILOSTAT Merge Diagnostics

Run `R/03a_diagnose_merge.R` after both clean steps and inspect its files before
running the analytical merge. `wdi_ilostat_merge_detail.csv` is a full
country-year join: it retains WDI values, ILOSTAT values, source/status fields,
and a `merge_status` of `matched`, `WDI-only` or `ILOSTAT-only`. Missing values
are counted but not filtered. `wdi_ilostat_merge_report.csv` records key
counts and validation results; `wdi_ilostat_unit_report.csv` records expected
and observed units.

Checks classified `STOP` (malformed columns/years/codes, duplicate join keys,
or unit mismatches) halt before diagnostics are written. `WARNING` flags
unmatched country coverage or missing values/status flags for review.
`INFORMATIONAL` reports successful standardization, matched counts, and
known unavailable status metadata. All diagnostics are written under
`data/processed/`, which is excluded from Git.

On 2026-10-15 the diagnostic found 56 matched country-years, zero WDI-only
rows and zero ILOSTAT-only rows. WDI and ILOSTAT country codes matched the
configured ISO3 codes; years were integer 2010-2023. No WDI or ILOSTAT values
were missing. The ILOSTAT source did not supply any status flags; its status
columns remain present and missing in the detail output. Units were retained
as annual percent, constant 2015 US dollars, persons, and percent respectively;
the two percentage measures remain distinct columns.

`analytical.csv` contains one intended row per country-year and one column per
configured WDI variable, plus the selected ILOSTAT series.
`gdp_per_capita_growth` is intended to measure the
percentage change from the same country's previous calendar year. Verify its
implementation before interpreting it.