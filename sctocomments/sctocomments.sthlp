.SS sctocomments
.SP 1
.SH NAME
sctocomments \- Collate SurveyCTO comments CSVs into a single Stata dataset
.SP 1
.SH SYNOPSIS
.TP
.B sctocomments, path(string) caseid(string) [mediafolder(string) filesub(string) out(string) survey(string) use(string) keepvars(string) stripgrp]
.SH DESCRIPTION
The \fBsctocomments\fR command imports SurveyCTO comments CSV exports (files named like \fBComments-<uuid>.csv\fR) found in the
subfolder specified by \fBmediafolder()\fR under the folder provided in \fBpath()\fR. It collates them into a single Stata dataset,
optionally merges with a survey dataset, and extracts variable names, values, and labels from a provided `use` dataset.

.SH OPTIONS
.TP
.B path(string)
Base project folder that contains the CSV files subfolder. Required.
.TP
.B caseid(string)
Variable name for the unique case identifier used to merge comments with your survey dataset. Required.
.TP
.B mediafolder(string)
Name of subfolder containing comment CSV files. Default: \fBmedia\fR.
.TP
.B filesub(string)
Filename pattern for the comment CSVs. Default: \fBComments*.csv\fR.
.TP
.B out(string)
Output filename to save (within \fBpath()\fR). Default: \fBcomments.dta\fR.
.TP
.B survey(string)
Full path to survey dataset to merge with. Optional.
.TP
.B use(string)
Full path to main survey dataset for extracting variable values/labels. Optional.
.TP
.B keepvars(string)
Space-separated list of additional variables to keep from the survey dataset (e.g., \fBfo_id fc_id\fR). Optional.
.TP
.B stripgrp
Option (flag) to remove the prefix \fBgrp_\fR from derived variable names.

.SH DETAILS
The command extracts variable names from the last non-empty segment of the `Field name` path present in SurveyCTO exports. It
handles repeat group indices (appending them to variable names) and extracts values/labels when a `use()` dataset is supplied. If
`caseid()` or required keep-variables are missing in the provided `survey()` dataset, warnings or errors are raised.

.SH EXAMPLES
.TP
.B Basic usage
.PP
.B sctocomments, path("C:\\Users\\AJolex\\Documents\\scto-field-comments") ///
	caseid("caseid") survey("survey_data.dta")
.PP
Processes all \fBComments*.csv\fR files in the `media` subfolder, merges by `caseid`, and saves as `comments.dta`.

.TP
.B With custom variables and stripgrp
.PP
.B sctocomments, path("C:\\Users\\AJolex\\Documents\\scto-field-comments") ///
	caseid("unique_id") keepvars("enum_id coord_id") ///
	survey("survey_data.dta") use("use_data.dta") stripgrp
.PP
Keeps `enum_id` and `coord_id`, uses `use_data.dta` for variable labels, strips `grp_` prefixes, and saves the output.

.SH AUTHOR
Developed by Aubrey Jolex.

.SH BUGS
If the `use()` dataset does not contain matching variables or if variable names are non-standard, label/value extraction may be incomplete.
Adjust the ado file loop limits or regex patterns when your `Field name` paths have more segments or different conventions.
