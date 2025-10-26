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

    syntax , PATH(string) [MEDIAFOLDER(string "media") FILESUB(string "Comments*.csv") ///
        OUT(string "comments.dta") SURVEY(string) USE(string)]

    // build the CSV files directory
    local media = "`path'" + "/" + "`mediafolder'"

    // check directory
    capture cd "`media'"
    if _rc {
        di as err "could not change to media directory: `media'"
        exit 198
    }

    // list files
    local pattern "`filesub'"
    local filenames: dir . files "`pattern'"
    if "`filenames'" == "" {
        di as err "no files found matching `pattern' in `media'"
        exit 499
    }

    tempfile comments_combined
    preserve
    clear
    save `comments_combined', emptyok
    restore

    foreach f of local filenames {
        di as txt "processing `f'..."

        // import CSV using first line as variable names where possible
        capture noisily import delimited using "`f'", varnames(1) stringcols(_all) clear
        if _rc {
            // fallback: import without varnames
            capture noisily import delimited using "`f'", varnames(0) stringcols(_all) clear
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
            di as err "imported file `f' doesn't contain a fieldname column; skipping"
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

        // append to combined tempfile
        append using `comments_combined', force
        save `comments_combined', replace
    }

    // load combined
    use `comments_combined', clear

    // split fieldname by slash into parts
    capture noisily split fieldname, parse("/")

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
    save `"`outfile'"', replace

    di as txt "saved combined comments to `outfile'"

end
