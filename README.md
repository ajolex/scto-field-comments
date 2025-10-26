# 📊 sctocomments: SurveyCTO Comments Collation Command

**`sctocomments`** is a Stata command-line tool for collating and merging **SurveyCTO comment CSV files** (e.g., `Comments-*.csv`) into a unified Stata dataset. It automatically extracts variable names and labels, merges comments with your survey data, and supports customization of key identifiers (e.g., case ID, enumerator ID, field coordinator ID). This utility streamlines the processing of **field comments** from SurveyCTO, including those with hierarchical field names from groups and repeat instances.

---

## 🧭 Overview

The `sctocomments` command:

- Collects and combines all SurveyCTO comment CSV files (typically stored in a `media` subfolder).
- Extracts variable names from the **last non-empty segment** of each field path.
- Handles **repeat group instances** and **nested field structures** automatically.
- Optionally removes `grp_` prefixes from variable names.
- Merges with a survey dataset to include **key IDs, variable values, and labels**.

The output is a clean `.dta` file containing all comments and relevant metadata.

---

## ⚙️ Installation

### 1. Manual Installation

Save `sctocomments.ado` to your Stata personal ado directory:

```stata
sysdir

- **Windows:** `%USERPROFILE%\ado\personal\`
- **macOS/Linux:** `~/ado/personal/`

### 2. Install via GitHub (optional)
```bash
git clone https://github.com/yourusername/scto-field-comments.git
```

Or directly from within Stata:
```stata
net install sctocomments, from("https://raw.githubusercontent.com/ajolex/scto-field-comments/master/sctocomments/") replace
```
### 3. Verify Installation
In Stata:

```stata
which sctocomments
```
## You should see the full path to the installed `.ado` file
---
## 🚀 Usage

### Syntax

```stata
sctocomments, path(string) caseid(string) [mediafolder(string) filesub(string) out(string) survey(string)
 use(string) keepvars(string) stripgrp]                                        
```
### Options

| Option            | Description                                                                                                   |
|-------------------|--------------------------------------------------------------------------------------------------------------|
| **path(string)**  | **Required.** Base folder containing the comments CSV folder.                                                 |
| **caseid(string)**| **Required.** Variable name for the unique case ID in the survey dataset.                                    |
| **mediafolder(string)** | Subfolder containing comment CSVs (default: `"media"`).                                                |
| **filesub(string)** | Filename pattern for comment files (default: `"Comments*.csv"`).                                           |
| **out(string)**   | Output `.dta` filepath (default: `"comments.dta"` inside `path`).                                            |
| **survey(string)**| **Required.** Full path to the survey dataset to merge with.                                                 |
| **use(string)**   | Path to an auxiliary dataset for extracting variable values/labels.                                          |
| **keepvars(string)** | Space-separated list of additional variables to keep (e.g., `"fo_id fc_id"`). Defaults to `"fo_id fc_id"`.|
| **stripgrp**      | Removes the `"grp_"` prefix from variable names (e.g., `grp_mig_lgth_mr_1` → `mig_lgth_mr_1`).              |

### 💡 Examples

#### Basic usage
```stata
sctocomments, path("C:\Users\AJolex\Documents\scto-field-comments") ///
    caseid("caseid") survey("survey_data.dta")
```
→ Processes all `Comments*.csv` files in the `media` subfolder, merges by `caseid`, and saves the result 
as `comments.dta`.                                                                                       
#### With custom variables and options
```stata
sctocomments, path("C:\Users\AJolex\Documents\scto-field-comments") ///
    caseid("unique_id") keepvars("enum_id coord_id") ///
    survey("survey_data.dta") use("use_data.dta") stripgrp
```

Uses `unique_id` as the case ID, keeps `enum_id` and `coord_id`, merges with `use_data.dta` for variable labels, strips `grp_` prefixes, and saves the output


## ⚡ Quick Start Example

Here’s an example folder layout to help you get started:

```
scto-field-comments/
├── media/
│   ├── Comments-0c2843ad-0293-4a5f-a6e6-d97581ad281a.csv
│   ├── Comments-0cb021ad-a8a1-418c-b8be-55131ee89d45.csv
│   └── Comments-0cdb217c-dab0-4de4-8fe9-2e71ac2dcb86.csv
├── survey_data.dta
├── use_data.dta
└── sctocomments.ado
```

**Step 1:** Open Stata in this directory.
**Step 2:** Run:
```stata
sctocomments, path(".") caseid("uuid") survey("survey_data.dta") use("use_data.dta") stripgrp
```

**Step 3:** View results:
```stata
use "comments.dta", clear
browse
```
### Example Output

| caseid | variable         | comment                              | label_val                      | fo_id | fc_id |
|--------|------------------|--------------------------------------|--------------------------------|-------|-------|
| A001   | fd_cons_2b_v1_1  | Enumerator unsure about units        | Quantity of maize consumed     | 203   | 45    |
| A002   | hh_size          | Household size changed on revisit    | Household size (members)       | 201   | 45    |
| A002   | grp_income_1     | Missing value, confirmed zero income | Income from main occupation    | 201   | 45    |

## 📂 Output

The resulting `comments.dta` includes:

| Variable | Description |
|-----------|--------------|
| **caseid** | Unique case ID from the survey dataset. |
| **keepvars** | Variables from `keepvars()` (e.g., `fo_id`, `fc_id`, etc.). Missing if not present in the survey dataset. |
| **variable** | The derived variable name from the last segment of the `Field name`. |
| **comment** | Text from the comment CSV. |
| **label_val** | Variable label if a match is found in the use dataset. |

---

## ⚠️ Cautions and Limitations

### Fieldname Segment Limit
The program assumes the `Field name` can be split into up to **9 segments**.
If your data has deeper nesting, increase loop limits in the ado file (e.g., `1/8` → `1/10`).

### Repeat and Group Instances
Repeat group indices (e.g., `[8]`, `[1]`) are appended to the variable name.
If your naming convention differs, modify the regex accordingly.
`grp_` prefixes can be removed with the `stripgrp` option.

### Variable Name Derivation
Variables are derived from the last non-empty segment of the field path.
If the structure varies or uses different delimiters, check your CSV’s `Field name` format.

### Missing Survey Variables
If `caseid` or `keepvars` are missing from the survey dataset, the program issues a warning or exits with
### Survey Dataset Requirements
Ensure your survey dataset contains the required key variables (`caseid` and any variables listed in `keepvars`). If these variables are missing, the program will issue a warning or terminate with an error. Double-check variable names and formats before running the command.
### Large Datasets
Extracting values and labels from large datasets may reduce performance.
Filter variables if needed to improve speed.

---

## 🛠️ Troubleshooting

| Error | Cause & Solution |
| **variable already defined (r(110))** | Occurs if a variable in `keepvars` already exists before generation. Use `capture gen` or clear the dataset before re-running. |
| **Incomplete extraction** | Check the `Field name` format and adjust loop limits or regex as needed. |
| **Missing data** | Ensure the survey and use datasets contain the key variable (`uuid:<id>`). |        

---

**Developed by:** *Aubrey Jolex*
**License:** MIT
**Compatible with:** Stata 15+
**Repository:** [github.com/ajolex/scto-field-comments](https://github.com/ajolex/scto-field-comments)   

```markdown
