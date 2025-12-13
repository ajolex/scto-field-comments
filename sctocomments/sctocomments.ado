capture program drop sctocomments
program define sctocomments, rclass
    version 17.0

    /*
    sctocomments: Collate SurveyCTO comments CSVs (Comments-*.csv) into a single Stata dataset

    Syntax:
        sctocomments, path(string) [mediafolder(string) filesub(string) out(string) survey(string) use(string) keepvars(string) stripgrp nosave]

    Options:
        path(string)     : Base folder that contains the comments CSV folder (required)
        mediafolder(string): Name of subfolder containing CSV files (default: "media")
        filesub(string)  : Filename pattern for comment files (default: "Comments*.csv")
        out(string)      : Output filepath for the combined comments .dta (default: "comments.dta" inside path)
        survey(string)   : Full path to survey dataset to merge with (optional, for adding caseid)
        use(string)      : Full path to dataset for extracting variable values/labels (optional, defaults to survey if not specified)
        keepvars(string) : Space-separated list of additional variables to keep from survey (default: "")
        stripgrp         : Option to remove "grp_" prefix from variable names (optional)
        nosave           : Do not save output file, only load in memory (optional)
    */

    syntax , PATH(string) [MEDIAFOLDER(string) FILESUB(string) OUT(string) SURVEY(string) USE(string) KEEPVARS(string) STRIPGRP NOSAVE]

    // Set defaults
    if "`filesub'" == "" local filesub "Comments*.csv"
    if "`out'" == "" local out "comments.dta"
    if "`mediafolder'" == "" local mediafolder "media"
    
    // use() and survey() are aliases - use whichever is provided (survey takes precedence)
    if "`survey'" == "" & "`use'" != "" {
        local survey "`use'"
    }

    // Normalize path separators for portability
    local dirsep = cond("`c(os)'" == "Windows", "\", "/")
    local path_clean = subinstr(subinstr("`path'", "/", "`dirsep'", .), "\", "`dirsep'", .)
    local mediafolder_clean = subinstr(subinstr("`mediafolder'", "/", "`dirsep'", .), "\", "`dirsep'", .)

    // Trim trailing separators from base path
    while substr("`path_clean'", -1, 1) == "`dirsep'" & strlen("`path_clean'") > 3 {
        local path_clean = substr("`path_clean'", 1, strlen("`path_clean'") - 1)
    }

    // Construct media folder path
    if regexm("`mediafolder_clean'", "^[A-Za-z]:") | substr("`mediafolder_clean'", 1, 1) == "`dirsep'" {
        local media "`mediafolder_clean'"
    }
    else {
        local media "`path_clean'`dirsep'`mediafolder_clean'"
    }

    // Check if directory exists
    capture confirm file "`media'`dirsep'."
    if _rc {
        di as err "Directory not found: `media'"
        exit 601
    }

    // List comment CSV files
    local current_dir "`c(pwd)'"
    quietly cd "`media'"
    local filenames: dir . files "`filesub'"
    quietly cd "`current_dir'"
    
    if `"`filenames'"' == "" {
        di as err "No files matching `filesub' found in `media'"
        exit 601
    }
    
    di as txt "{txt}Found " as res word count `"`filenames'"' as txt " comment file(s) in: {res}`media'"

    // Initialize combined dataset tempfile
    tempfile comments_combined
    local combined_initialized 0
    
    foreach f of local filenames {
        // Strip quotes if present
        local f_clean = subinstr(`"`f'"', `"""', "", .)
        
        quietly {
            capture import delimited using `"`media'`dirsep'`f_clean'"', ///
                stripquotes(yes) bindquotes(strict) clear
            if _rc {
                noisily di as txt "  {txt}Skipping {res}`f_clean' {txt}(import failed)"
                continue
            }

            // Normalize column names (handle various SurveyCTO export formats)
            capture confirm variable Field_name
            if !_rc rename Field_name fieldname
            capture confirm variable field_name
            if !_rc rename field_name fieldname
            capture confirm variable Comment
            if !_rc rename Comment comment
            
            // Handle v1/v2 columns (old format)
            capture confirm variable v1
            if !_rc {
                capture confirm variable v2
                if !_rc {
                    rename v1 fieldname
                    rename v2 comment
                }
            }

            // Verify required columns exist
            capture confirm variable fieldname comment
            if _rc {
                noisily di as txt "  {txt}Skipping {res}`f_clean' {txt}(missing fieldname or comment column)"
                continue
            }
            
            // Normalize comment to string to avoid type mismatches during append
            capture confirm string variable comment
            if _rc tostring comment, replace
            
            // Skip if no data
            if _N == 0 {
                noisily di as txt "  {txt}Skipping {res}`f_clean' {txt}(empty)"
                continue
            }

            // Generate metadata columns
            gen str file = `"`f_clean'"'
            gen str uuid = substr(file, 10, .)
            replace uuid = subinstr(uuid, ".csv", "", .)

            // Drop header rows and empty comments
            drop if inlist(fieldname, "Field name", "")
            drop if comment == ""
            
            if _N == 0 {
                noisily di as txt "  {txt}Skipping {res}`f_clean' {txt}(no valid comments)"
                continue
            }

            // Append to combined dataset
            if `combined_initialized' {
                append using "`comments_combined'"
            }
            else {
                local combined_initialized 1
            }

            save "`comments_combined'", replace
        }
        di as txt "  {txt}Processed {res}`f_clean' {txt}({res}" _N " {txt}comments)"
    }

    if `combined_initialized' == 0 {
        di as err "No valid comments data found in any CSV files"
        exit 601
    }

    use "`comments_combined'", clear
    di as txt "{txt}Combined {res}" _N " {txt}comments from {res}" wordcount("`filenames'") " {txt}file(s)"

    // Save raw comments data before processing
    local rawfile "comments_raw.dta"
    local rawpath "`path_clean'`dirsep'`rawfile'"
    quietly save "`rawpath'", replace
    di as txt "{txt}Saved raw comments to: {res}`rawpath'"

    // Parse fieldname to extract variable name and repeat instances
    // Split fieldname by slash to extract hierarchy (e.g., group/repeat/field)
    quietly split fieldname, p(/) gen(fld)
    
    // Find the last non-empty component (the actual variable name)
    quietly ds fld*
    local max_fld: word count `r(varlist)'
    gen str variable = ""
    forvalues i = `max_fld'(-1)1 {
        quietly replace variable = fld`i' if variable == "" & fld`i' != ""
    }
    
    // Extract repeat instance numbers from fieldname components
    gen str inst1 = ""
    gen str inst2 = ""
    forvalues i = 1/`max_fld' {
        quietly replace inst1 = regexs(1) if regexm(fld`i', "repeat_.+\[(\d+)\]") & inst1 == ""
        local j = `i' + 1
        if `j' <= `max_fld' {
            quietly replace inst2 = regexs(1) if regexm(fld`j', "repeat_.+\[(\d+)\]") & inst1 != "" & inst2 == ""
        }
    }
    
    // Construct variable name with repeat instance identifiers
    quietly replace variable = variable + "_" + inst1 + "_" + inst2 if inst1 != "" & inst2 != ""
    quietly replace variable = variable + "_" + inst1 if inst1 != "" & inst2 == ""
    
    // Apply stripgrp option to remove "grp_" prefix
    if "`stripgrp'" != "" {
        quietly replace variable = regexr(variable, "^grp_", "")
    }
    
    // Drop processing variables
    drop fld* inst1 inst2
    
    // Keep only valid observations
    keep if comment != "" & variable != ""
    
    // Generate key for merging
    gen str key = "uuid:" + uuid
    drop uuid file

    // Merge with survey dataset if specified
    if "`survey'" != "" {
        capture confirm file `"`survey'"'
        if _rc {
            di as err "Survey file not found: `survey'"
            exit 601
        }
        
        tempfile comments_data
        quietly save "`comments_data'"
        
        // Load survey data and identify caseid variable
        quietly use `"`survey'"', clear
        quietly ds
        local survey_vars `r(varlist)'
        
        // Try to identify caseid variable
        local caseid_var ""
        foreach v in caseid hhid instanceid submissionid key {
            capture confirm variable `v'
            if !_rc {
                local caseid_var `v'
                continue, break
            }
        }
        
        // Check if key exists for merging
        capture confirm variable key
        if _rc {
            di as err "Survey dataset must contain a 'key' variable for merging"
            exit 109
        }
        
        // Build list of variables to keep from survey
        local merge_vars "key `caseid_var' `keepvars'"
        local merge_vars: list uniq merge_vars
        
        // Verify keepvars exist
        foreach v of local keepvars {
            capture confirm variable `v'
            if _rc {
                di as txt "{txt}Warning: Variable {res}`v' {txt}not found in survey dataset"
                local merge_vars: list merge_vars - v
            }
        }
        
        keep `merge_vars'
        
        // Merge comments with survey data
        quietly merge 1:m key using "`comments_data'", keep(match) nogen
        
        // Extract values and labels for commented variables
        quietly use `"`survey'"', clear
        
        // Get numeric and string variable lists
        quietly ds, has(type numeric)
        local num_vars `r(varlist)'
        quietly ds, has(type string)
        local str_vars `r(varlist)'
        
        quietly merge 1:m key using "`comments_data'", keep(match using) nogen
        
        // Create value and label columns using frval() and variable labels
        gen str value = ""
        gen str label_val = ""
        
        foreach v of local num_vars {
            capture confirm variable `v'
            if !_rc {
                quietly replace value = string(`v') if variable == "`v'" & missing(value)
                local vlab: variable label `v'
                if `"`vlab'"' != "" {
                    quietly replace label_val = `"`vlab'"' if variable == "`v'"
                }
            }
        }
        
        foreach v of local str_vars {
            capture confirm variable `v'
            if !_rc {
                quietly replace value = `v' if variable == "`v'" & missing(value)
                local vlab: variable label `v'
                if `"`vlab'"' != "" {
                    quietly replace label_val = `"`vlab'"' if variable == "`v'"
                }
            }
        }
        
        // Keep only relevant columns
        local final_vars "`caseid_var' `keepvars' variable comment value label_val"
        local final_vars: list uniq final_vars
        keep `final_vars'
        
        di as txt "{txt}Merged with survey data: {res}" _N " {txt}comments matched"
    }
    else {
        // No survey merge - keep basic columns
        order variable comment fieldname key
        di as txt "{txt}No survey data merged (use survey() option to add caseid and values)"
    }

    // Save output dataset
    if "`nosave'" == "" {
        local outfile "`out'"
        if !regexm("`outfile'", "^[A-Za-z]:") & !inlist(substr("`outfile'", 1, 1), "/", "\") {
            local outfile "`path_clean'`dirsep'`out'"
        }
        
        quietly save `"`outfile'"', replace
        
        local obs_count = _N
        di as txt "{txt}Saved final dataset to: {res}`outfile'"
        di as txt "{txt}Dataset contains {res}`obs_count' {txt}comment observation(s)"
    }
    else {
        di as txt "{txt}Data loaded in memory (nosave option specified)"
        di as txt "{txt}Dataset contains {res}" _N " {txt}comment observation(s)"
    }

end