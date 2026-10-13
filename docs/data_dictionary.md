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

`analytical.csv` contains one intended row per country-year and one column per
configured WDI variable. `gdp_per_capita_growth` is intended to measure the
percentage change from the same country's previous calendar year. Verify its
implementation before interpreting it.

Record your selected ILOSTAT code, exact age/sex/population concept, unit,
source and status fields, retrieval date, observed coverage and transformations
here after inspecting the source metadata.