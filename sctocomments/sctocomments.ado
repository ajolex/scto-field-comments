capture program drop sctocomments
program define sctocomments, rclass
    version 17.0

    /*
    sctocomments: Collate SurveyCTO comments CSVs (Comments-*.csv) into a single Stata dataset

    Syntax:
        sctocomments, path(string) [filesub(string) out(string)]

    Options:
        path(string)     : base folder that contains the comments CSV folder (required)
        mediafolder(string): name of subfolder containing CSV files (default: "media")
        filesub(string)  : filename pattern for comment files (default: "Comments*.csv")
        out(string)      : output filepath for the combined comments .dta (default: "comments.dta" inside path)
        survey(string)   : full path to survey dataset to merge with (optional)
        use(string)      : full path to main survey dataset for extracting variable values/labels

    Notes:
      - This ado expects SurveyCTO's exported comments CSV files (names like Comments-<uuid>.csv) to live in
        <path>/<mediafolder>. It will import them, extract the uuid from the filename,
        and create a dataset with variables: caseid fo_id fc_id variable comment value label_val (when available).
      - Provide `path()` to point to your project folder and `mediafolder()` for the subfolder name.
    */

    syntax , PATH(string) [MEDIAFOLDER(string) FILESUB(string) ///
        OUT(string) SURVEY(string) USE(string)]

    // set defaults
    if "`mediafolder'" == "" local mediafolder "media"
    if "`filesub'" == "" local filesub "Comments*.csv"
    if "`out'" == "" local out "comments.dta"
    
    // build the CSV files directory
    local media = "`path'" + "/" + "`mediafolder'"

    // check directory exists
    capture confirm dir "`media'"
    if _rc {
        di as err "directory not found: `media'"
        exit 198
    }

    // list files using full path (avoid cd issues)
    local pattern "`filesub'"
    local filenames: dir "`media'" files "`pattern'"
    if "`filenames'" == "" {
        di as err "no files found matching `pattern' in `media'"
        exit 499
    }

    // store current working directory
    local original_dir = c(pwd)
    
    tempfile comments_combined
    preserve
    clear
    save `comments_combined', emptyok
    restore

    foreach f of local filenames {
        di as txt "processing `f'..."
        
        // use full path for file import
        local fullpath "`media'/`f'"
        
        // safer import with better error handling
        capture import delimited using "`fullpath'", varnames(1) stringcols(_all) clear
        if _rc {
            di as txt "  trying alternative import method..."
            capture import delimited using "`fullpath'", varnames(0) stringcols(_all) clear
            if _rc {
                di as err "  failed to import `f', skipping..."
                continue
            }
        }

        // normalize column names to `fieldname' and `comment'
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

        // ensure we have the expected vars
        capture confirm variable fieldname
        if _rc {
            di as txt "  file `f' doesn't contain a fieldname column; skipping"
            continue
        }
        
        // ensure we have data
        if _N == 0 {
            di as txt "  file `f' is empty; skipping"
            continue
        }

        // create file and id variables
        gen file = "`f'"
        // extract uuid part from filename (remove "Comments-" prefix and ".csv" suffix)
        local fname = "`f'"
        // in-stata string manipulation
        gen id = substr(file, 10, .)
        replace id = subinstr(id, ".csv", "", .)

        // drop any header-like rows that some exports include
        capture drop if fieldname=="Field name"
        capture drop if comment==""

        // safely append to combined tempfile
        capture append using `comments_combined', force
        if _rc {
            di as err "  failed to append `f' to combined dataset"
            continue
        }
        
        capture save `comments_combined', replace
        if _rc {
            di as err "  failed to save combined dataset after `f'"
            exit 198
        }
    }

    // load combined dataset
    capture use `comments_combined', clear
    if _rc {
        di as err "failed to load combined comments dataset"
        exit 198
    }
    
    // check if we have any data
    if _N == 0 {
        di as err "no comments data found in any CSV files"
        exit 499
    }

    // split fieldname by slash into parts
    capture split fieldname, parse("/")
    if _rc {
        di as err "failed to split fieldname variable"
    }

    // create variable name candidate: pick the last non-empty split component
    gen variable = ""
    forvalues i = 1/20 {
        capture confirm variable fieldname`i'
        if !_rc {
            replace variable = fieldname`i' if fieldname`i' != "" & variable==""
        }
    }

    // try to extract repeat instance numbers (if present) from components
    gen inst1 = ""
    gen inst2 = ""
    forvalues i = 1/19 {
        capture confirm variable fieldname`i'
        if !_rc {
            local p = `i' + 1
            capture confirm variable fieldname`p'
            if !_rc {
                replace inst1 = regexs(1) if regexm(fieldname`i', "repeat_.+\\[(\\d+)\\]") & inst1==""
                replace inst2 = regexs(1) if regexm(fieldname`p', "repeat_.+\\[(\\d+)\\]") & inst1!=""
            }
        }
    }

    gen repeat_inst = ""
    replace repeat_inst = variable + "_" + inst1 + "_" + inst2 if (inst1!="" & inst2!="")
    replace repeat_inst = variable + "_" + inst1 if inst2=="" & repeat_inst=="" & inst1!=""
    replace repeat_inst = variable if repeat_inst==""

    drop variable
    rename repeat_inst variable

    keep if comment!="" & variable!=""

    // create a key similar to your workflow: uuid:<id>
    gen key = "uuid:" + id

    // attempt to merge with survey data (if provided)
    if "`survey'" != "" {
        capture confirm file `"`survey'"'
        if _rc == 0 {
            merge m:1 key using `"`survey'"', keep(match using) nogen
        }
        else {
            di as err "warning: survey file not found: `survey'"
        }
    }

    // attempt to pull values and labels for variables named in `variable'
    tempvar num_val str_val label_val
    gen `num_val' = .
    gen `str_val' = ""
    gen `label_val' = ""

    // if use() option provided, merge with that dataset first
    if "`use'" != "" {
        capture confirm file `"`use'"'
        if _rc == 0 {
            tempfile current_data
            save `current_data', replace
            use `"`use'"', clear
            merge 1:m key using `current_data', keep(match using) nogen
        }
        else {
            di as err "warning: file specified in use() not found: `use'"
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
    replace `str_val' = `num_val' if `str_val'=="" & `num_val'!="."
    drop `num_val'
    rename `str_val' value
    rename `label_val' label_val

    // save output
    local outfile = "`path'/`out'"
    capture save `"`outfile'"', replace
    if _rc {
        di as err "failed to save output file: `outfile'"
        exit 198
    }

    di as txt "saved combined comments to `outfile'"
    di as txt "dataset contains `=_N' comment observations"
    
    // restore original directory if changed
    quietly cd "`original_dir'"

end
