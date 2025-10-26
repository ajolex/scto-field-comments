.SS sctocomments
.SP 1
.SH NAME
sctocomments \- Collate SurveyCTO comments CSVs into a single Stata dataset
.SP 1
.SH SYNOPSIS
.TP
.B sctocomments, path(string) [mediafolder(string) filesub(string) out(string) survey(string) use(string)]
.SH DESCRIPTION
The \fBsctocomments\fR command imports SurveyCTO comments CSV exports (files named like \fBComments-<uuid>.csv\fR) found in the
subfolder specified by \fBmediafolder()\fR under the folder provided in \fBpath()\fR. It collates them into a single Stata dataset and
saves the result to \fBout()\fR inside the \fBpath()\fR folder.

.SH OPTIONS
.TP
.B path(string)
Base project folder that contains the CSV files subfolder. Required.
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

.SH EXAMPLE
Suppose your project folder is \fBC:/Projects/PSPS\fR and the comments CSVs are in\
\fBC:/Projects/PSPS/4_data/2_survey/media\fR. To build the combined comments dataset:

.TP
.B sctocomments, path("C:/Projects/PSPS")

With custom folder name:

.TP
.B sctocomments, path("C:/Projects/PSPS") mediafolder("comments")

To merge with a survey dataset:

.TP
.B sctocomments, path("C:/Projects/PSPS") survey("C:/Projects/PSPS/my_survey_data.dta")

To include variable values from a specific survey dataset:

.TP
.B sctocomments, path("C:/Projects/PSPS") use("C:/Projects/PSPS/main_survey.dta")

.SH AUTHOR
Based on code by the repository owner. Generated helper by automated refactor.

.SH BUGS
This command makes a best-effort attempt to extract variable values and labels; if your
survey variables aren't present in memory or in a linked household dataset, the value/label
fields may be empty. In that case run the command after loading the main survey dataset.
