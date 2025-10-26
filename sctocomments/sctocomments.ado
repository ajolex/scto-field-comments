capture program drop sctocomments
program define sctocomments, rclass
    version 17.0

    /*
    sctocomments: Collate SurveyCTO comments CSVs (Comments-*.csv) into a single Stata dataset

    Syntax:
        sctocomments, path(string) [mediafolder(string) filesub(string) out(string) survey(string) use(string)]

    Options:
        path(string)     : base folder that contains the comments CSV folder (required)
        mediafolder(string): name of subfolder containing CSV files (default: "media")
        filesub(string)  : filename pattern for comment files (default: "Comments*.csv")
        out(string)      : output filepath for the combined comments .dta (default: "comments.dta" inside path)
        survey(string)   : full path to survey dataset to merge with (optional)
        use(string)      : full path to main survey dataset for extracting variable values/labels
    */

    syntax , PATH(string) [MEDIAFOLDER(string) FILESUB(string) OUT(string) SURVEY(string) USE(string)]

    // Set defaults
    if "`filesub'" == "" local filesub "Comments*.csv"
    if "`out'" == "" local out "comments.dta"
    if "`mediafolder'" == "" local mediafolder "media"
    
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
        // Check if path_clean already ends with mediafolder_clean
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

    // List files using dir command to match working do-file
    local current_dir "`c(pwd)'"
    cd "`media'"
    local filenames: dir . files "`filesub'"
    cd "`current_dir'"
    if `"`filenames'"' == "" {
        di as err "No files found matching `filesub' in `media'"
        exit 499
    }
    
    // Debug: Display each filename individually
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
        // Strip quotes if present to handle quoted filenames
        local f_clean `f'
        if substr(`"`f'"', 1, 1) == `"""' & substr(`"`f'"', -1, 1) == `"""' {
            local f_clean = substr(`"`f'"', 2, strlen(`"`f'"') - 2)
        }
        
        di as txt "Processing `f_clean'..."
        
        // Import using compound quotes to match working do-file
        capture import delimited using `"`media'`dirsep'`f_clean'"', stripquotes(yes) bindquotes(strict) clear
        if _rc {
            di as err "  Failed to import `f_clean', skipping..."
            continue
        }

        // Normalize column names to fieldname and comment
        capture confirm variable Field_name
        if !_rc rename Field_name fieldname
        capture confirm variable field_name
        if !_rc rename field_name fieldname
        capture confirm variable Comment
        if !_rc rename Comment comment
        capture confirm variable comment

        // If import created v1/v2 columns, rename them
        capture confirm variable v1
        if !_rc {
            capture confirm variable v2
            if !_rc {
                rename v1 fieldname
                rename v2 comment
            }
        }

        // Ensure we have the expected vars
        capture confirm variable fieldname
        if _rc {
            di as txt "  File `f_clean' doesn't contain a fieldname column; skipping"
            continue
        }
        
        // Ensure we have data
        if _N == 0 {
            di as txt "  File `f_clean' is empty; skipping"
            continue
        }

        // Create file and id variables to match working do-file
        gen file = `"`f_clean'"'
        gen id = substr(file, 10, .)
        replace id = subinstr(id, ".csv", "", .)

        // Drop any header-like rows
        capture drop if fieldname == "Field name"
        capture drop if comment == ""

        // Append to combined dataset
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

    // Load combined dataset
    use "`comments_combined'", clear

    // Split fieldname by slash into parts
    capture split fieldname, parse("/")
    if _rc {
        di as err "Failed to split fieldname variable"
    }

    // Create variable name from last non-empty split component
    gen variable = ""
    forvalues i = 1/20 {
        capture confirm variable fieldname`i'
        if !_rc {
            replace variable = fieldname`i' if fieldname`i' != "" & variable == ""
        }
    }

    // Extract repeat instance numbers
    gen inst1 = ""
    gen inst2 = ""
    forvalues i = 1/19 {
        capture confirm variable fieldname`i'
        if !_rc {
            local p = `i' + 1
            capture confirm variable fieldname`p'
            if !_rc {
                replace inst1 = regexs(1) if regexm(fieldname`i', "repeat_.+\\[(\\d+)\\]") & inst1 == ""
                replace inst2 = regexs(1) if regexm(fieldname`p', "repeat_.+\\[(\\d+)\\]") & inst1 != ""
            }
        }
    }

    gen repeat_inst = ""
    replace repeat_inst = variable + "_" + inst1 + "_" + inst2 if (inst1 != "" & inst2 != "")
    replace repeat_inst = variable + "_" + inst1 if inst2 == "" & inst1 != ""
    replace repeat_inst = variable if repeat_inst == ""

    drop variable
    rename repeat_inst variable

    keep if comment != "" & variable != ""

    // Create key to match working do-file
    gen key = "uuid:" + id

    // Merge with survey data if provided
    if "`survey'" != "" {
        capture confirm file `"`survey'"'
        if _rc == 0 {
            merge m:1 key using `"`survey'"', keep(match) nogen
        }
        else {
            di as err "Warning: survey file not found: `survey'"
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
            merge 1:m key using "`current_data'", keep(match using) nogen
        }
        else {
            di as err "Warning: file specified in use() not found: `use'"
        }
    }

    ds, has(type numeric)
    local numeric_vars `r(varlist)'
    ds, has(type string)
    local string_vars `r(varlist)'

    forvalues i = 1/`=_N' {
        local varname = variable[`i']
        foreach nv of local numeric_vars {
            if "`nv'" == "`varname'" {
                quietly replace `num_val' = `nv'[`i'] in `i'
                quietly replace `label_val' = "`: var label `nv''" in `i'
            }
        }
        foreach sv of local string_vars {
            if "`sv'" == "`varname'" {
                quietly replace `str_val' = `sv'[`i'] in `i'
                quietly replace `label_val' = "`: var label `sv''" in `i'
            }
        }
    }

    tostring `num_val', replace force
    replace `str_val' = `num_val' if `str_val' == "" & `num_val' != "."
    drop `num_val'
    rename `str_val' value
    rename `label_val' label_val

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