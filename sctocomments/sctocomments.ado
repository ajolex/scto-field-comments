capture program drop sctocomments
program define sctocomments, rclass
    version 17.0

    /*
    sctocomments: Collate SurveyCTO comments CSVs (Comments-*.csv) into a single Stata dataset

    Syntax:
        sctocomments, path(string) caseid(string) [mediafolder(string) filesub(string) out(string) survey(string) use(string) keepvars(string) stripgrp]

    Options:
        path(string)     : Base folder that contains the comments CSV folder (required)
        caseid(string)   : Variable name for unique case ID in the survey dataset (required)
        mediafolder(string): Name of subfolder containing CSV files (default: "media")
        filesub(string)  : Filename pattern for comment files (default: "Comments*.csv")
        out(string)      : Output filepath for the combined comments .dta (default: "comments.dta" inside path)
        survey(string)   : Full path to survey dataset to merge with (required if caseid is to be populated)
        use(string)      : Full path to main survey dataset for extracting variable values/labels
        keepvars(string) : Space-separated list of additional variables to keep (e.g., "fo_id"), defaults to "fo_id" if not specified
        stripgrp         : Option to remove "grp_" prefix from variable names (optional)
    */

    syntax , PATH(string) CASEID(string) [MEDIAFOLDER(string) FILESUB(string) OUT(string) SURVEY(string) USE(string) KEEPVARS(string) STRIPGRP]

    // Set defaults
    if "`filesub'" == "" local filesub "Comments*.csv"
    if "`out'" == "" local out "comments.dta"
    if "`mediafolder'" == "" local mediafolder "media"
    if "`keepvars'" == "" local keepvars "fo_id" // Default to fo_id 

    // Split keepvars into a local macro list
    local keepvars_list `keepvars'

    // Normalize path separators for portability
    local oslower = lower(c(os))
    local dirsep = cond(strpos("`oslower'", "windows"), "\", "/")
    local path_clean = subinstr("`path'", "/", "`dirsep'", .)
    local path_clean = subinstr("`path_clean'", "\", "`dirsep'", .)
    local mediafolder_clean = subinstr("`mediafolder'", "/", "`dirsep'", .)
    local mediafolder_clean = subinstr("`mediafolder_clean'", "\", "`dirsep'", .)

    // Trim trailing separators from base path (keep drive roots intact)
    while substr("`path_clean'", -1, 1) == "`dirsep'" & strlen("`path_clean'") > 1 {
        local path_clean = substr("`path_clean'", 1, strlen("`path_clean'") - 1)
    }

    // Handle mediafolder (avoid appending if path already ends with mediafolder)
    if "`mediafolder_clean'" == "" {
        local media "`path_clean'"
    }
    else if regexm("`mediafolder_clean'", "^[A-Za-z]:") | substr("`mediafolder_clean'", 1, 1) == "`dirsep'" {
        local media "`mediafolder_clean'"
    }
    else {
        if regexm("`path_clean'", "[/\\]`mediafolder_clean'$") {
            local media "`path_clean'"
        }
        else {
            local media "`path_clean'`dirsep'`mediafolder_clean'"
        }
    }

    // Check if directory exists
    di as txt "Checking directory: `media'"
    mata: st_local("dir_exists_flag", strofreal(direxists("`media'")))
    if "`dir_exists_flag'" != "1" {
        di as err "Directory not found: `media'"
        exit 198
    }

    // List files using dir command
    local current_dir "`c(pwd)'"
    cd "`media'"
    local filenames: dir . files "`filesub'"
    cd "`current_dir'"
    if `"`filenames'"' == "" {
        di as err "No files found matching `filesub' in `media'"
        exit 499
    }
    di as txt "Found files:"
    foreach f of local filenames {
        di as txt `"  "`f'"'
    }

    // Initialize combined dataset tempfile
    tempfile comments_combined
    preserve
    clear
    save "`comments_combined'", emptyok
    restore
    local combined_initialized 0
    
    foreach f of local filenames {
        // Strip quotes if present
        local f_clean `f'
        if substr(`"`f'"', 1, 1) == `"""' & substr(`"`f'"', -1, 1) == `"""' {
            local f_clean = substr(`"`f'"', 2, strlen(`"`f'"') - 2)
        }
        
        di as txt "Processing `f_clean'..."
        capture import delimited using `"`media'`dirsep'`f_clean'"', stripquotes(yes) bindquotes(strict) clear
        if _rc {
            di as err "  Failed to import `f_clean', skipping..."
            continue
        }

        // Normalize column names
        capture confirm variable Field_name
        if !_rc rename Field_name fieldname
        capture confirm variable field_name
        if !_rc rename field_name fieldname
        capture confirm variable Comment
        if !_rc rename Comment comment
        capture confirm variable comment

        // Handle v1/v2 columns if present
        capture confirm variable v1
        if !_rc {
            capture confirm variable v2
            if !_rc {
                rename v1 fieldname
                rename v2 comment
            }
        }

        capture confirm variable fieldname
        if _rc {
            di as txt "  File `f_clean' doesn't contain a fieldname column; skipping"
            continue
        }
        
        if _N == 0 {
            di as txt "  File `f_clean' is empty; skipping"
            continue
        }

        gen file = `"`f_clean'"'
        gen id = substr(file, 10, .)
        replace id = subinstr(id, ".csv", "", .)

        capture drop if fieldname == "Field name"
        capture drop if comment == ""

        if `combined_initialized' {
            capture append using "`comments_combined'", force
            if _rc {
                di as err "  Failed to append `f_clean' to combined dataset"
                continue
            }
        }
        else {
            local combined_initialized 1
        }

        capture save "`comments_combined'", replace
        if _rc {
            di as err "  Failed to save combined dataset after `f_clean'"
            exit 198
        }
    }

    if `combined_initialized' == 0 {
        di as err "No comments data found in any CSV files"
        exit 499
    }

    use "`comments_combined'", clear

    // Split fieldname by slash
    capture split fieldname, p(/)
    if _rc {
        di as err "Failed to split fieldname variable"
    }

    // Derive variable from the last non-empty component
    gen variable = ""
    forvalues i = 1/8 {
        forvalues k = 2/8 {
            replace variable = fieldname`i' if fieldname`k' == "" & fieldname`i' != ""
        }
    }
    replace variable = fieldname8 if fieldname8 != ""

    // Extract repeat instances for variables from a repeat group
    gen inst1 = ""
    gen inst2 = ""
    gen fieldname9 = ""
    forvalues i = 1/7 {
        local p = `i' + 1
        replace inst1 = regexs(1) if regexm(fieldname`i', "repeat_.+\[(\d+)\]") & inst1 == ""
        replace inst2 = regexs(1) if regexm(fieldname`p', "repeat_.+\[(\d+)\]") & inst1 != ""
    }

    // Construct variable with repeat instances
    gen repeat_inst = ""
    replace repeat_inst = variable + "_" + inst1 + "_" + inst2 if (inst1 != "" & inst2 != "")
    replace repeat_inst = variable + "_" + inst1 if inst2 == "" & repeat_inst == "" & inst1 != ""
    replace repeat_inst = variable if repeat_inst == ""
    drop variable
    rename repeat_inst variable

    // Apply stripgrp as the final step to ensure all grp_ prefixes are removed
    if "`stripgrp'" != "" {
        replace variable = subinstr(variable, "grp_", "", .)
    }

    keep if comment != "" & variable != ""

    // Generate key
    gen key = "uuid:" + id
    drop id

    // Merge with survey dataset to populate caseid, fo_id
    if "`survey'" == "" {
        di as err "survey option is required to populate caseid"
        exit 198
    }
    capture confirm file `"`survey'"'
    if _rc {
        di as err "Survey file not found: `survey'"
        exit 198
    }
    else {
        preserve
        use `"`survey'"', clear
        capture confirm variable `caseid'
        if _rc {
            di as err "Variable `caseid' not found in survey dataset"
            exit 198
        }
        // Check for keepvars in survey dataset, issue warning if absent
        local keepvars_count : word count `keepvars_list'
        forvalues i = 1/`keepvars_count' {
            local var = word("`keepvars_list'", `i')
            capture confirm variable `var'
            if _rc {
                di as warn "Variable `var' not found in survey dataset, will be empty"
            }
        }
        restore
        merge m:1 key using `"`survey'"', keep(match) nogen
        // Always generate caseid and keepvars, populate if present
        replace `caseid' = `caseid' if !missing(`caseid')
        foreach var of local keepvars_list {
            capture gen `var' = ""
            if _rc {
                replace `var' = "" if missing(`var')
            }
            capture confirm variable `var'
            if !_rc {
                replace `var' = `var' if !missing(`var')
            }
        }
    }

    // Pull values and labels if use() provided
    tempvar num_val str_val label_val
    gen `num_val' = .
    gen `str_val' = ""
    gen `label_val' = ""

    if "`use'" != "" {
        capture confirm file `"`use'"'
        if _rc == 0 {
            tempfile current_data
            save "`current_data'", replace
            use `"`use'"', clear
            ds, has(type numeric)
            local num_vars `r(varlist)' // List of all numeric vars
            ds, has(type string)
            local str_vars `r(varlist)' // List of all string vars
            merge 1:m key using "`current_data'", keep(match using) nogen
        }
        else {
            di as err "Warning: file specified in use() not found: `use'"
        }
    }
    else {
        // If no use() provided, use all variables from current dataset
        ds, has(type numeric)
        local num_vars `r(varlist)' // List of all numeric vars
        ds, has(type string)
        local str_vars `r(varlist)' // List of all string vars
    }

    // Loop through each observation to assign values and labels
    forval i = 1/`=_N' {
        local varname = variable[`i']
        // Check numeric variables
        foreach num_var of local num_vars {
            if "`varname'" == "`num_var'" {
                quietly replace `num_val' = `num_var'[`i'] in `i'
                quietly replace `label_val' = "`: var label `num_var''" in `i'
                continue
            }
        }
        // Check string variables
        foreach str_var of local str_vars {
            if "`varname'" == "`str_var'" {
                quietly replace `str_val' = `str_var'[`i'] in `i'
                quietly replace `label_val' = "`: var label `str_var''" in `i'
                continue
            }
        }
    }

    tostring `num_val', replace force
    replace `str_val' = `num_val' if `str_val' == "" & `num_val' != "."
    drop `num_val'
    rename `str_val' value
    rename `label_val' label_val

    // Keep only the specified variables
    local keep_list `caseid' `keepvars_list' variable comment value label_val
    keep `keep_list'

    // Save output
    local outfile "`out'"
    if !regexm("`outfile'", "^[A-Za-z]:") & !inlist(substr("`outfile'", 1, 1), "/", "\") {
        local outfile "`path_clean'`dirsep'`out'"
    }
    if "`dirsep'" == "\" {
        local outfile = subinstr("`outfile'", "/", "\", .)
    }

    capture save `"`outfile'"', replace
    if _rc {
        di as err "Failed to save output file: `outfile'"
        exit 198
    }

    local obs_count = _N
    di as txt "Saved combined comments to `outfile'"
    di as txt "Dataset contains `obs_count' comment observations"

end