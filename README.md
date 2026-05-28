# sctocomments

`sctocomments` is a Stata command that consolidates SurveyCTO "Comments-*.csv" exports into a single `.dta` file. It standardises column names, extracts the referenced field, builds repeat-instance identifiers, and (optionally) merges the results with survey datasets to bring in case IDs, variable values, and labels.

---

## Installation

```stata
net install sctocomments, from(https://raw.githubusercontent.com/ajolex/scto-field-comments/master/sctocomments) replace
help sctocomments
```

This requires Stata 17 or newer (the command declares `version 17.0`). The ado file does not modify the working directory and only writes to the path you provide.

---

## Quick Start

```stata
* set the project folder that contains the media/ subfolder
local proj "C:/Users/you/yourproject"

* collate comments (no survey merge)
sctocomments, path("`proj'")

* collate and merge with survey data for case IDs and values
sctocomments, path("`proj'") survey("survey_data.dta")

* review the combined data
use "`proj'/comments.dta", clear
list in 1/10
```

Provide `mediafolder()` if the comment CSVs live somewhere other than `path()/media`, and `out()` to change the name or location of the resulting dataset.

---

## Syntax

```stata
sctocomments, path(string) [mediafolder(string) filesub(string) ///
    out(string) survey(string) use(string) keepvars(string) stripgrp nosave]
```

### Options

| Option | Description |
| --- | --- |
| `path(string)` | **Required.** Base directory used to resolve all relative paths. Trailing separators are trimmed automatically. |
| `mediafolder(string)` | Folder that stores the comment CSVs. Accepts relative fragments (e.g. `"media/comments"`) or an absolute override. Default is `"media"`. |
| `filesub(string)` | Filename pattern passed to Stata's `dir` command. Default is `"Comments*.csv"`. |
| `out(string)` | Output dataset name. Relative values are written inside `path()`. Absolute paths are honoured as-is. Default is `"comments.dta"`. |
| `survey(string)` | Optional survey dataset for merging. Must contain a `key` variable (`"uuid:" + uuid`). The command auto-detects common case ID variables (caseid, hhid, instanceid, etc.) and extracts variable values and labels for commented fields. |
| `use(string)` | Alias for `survey()`. Provided for backward compatibility. |
| `keepvars(string)` | Space-separated list of additional variables to keep from the survey dataset (e.g., `"fo_id enum_name"`). |
| `stripgrp` | Flag to remove the `grp_` prefix from derived variable names. |
| `nosave` | Load the combined dataset in memory without saving to disk. Useful for inspection or piping to other commands. |

All option paths accept forward `/` or back `\` slashes; the command normalises them for the host operating system.

---

## What the Command Does

1. **Normalises paths and confirms the target folder exists.**
2. **Enumerates comment CSVs** using `filesub()`; exits with error if none are found.
3. **Imports each file** with `import delimited, stripquotes(yes) bindquotes(strict)`, harmonising variants of `Field_name`, `field_name`, etc. into `fieldname` and `comment`.
4. **Normalises the `comment` variable to string** to prevent type mismatches during append operations.
5. **Drops empty/header rows**, records the source filename and extracts the UUID from the filename (text after `"Comments-"`, without `.csv`).
6. **Stacks all comment rows** into a temporary dataset on disk so memory usage stays bounded even with thousands of files.
7. **Saves a raw comments file** (`comments_raw.dta`) before further processing for debugging and record-keeping.
8. **Splits `fieldname` on `/`**, selecting the last non-empty component as `variable` and extracting repeat indices when SurveyCTO repeat groups are present. The final `variable` combines the base name with repeat indices when available.
9. **Keeps rows with both `variable` and `comment`,** and creates `key = "uuid:" + uuid` for compatibility with SurveyCTO survey exports.
10. **Optionally merges survey data** via `survey()`, auto-detecting common case ID variables (caseid, hhid, instanceid, submissionid, key) and extracting variable values and labels for commented fields.
11. **Saves the combined dataset** to `out()` (unless `nosave` is specified) and reports the number of comment observations.

The final dataset contains at minimum:

| Variable | Description |
| --- | --- |
| `variable` | Derived field/variable name, including repeat indices when relevant. |
| `comment` | Enumerator comment text. |
| `fieldname` | Original SurveyCTO field path (when no survey merge). |
| `key` | `"uuid:" + uuid`, suitable for merging with SurveyCTO survey exports. |

When `survey()` is provided, additional columns include:

| Variable | Description |
| --- | --- |
| `caseid` (or similar) | Auto-detected case identifier from the survey dataset. |
| `value` | Value of the referenced variable (converted to string). |
| `label_val` | Variable label from the survey dataset (if available). |
| `<keepvars>` | Any additional variables specified in `keepvars()`. |

---

## Tips and Caveats

- The command reads every CSV matching `filesub()`. Use restrictive patterns (e.g. `"Comments-2024-*.csv"`) if your media folder is large.
- SurveyCTO sometimes repeats header rows (`Field name`, etc.) within CSVs; these are dropped automatically, and completely empty files are skipped.
- The `comment` variable is always normalized to string type to prevent data loss during append operations.
- A raw comments file (`comments_raw.dta`) is saved automatically before processing for debugging purposes.
- Large directories (thousands of CSVs) are supported; processing time scales roughly linearly with the number of files. Progress is printed file-by-file.
- The command auto-detects common case ID variable names: `caseid`, `hhid`, `instanceid`, `submissionid`, `key`.
- Use `nosave` option to inspect data in memory without writing to disk.

---

## Changelog

### v2.0 (December 2025)

- **Simplified syntax**: Removed redundant `caseid()` requirement; `use()` kept as alias for `survey()`
- **Auto-detection**: Automatically detects common case ID variables from survey data
- **Performance**: Optimized variable extraction (up to 100x faster on large datasets)
- **Robustness**: Normalizes comment variable to string to prevent type mismatches
- **New option**: Added `nosave` to load data in memory without saving
- **Better output**: Saves `comments_raw.dta` for debugging before processing

---

## Support

For issues or contributions, visit the repository: <https://github.com/ajolex/scto-field-comments>. The project is released under the MIT License. Bug reports that include the command call, abbreviated log, and (if possible) a synthetic example dataset are especially helpful.
