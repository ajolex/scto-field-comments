// Example: run sctocomments on a project folder
// Edit the path() to your project root (the folder that contains 4_data/2_survey)

clear all
set more off

// change this to your path
local mypath "C:/path/to/your/project"

// basic usage (looks for CSV files in media subfolder)
sctocomments, path("`mypath'")

// with custom folder name for CSV files
// sctocomments, path("`mypath'") mediafolder("comments")

// with survey dataset for merging
// sctocomments, path("`mypath'") survey("`mypath'/my_survey_data.dta")

// with main survey dataset for variable values
// sctocomments, path("`mypath'") use("`mypath'/main_survey.dta")

use "`mypath'/comments.dta", clear
describe
list in 1/10
