{smcl}
{* *! version 2.0  12dec2025}{...}
{vieweralsosee "[D] import delimited" "help import delimited"}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{viewerjumpto "Syntax" "sctocomments##syntax"}{...}
{viewerjumpto "Description" "sctocomments##description"}{...}
{viewerjumpto "Options" "sctocomments##options"}{...}
{viewerjumpto "Examples" "sctocomments##examples"}{...}
{viewerjumpto "Stored results" "sctocomments##results"}{...}
{viewerjumpto "Author" "sctocomments##author"}{...}
{title:Title}

{phang}
{bf:sctocomments} {hline 2} Collate SurveyCTO comments CSVs into a single Stata dataset


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmdab:sctocomments}
{cmd:,} {opt path(string)}
[{opt mediafolder(string)}
{opt filesub(string)}
{opt out(string)}
{opt survey(string)}
{opt use(string)}
{opt keepvars(string)}
{opt stripgrp}
{opt nosave}]


{marker description}{...}
{title:Description}

{pstd}
{cmd:sctocomments} imports SurveyCTO comments CSV exports (files named like 
{it:Comments-<uuid>.csv}) found in the subfolder specified by {opt mediafolder()} 
under the folder provided in {opt path()}. It collates them into a single Stata 
dataset, optionally merges with a survey dataset to bring in case IDs, variable 
values, and labels.

{pstd}
The command extracts variable names from the last non-empty segment of the 
{it:Field name} path present in SurveyCTO exports. It handles repeat group indices 
(appending them to variable names) and extracts values/labels when a {opt survey()} 
dataset is supplied.


{marker options}{...}
{title:Options}

{phang}
{opt path(string)} specifies the base project folder that contains the CSV files 
subfolder. This is required.

{phang}
{opt mediafolder(string)} specifies the name of the subfolder containing comment 
CSV files. Default is {bf:media}. Can be a relative path or absolute path.

{phang}
{opt filesub(string)} specifies the filename pattern for the comment CSVs. 
Default is {bf:Comments*.csv}.

{phang}
{opt out(string)} specifies the output filename to save (within {opt path()}). 
Default is {bf:comments.dta}. Absolute paths are honored as-is.

{phang}
{opt survey(string)} specifies the full path to the survey dataset to merge with. 
Must contain a {bf:key} variable. The command auto-detects common case ID variables 
(caseid, hhid, instanceid, submissionid) and extracts variable values and labels. 
Optional.

{phang}
{opt use(string)} is an alias for {opt survey()}. Provided for backward compatibility.

{phang}
{opt keepvars(string)} specifies a space-separated list of additional variables 
to keep from the survey dataset (e.g., {bf:fo_id enum_name}). Optional.

{phang}
{opt stripgrp} is an option flag to remove the prefix {bf:grp_} from derived 
variable names.

{phang}
{opt nosave} loads the combined dataset in memory without saving to disk. 
Useful for inspection or piping to other commands.


{marker examples}{...}
{title:Examples}

{pstd}Basic usage (no survey merge):{p_end}
{phang2}{cmd:. sctocomments, path("C:/Users/you/project")}{p_end}
{pstd}Processes all {it:Comments*.csv} files in the {it:media} subfolder and saves as {it:comments.dta}.

{pstd}With survey merge:{p_end}
{phang2}{cmd:. sctocomments, path("C:/Users/you/project") survey("survey_data.dta")}{p_end}
{pstd}Processes comments and merges with survey data, auto-detecting case ID and extracting variable values/labels.

{pstd}With custom variables and options:{p_end}
{phang2}{cmd:. sctocomments, path("C:/Users/you/project") survey("survey_data.dta") keepvars("fo_id enum_name") stripgrp}{p_end}
{pstd}Keeps {it:fo_id} and {it:enum_name} from survey, strips {it:grp_} prefixes from variable names.

{pstd}Load in memory without saving:{p_end}
{phang2}{cmd:. sctocomments, path("C:/Users/you/project") nosave}{p_end}
{pstd}Processes comments and loads in memory for inspection without saving to disk.


{marker results}{...}
{title:Output Files}

{pstd}
The command creates two files in the {opt path()} directory:

{phang2}{bf:comments_raw.dta} - Raw comments before processing (for debugging){p_end}
{phang2}{bf:comments.dta} - Final processed comments (or custom name via {opt out()}){p_end}


{marker author}{...}
{title:Author}

{pstd}
Developed by Aubrey Jolex.

{pstd}
Version 2.0 (December 2025) - Simplified syntax, auto-detection of case IDs, performance optimizations.

{pstd}
For issues or contributions, visit: {browse "https://github.com/ajolex/scto-field-comments"}
