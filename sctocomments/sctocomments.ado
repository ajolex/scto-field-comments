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

    // Set maxvar high enough for large surveys before any data is loaded
    if c(maxvar) < 32000 {
        quietly set maxvar 32000
    }

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
    
    di as txt "{txt}Found " as res `=wordcount(`"`filenames'"')' as txt " comment file(s) in: {res}`media'"

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
    di as txt "{txt}Combined {res}" _N " {txt}comments from {res}" wordcount(`"`filenames'"') " {txt}file(s)"

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
    // Also capture outer respondent_availability[N] index as N-1 (SurveyCTO 0-indexes this level)
    gen str _inst0 = ""
    gen str _inst_parent = ""
    gen str inst1 = ""
    gen str inst2 = ""
    forvalues i = 1/`max_fld' {
        quietly replace _inst0 = string(real(regexs(1)) - 1) if regexm(fld`i', "respondent_availability\[([0-9]+)\]") & _inst0 == ""
        quietly replace inst1 = regexs(1) if regexm(fld`i', "repeat_.+\[([0-9]+)\]") & inst1 == ""
        local j = `i' + 1
        if `j' <= `max_fld' {
            quietly replace inst2 = regexs(1) if regexm(fld`j', "repeat_.+\[([0-9]+)\]") & inst1 != "" & inst2 == ""
        }
    }
    forvalues i = 2/`max_fld' {
        local p = `i' - 1
        quietly replace _inst_parent = regexs(1) if variable == fld`i' & _inst_parent == "" & regexm(fld`p', "^.+\[([0-9]+)\]$")
    }
    
    // Construct variable name with repeat instance identifiers
    quietly replace variable = variable + "_" + inst1 + "_" + inst2 if inst1 != "" & inst2 != ""
    quietly replace variable = variable + "_" + inst1 if inst1 != "" & inst2 == ""
    
    // Apply stripgrp option to remove "grp_" prefix
    if "`stripgrp'" != "" {
        quietly replace variable = regexr(variable, "^grp_", "")
    }
    
    // Drop processing variables (keep _inst0/_inst_parent for value-extraction fallback)
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
        
        // Merge comments with survey data (1:m — one survey row to many comments)
        // keep(match using): keep matched rows AND unmatched comments so no
        // comment is lost. Unmatched comments get missing caseid/keepvars.
        quietly merge 1:m key using "`comments_data'", keep(match using) nogen
        
        // Flag rows that couldn't be matched to survey
        gen byte flag_no_survey_match = missing(`caseid_var') | `caseid_var'==""
        quietly count if flag_no_survey_match
        if r(N) > 0 {
            noisily di as txt "{txt}Note: {res}" r(N) "{txt} comment(s) could not be matched to a survey record"
            noisily di as txt "{txt}  (key not found in survey — submission may not yet be downloaded)"
        }
        
        // Assign a unique row ID before splitting off for value extraction
        gen long _row_id = _n
        
        // Save enriched comments (caseid + keepvars + flag + row id)
        tempfile enriched_comments
        quietly save "`enriched_comments'"
        
        // Extract values and labels for commented variables
        // Only use matched rows (flag_no_survey_match==0) for value extraction
        quietly keep if !flag_no_survey_match
        quietly keep _row_id key variable _inst0 _inst_parent   // slim dataset for merge with survey
        tempfile comments_matched
        quietly save "`comments_matched'"
        
        quietly use `"`survey'"', clear
        
        // Get numeric and string variable lists
        quietly ds, has(type numeric)
        local num_vars `r(varlist)'
        quietly ds, has(type string)
        local str_vars `r(varlist)'
        
        quietly merge 1:m key using "`comments_matched'", keep(match using) nogen

        // Secondary suffix resolution: if variable is still unsuffixed but the
        // parent path segment had [n], try var_n only when it exists in survey.
        quietly count if _inst_parent != "" & !regexm(variable, "_[0-9]+$")
        if r(N) > 0 {
            quietly levelsof variable if _inst_parent != "" & !regexm(variable, "_[0-9]+$"), local(_base_no_suffix) clean
            foreach _v of local _base_no_suffix {
                quietly levelsof _inst_parent if variable == "`_v'" & _inst_parent != "", local(_pvals) clean
                foreach _pi of local _pvals {
                    if `"`_pi'"' != "" {
                        local _cand "`_v'_`_pi'"
                        capture confirm variable `_cand'
                        if !_rc quietly replace variable = "`_cand'" if variable == "`_v'" & _inst_parent == "`_pi'"
                    }
                }
            }
        }
        
        // Create value and label columns using frval() and variable labels
        gen str value = ""
        gen str label_val = ""
        
        // Only iterate over variables that actually appear in the comments
        // (avoids looping through all 5000+ survey vars for each comment)
        quietly levelsof variable, local(commented_vars) clean
        local num_vars_used
        foreach v of local num_vars {
            if `: list v in commented_vars' local num_vars_used `num_vars_used' `v'
        }
        local str_vars_used
        foreach v of local str_vars {
            if `: list v in commented_vars' local str_vars_used `str_vars_used' `v'
        }
        
        foreach v of local num_vars_used {
            capture confirm variable `v'
            if !_rc {
                quietly replace value = string(`v') if variable == "`v'" & missing(value)
                local vlab: variable label `v'
                if `"`vlab'"' != "" {
                    quietly replace label_val = `"`vlab'"' if variable == "`v'"
                }
            }
        }
        
        foreach v of local str_vars_used {
            capture confirm variable `v'
            if !_rc {
                quietly replace value = `v' if variable == "`v'" & missing(value)
                local vlab: variable label `v'
                if `"`vlab'"' != "" {
                    quietly replace label_val = `"`vlab'"' if variable == "`v'"
                }
            }
        }
        
        // Fallback: for rows where value is still missing and the fieldname had
        // respondent_availability[N], try the outer-indexed variable form: var_{N-1}_{inner}
        // This covers member-roster variables like agwork_n_0_1, nonagwork_n_1_2, etc.
        quietly count if (value == "" | missing(value)) & _inst0 != ""
        if r(N) > 0 {
            quietly levelsof variable if (value == "" | missing(value)) & _inst0 != "", local(_still_miss) clean
            foreach _v of local _still_miss {
                if regexm("`_v'", "^(.+)_([0-9]+)$") {
                    local _vbase = regexs(1)
                    local _vidx  = regexs(2)
                    quietly levelsof _inst0 if variable == "`_v'" & (value == "" | missing(value)), local(_outer_vals) clean
                    foreach _oi of local _outer_vals {
                        if `"`_oi'"' != "" {
                            local _valt "`_vbase'_`_oi'_`_vidx'"
                            capture confirm variable `_valt'
                            if !_rc {
                                if `: list _valt in num_vars' {
                                    quietly replace value = string(`_valt') if variable == "`_v'" & _inst0 == "`_oi'" & (value == "" | missing(value))
                                    local _vlab : variable label `_valt'
                                    if `"`_vlab'"' != "" quietly replace label_val = `"`_vlab'"' if variable == "`_v'" & _inst0 == "`_oi'" & label_val == ""
                                }
                                else if `: list _valt in str_vars' {
                                    quietly replace value = `_valt' if variable == "`_v'" & _inst0 == "`_oi'" & (value == "" | missing(value))
                                    local _vlab : variable label `_valt'
                                    if `"`_vlab'"' != "" quietly replace label_val = `"`_vlab'"' if variable == "`_v'" & _inst0 == "`_oi'" & label_val == ""
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Bring back caseid/keepvars/flag from enriched_comments via _row_id
        quietly keep _row_id value label_val
        quietly merge 1:1 _row_id using "`enriched_comments'", nogen
        drop _row_id
        
        // Keep only relevant columns
        local final_vars "key `caseid_var' `keepvars' variable comment value label_val flag_no_survey_match"
        local final_vars: list uniq final_vars
        capture keep `final_vars'
        
        // Deduplicate: same submission + variable + comment is a true duplicate
        quietly duplicates drop key variable comment, force
        
        quietly count if !flag_no_survey_match
        local n_matched = r(N)
        di as txt "{txt}Merged with survey data: {res}`n_matched' {txt}comments matched"
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