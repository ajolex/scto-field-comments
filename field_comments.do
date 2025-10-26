
********************************************************************************
** 	TITLE	: field_comments.do
**	PURPOSE	: Collating enumerator comments from from the SCTO "comments" function
**  PROJECT	: PSPS Wave 1		
**	AUTHOR	: Aubrey Jolex
**	DATE	: 3 FEB 2025
********************************************************************************

clear

	set maxvar 		32767


	if "`c(username)'" 		== "NBKuan" loc cdloc = "C:/Users/NBKuan/Box/Philippines Panel/01 Panel/08 Analysis & Data"
	if "`c(username)'" 		== "AJolex" loc cdloc = "C:/Users/AJolex/Box/Philippines Panel/01 Panel/08 Analysis & Data"

	
	gl public	"`cdloc'/04 HFCs/PSPS_Wave1_Household"
	gl secure	"D:/04 HFCs/PSPS_Wave1_Household"


cd "${public}/4_data/2_survey/media"

local filenames: dir "." files "Comments*.csv"

tempfile comments
save `comments', emptyok

foreach f of local filenames {
    * Extract the key from the filename
    local key = substr("`f'", 10, .) // Remove the "Comments-" prefix
    local key = subinstr("`key'", ".csv", "", .) // Remove ".csv"

    * Import the file
    import delimited using `"`f'"', stripquotes(yes) bindquotes(strict) clear

    * Create the `file` and `id` variables
    gen file = `"`f'"'
    gen id = "`key'"

    * Append the current data to the combined dataset
    append using `comments', force
    save `comments', replace
	drop if v1=="Field name"
	drop if v2==""
	cap drop fieldname comment
	rename (v1 v2) (fieldname comment)
}

**Spliting the variable string - it contains group and repeat instances
split fieldname, p(/)
gen variable = ""

forvalues i = 1/8 {
	forvalues k = 2/8{
		replace variable = fieldname`i' if fieldname`k'=="" & fieldname`i'~=""
	}
}

	replace variable = fieldname8 if fieldname8~=""

	gen inst1=""
	gen inst2=""
	gen fieldname9=""
*Extract repeat instances for variables from a repeat group
forvalues i = 1/7 {
	local p = `i' + 1
replace inst1 = regexs(1) if regexm(fieldname`i', "repeat_.+\[(\d+)\]") & inst1==""
replace inst2 = regexs(1) if regexm(fieldname`p', "repeat_.+\[(\d+)\]") & inst1~=""
}

gen repeat_inst= ""
replace repeat_inst = variable + "_" + inst1 + "_" + inst2 if (inst1~="" & inst2~="")
replace repeat_inst = variable + "_" + inst1 if inst2=="" & repeat_inst=="" & inst1~=""
replace repeat_inst = variable if repeat_inst==""

drop variable
rename repeat_inst variable
	
keep comment variable id
drop if comment==""
drop if variable==""

gen uuid = "uuid:"
gen key = uuid+id
drop id uuid
replace variable = subinstr(variable, "grp_", "", .) 

save "${secure}\4_data\2_survey\comments_raw.dta", replace

merge m:1 key using "${secure}/4_data/2_survey/Household_linked_checked.dta"
keep if _merge==3
drop _merge key


global cvars "agown_cap	agown_cap_oth	agown_cred_amt	agown_cred_loc	agown_cred_rpd	agown_cred_yn	agown_inc	agown_inc_share	agri_cost_1	agri_cost_2	agri_cost_3	agri_cost_4	agri_cost_5	agri_cost_6	agri_cost_ltm	agri_crops_list	agri_crops_no_sale_1	agri_crops_no_sale_2	agri_crops_no_sale_3	agri_crops_no_sale_5	agri_crops_no_sale_6	agri_crops_no_sale_9	agri_crops_oth_num	agri_crops_qty_1	agri_crops_qty_10	agri_crops_qty_14	agri_crops_qty_2	agri_crops_qty_3	agri_crops_qty_4	agri_crops_qty_5	agri_crops_qty_6	agri_crops_qty_7	agri_crops_qty_8	agri_crops_qty_unit_oth_1	agri_crops_qty_unit_oth_2	agri_crops_rev_1	agri_crops_rev_2	agri_crops_rev_3	agri_crops_rev_4	agri_crops_rev_5	agri_crops_rev_6	agri_crops_rev_7	agri_crops_sale_ltm_1	agri_crops_sale_ltm_2	agri_crops_sale_ltm_3	agri_crops_sale_ltm_4	agri_crops_sale_ltm_5	agri_crops_sale_ltm_6	agri_crops_sale_ltm_7	agri_crops_snn_no_1	agri_crops_snn_no_10	agri_crops_snn_no_11	agri_crops_snn_no_13	agri_crops_snn_no_2	agri_crops_snn_no_3	agri_crops_snn_no_4	agri_crops_snn_no_5	agri_crops_snn_no_6	agri_crops_snn_no_7	agri_crops_snn_no_9	agri_crops_szn_1	agri_crops_szn_14	agri_crops_szn_3	agri_plot	agri_plot_area_unit_oth_8	agri_plot_care	agri_plot_n	agri_plot_prim_care	agri_work_dy_1	agri_work_dy_2	agwork_dy_1_1	agwork_dy_1_2	agwork_dy_2_1	agwork_dy_3_1	agwork_dy_4_1	agwork_hr_1_1	agwork_hr_1_2	agwork_hr_2_1	agwork_hr_3_1	agwork_hr_4_1	agwork_hr_4_2	agwork_hr_5_1	agwork_n_1	agwork_n_3	agwork_n_4	agwork_n_8	agwork_nam_1_1	agwork_nam_1_2	agwork_nam_2_1	agwork_nam_3_1	agwork_nam_4_1	agwork_nam_5_1	agwork_pay_amt_1_1	agwork_pay_amt_1_1_1	agwork_pay_amt_1_2	agwork_pay_amt_1_2_1	agwork_pay_amt_1_2_2	agwork_pay_amt_1_3_1	agwork_pay_amt_1_4_1	agwork_pay_amt_1_6_1	agwork_pay_amt_2_1	agwork_pay_amt_3_1	agwork_pay_amt_4_1	agwork_pay_amt_add_1_1	agwork_pay_amt_add_2_1	agwork_pay_amt_add_3_1	agwork_pay_control_1_1	agwork_pay_sch_1_1	agwork_pay_sch_1_2	agwork_pay_sch_oth_3_1	agwork_prod_1_1	agwork_prod_1_2	agwork_prod_3_1	agwork_prod_4_1	agwork_prod_6_1	agwork_prod_oth_1_1	asset_appliance_1	asset_appliance_2_11	asset_appliance_2_13	asset_appliance_2_2	asset_appliance_2_3	asset_appliance_2_4	asset_appliance_2_5	asset_appliance_2_6	asset_appliance_2_7	asset_appliance_2_9	asset_appliance_2high_1	asset_appliance_2high_2	asset_appliance_2high_3	asset_appliance_2high_5	asset_appliance_3a_1	asset_appliance_3a_2	asset_appliance_3a_3	asset_appliance_3a_4	asset_appliance_3a_5	asset_appliance_3b_1	asset_appliance_3b_5	asset_appliance_3b_6	asset_appliance_3b_7	asset_appliance_3ck_1	asset_appliance_3ck_2	asset_appliance_3ck_3	asset_appliance_4a_1	asset_appliance_4a_12	asset_appliance_4a_2	asset_appliance_4a_3	asset_appliance_4a_4	asset_appliance_4a_5	asset_appliance_4a_6	asset_appliance_4a_9	asset_appliance_4ahigh_1	asset_appliance_4ahigh_2	asset_appliance_4ahigh_3	asset_appliance_4alow_1	asset_appliance_4alow_2	asset_appliance_4alow_3	asset_appliance_4alow_4	asset_appliance_4alow_5	asset_appliance_4alow_6	asset_appliance_4alow_7	asset_appliance_4alow_8	asset_appliance_4b_1	asset_appliance_4b_2	asset_appliance_4b_3	asset_appliance_4b_4	asset_appliance_4b_5	asset_appliance_4bhigh_1	asset_appliance_4blow_1	asset_appliance_4blow_2	asset_appliance_4blow_3	asset_appliance_4blow_4	asset_equip_1	asset_equip_2_1	asset_equip_2_2	asset_equip_2_3	asset_equip_2_4	asset_equip_2_6	asset_equip_2high_2	asset_equip_3b_1	asset_equip_3ck_1	asset_equip_3ck_2	asset_equip_4a_1	asset_equip_4a_2	asset_equip_4a_3	asset_equip_4a_5	asset_equip_4alow_1	asset_equip_4alow_2	asset_equip_4alow_3	asset_equip_4alow_4	asset_equip_4b_1	asset_equip_4b_2	asset_equip_4b_4	asset_equip_4b_6	asset_equip_4blow_1	asset_equip_4blow_2	asset_equip_4ck_8	asset_furniture_1	asset_furniture_2	asset_furniture_2high	asset_house1_1	asset_house1_1_oth	asset_house1_2	asset_house1_2high	asset_house1_own	asset_house1_val_high	asset_house1_val_low	asset_house1a_value	asset_house1b_value	asset_house2_1	asset_house2_4	asset_house2_4high	asset_house2_4low	asset_house2_own	asset_house2_value	asset_house2_valuelow	asset_houses	asset_land_own	asset_land_value	asset_land_valuehigh	asset_land_valuelow	asset_vehicle_1	asset_vehicle_2_1	asset_vehicle_2_2	asset_vehicle_2_4	asset_vehicle_2_5	asset_vehicle_3a_1	asset_vehicle_3a_2	asset_vehicle_3a_3	asset_vehicle_3a_4	asset_vehicle_3b_1	asset_vehicle_3b_2	asset_vehicle_3ck_1	asset_vehicle_4a_1	asset_vehicle_4a_2	asset_vehicle_4a_3	asset_vehicle_4ahigh_1	asset_vehicle_4ahigh_3	asset_vehicle_4alow_1	asset_vehicle_4alow_2	asset_vehicle_4b_1	asset_vehicle_4b_2	asset_vehicle_4blow_1	asset_vehicle_4blow_2	asset_vehicle_4ck_2	asset_vehicle_5_1	asset_vehicle_5_2	asset_vehicle_5high_1	asset_vehicle_5high_2	asset_vehicle_oth_name_1	asset_vehicle_oth_num	bfi_1	bfi_1b	bfi_2	bfi_2a consent_agree	consent_agree_other_mem	consent_audio	consent_gps	 consent_other_mem	consent_reject_reas	consent_share_pii	cooking_oth	cooking_water	credit	credit_amt_1	credit_amt_2	credit_fee_1	credit_fee_2	credit_outstnd_1	credit_outstnd_2	credit_pay_amt_1	credit_pay_amt_2	credit_pay_sch_1	credit_pay_sch_2	credit_pay_sch_3	credit_pay_sch_oth_1	credit_pay_sch_oth_2	credit_reason_1	credit_reason_oth_1	credit_total_1	credit_total_2	datetime_ck	dremit_freq_irreg_2	dremit_freq_reg_1	dremit_freq_reg_2	dremit_freq_reg_3	dremit_freq_reg_4	dremit_total_1	dremit_total_2	dremit_total_3	dremit_total_4	dremit_total_5	drinking_water	earn_inc_ag_1	earn_inc_ag_4	earn_inc_ag_6	earn_inc_nonag_1	earn_inc_nonag_2	ed_presch_3	ed_presch_4	ed_presch_5	ed_presch_ever_4	ed_presch_yrs_3	ed_presch_yrs_4	ed_presch_yrs_5	ed_presch_yrs_6	ed_presch_yrs_8	edu_absent_3	edu_absent_4	edu_absent_5	edu_absent_7	edu_attend_3	edu_attend_4	edu_boarder_2	edu_boarder_3	edu_boarder_4	edu_boarder_5	edu_completed_1	edu_completed_12	edu_completed_2	edu_completed_3	edu_completed_4	edu_completed_5	edu_completed_7	edu_current_2	edu_current_3	edu_current_4	edu_current_5	edu_current_6	edu_current_7	edu_current_8	edu_current_9	edu_grade_2	edu_grade_3	edu_grade_4	edu_grade_5	edu_grade_7	edu_grade_ck_1	edu_grade_ck_2	edu_grade_ck_3	edu_grade_ck_4	edu_grade_ck_5	edu_grade_ck_6	edu_grade_ck_7	edu_grade_ck_8	edu_grade_ck_9	edu_grade_oth_3	edu_grade_oth_5	edu_reasons1_1	edu_reasons1_2	edu_reasons1_3	edu_reasons1_4	edu_reasons1_5	edu_reasons1_6	edu_reasons1_oth_5	edu_reasons2_1	edu_reasons2_2	edu_reasons2_3	edu_reasons2_4	edu_reasons2_5	edu_reasons2_6	edu_reasons2_8	edu_reasons3_3	edu_reasons3_4	edu_reasons3_5	edu_sch_municipality_3	edu_sch_municipality_5	edu_sch_municipality_6	edu_sch_name_1	edu_sch_name_10	edu_sch_name_2	edu_sch_name_3	edu_sch_name_4	edu_sch_name_5	edu_sch_name_6	edu_sch_name_7	edu_sch_name_8	edu_sch_name_oth_2	edu_sch_name_oth_4	edu_sch_name_oth_5	edu_sch_name_oth_6	edu_sch_province_3	edu_sch_province_5	edu_sch_province_6	edu_sch_type_1	edu_sch_type_4	edu_sch_type_5	edu_sch_type_oth_6	fd_cons_1_1	fd_cons_1_2	fd_cons_1_3	fd_cons_1_4	fd_cons_1_5	fd_cons_1_6	fd_cons_1_7	fd_cons_1_8	fd_cons_1_9	fd_cons_1a_1_1	fd_cons_1a_1_2	fd_cons_1a_1_3	fd_cons_1a_2_1	fd_cons_1a_2_2	fd_cons_1a_3_1	fd_cons_1a_3_2	fd_cons_1a_3_3	fd_cons_1a_3_4	fd_cons_1a_4_1	fd_cons_1a_4_2	fd_cons_1a_5_1	fd_cons_1a_5_2	fd_cons_1a_6_1	fd_cons_1a_6_2	fd_cons_1a_7_1	fd_cons_1a_8_1	fd_cons_1a_8_2	fd_cons_1a_9_1	fd_cons_2ahigh_1_1	fd_cons_2ahigh_1_2	fd_cons_2ahigh_1_3	fd_cons_2ahigh_3_2	fd_cons_2ahigh_6_1	fd_cons_2ahigh_7_1	fd_cons_2ahigh_8_1	fd_cons_2aunitoth_3_1	fd_cons_2aunitoth_4_1	fd_cons_2aunitoth_7_1	fd_cons_2aunitoth_8_1	fd_cons_2b_v1_1_1	fd_cons_2b_v1_1_2	fd_cons_2b_v1_1_3	fd_cons_2b_v1_2_1	fd_cons_2b_v1_2_2	fd_cons_2b_v1_2_3	fd_cons_2b_v1_2_4	fd_cons_2b_v1_3_1	fd_cons_2b_v1_3_2	fd_cons_2b_v1_3_3	fd_cons_2b_v1_3_4	fd_cons_2b_v1_4_1	fd_cons_2b_v1_4_2	fd_cons_2b_v1_6_1	fd_cons_2b_v1_7_1	fd_cons_2b_v1_8_1	fd_cons_2b_v1_8_2	fd_cons_2b_v1_8_3	fd_cons_2b_v2_1_2	fd_cons_2b_v2_1_3	fd_cons_2b_v2_4_1	fd_cons_2b_v2_5_1	fd_cons_2b_v2_5_2	fd_cons_2b_v2_6_1	fd_cons_2b_v2_6_2	fd_cons_2b_v2_9_1	fd_cons_2bhigh_1_1	fd_cons_2bhigh_4_1	fd_cons_2blow_2_1	fd_cons_2blow_2_2	fd_cons_2blow_5_1	fd_cons_2blow_5_2	fd_cons_2blow_7_1	fd_cons_2blow_8_1	fd_cons_2blow_9_1	fd_cons_3ahigh_1_1	fd_cons_3ahigh_3_2	fd_cons_3b_v1_1_1	fd_cons_3b_v1_1_2	fd_cons_3b_v1_1_3	fd_cons_3b_v1_2_1	fd_cons_3b_v1_2_2	fd_cons_3b_v1_2_3	fd_cons_3b_v1_2_4	fd_cons_3b_v1_3_1	fd_cons_3b_v1_3_2	fd_cons_3b_v1_3_3	fd_cons_3b_v1_4_1	fd_cons_3b_v1_4_2	fd_cons_3b_v1_6_1	fd_cons_3b_v1_8_1	fd_cons_3b_v2_1_2	fd_cons_3b_v2_1_3	fd_cons_3b_v2_5_1	fd_cons_3b_v2_5_2	fd_cons_3b_v2_6_1	fd_cons_3b_v2_6_2	fd_cons_3b_v2_9_1	fd_cons_3bhigh_3_2	fd_cons_3blow_2_1	fd_cons_3blow_2_2	fd_cons_3blow_6_1	fd_cons_4ahigh_6_1	fd_cons_4b_v1_1_1	fd_cons_4b_v1_1_2	fd_cons_4b_v1_1_3	fd_cons_4b_v1_2_1	fd_cons_4b_v1_2_2	fd_cons_4b_v1_2_3	fd_cons_4b_v1_3_1	fd_cons_4b_v1_3_2	fd_cons_4b_v1_4_1	fd_cons_4b_v1_4_2	fd_cons_4b_v1_6_1	fd_cons_4b_v1_7_1	fd_cons_4b_v1_8_1	fd_cons_4b_v1_8_2	fd_cons_4b_v2_1_2	fd_cons_4b_v2_1_3	fd_cons_4b_v2_5_1	fd_cons_4b_v2_5_2	fd_cons_4b_v2_6_1	fd_cons_4b_v2_6_2	fd_cons_4b_v2_9_1	fd_cons_4blow_2_1	fd_cons_4unitdiff_a_3_1	fd_cons_5	fd_cons_5a_1	fd_cons_5a_2	fd_cons_5a_3	fd_cons_5a_4	fd_cons_5ahigh_1	fd_cons_5ahigh_2	fd_cons_6a_1	fd_cons_6a_2	fd_cons_6a_3	fd_cons_6a_4	fd_cons_6a_5	fd_cons_6ahigh_2	fd_cons_6alow_1	fd_cons_6alow_2	fd_cons_6alow_3	fd_cons_6b_1	fd_cons_6b_4	fd_cons_6blow_2	fd_cons_6blow_4	fd_cons_unitdiff_8_1	fies_1	fies_4	fies_6	fies_8	fish_act	fish_act_list_oth	fish_cap	fish_cap_oth	fish_care	fish_cost_1	fish_cost_2	fish_cost_3	fish_cost_ltm	fish_oth_num	fish_rev	fish_sale_ltm	fish_work_dy_1	fish_work_dy_2	fish_work_dy_3	fish_work_dy_4	floor_oth	forest_act	forest_act_list	forest_cap	forest_cap_oth	forest_care	forest_cost_1	forest_cost_ltm	forest_cred_yn	forest_no_sale	forest_prim_care	forest_rev	forest_sale_ltm	forest_work_dy_1	forest_work_dy_4	fremit_freq_reg_1	fremit_freq_reg_2	fremit_freq_reg_oth_2	fremit_total_1	fremit_total_2	fremit_total_3	fremit_total_5	gcash_register	gift_freq_1	gift_freq_2	gift_freq_3	gift_tot_cash_1	gift_tot_cash_3	gift_tot_cash_5	gift_tot_cash_6	gift_tot_inkind_1	gift_tot_inkind_2	gift_tot_inkind_3	gift_type_1	gift_type_2	govt_freq_reg_1	govt_freq_reg_2	govt_freq_reg_3	govt_freq_reg_4	govt_freq_reg_6	govt_source_1	govt_source_2	govt_source_3	govt_source_5	govt_source_oth_1	govt_source_oth_2	govt_suff_1	govt_suff_2	govt_target_1	govt_tot_cash_1	govt_tot_cash_2	govt_tot_cash_3	govt_tot_cash_4	govt_tot_cash_5	govt_tot_cash_6	govt_tot_cash_8	govt_tot_inkind_1	govt_tot_inkind_2	govt_type_1	govt_type_2	govt_type_3	govt_type_6	govt_type_oth_4	health_exp1	health_exp2	health_exp3	mig_lgth_1_1	mig_lgth_mr_1	mig_lgth_mr_2	mig_lgth_mr_3	mig_lgth_mr_4	nr_age_est_1	nr_age_est_2 r_birthdate_11	r_birthdate_2	r_birthdate_3	r_birthdate_4	r_birthdate_5	r_birthdate_6	r_birthdate_7	r_birthdate_8	r_birthdate_9	health_access_1	health_access_11	health_access_2	health_access_3	health_access_4	health_access_6	health_access_7	health_access_9	hh_help	hh_resp	housing_construction	housing_cooking	housing_floor	housing_lighting	housing_roof	housing_status	housing_toilet	hwise_1	hwise_2	hwise_4	illness_action_1_1	illness_action_2_1	illness_action_2_2	illness_action_3_1	illness_action_6_1	illness_action_6_2	illness_action_9_1	illness_diagnoser_1_1	illness_diagnoser_2_1	illness_diagnoser_2_2	illness_insurance_1	illness_insurance_10	illness_insurance_2	illness_insurance_3	illness_insurance_4	illness_insurance_5	illness_insurance_6	illness_insurance_9	illness_oth_name_2_1	illness_stop_1	illness_stop_2	illness_stop_3	illness_stop_4	illness_stop_5	illness_stop_6	illness_stop_care_1	illness_stop_care_2	illness_stop_care_3	illness_traditional	illness_which_1	illness_which_2	illness_which_3	illness_which_4	illness_which_5	illness_which_8	illness_which_9	illness_which_oth_num_2	illness_yn_1	illness_yn_2	illness_yn_3	illness_yn_4	illness_yn_5	inc_any_earn_30d_1	inc_any_earn_30d_2	inc_any_earn_30d_3	inc_any_earn_30d_4	inc_any_earn_30d_5	inc_any_unearn_ltm_1	inc_any_unearn_ltm_2	inc_any_unearn_ltm_3	inc_any_unearn_ltm_4	inc_any_unearn_ltm_5	inc_recv_1	inc_recv_2	inc_recv_4	inc_recv_unearn_1	inc_recv_unearn_2	inc_recv_unearn_3	inc_recv_unearn_4	inc_recv_unearn_5	interview_brgy_hall	lighting_oth	lv_buy_1	lv_buy_price_2	lv_cap	lv_cap_oth	lv_care	lv_cost_1	lv_cost_2	lv_cost_3	lv_cost_ltm	lv_cost_oth_name_1	lv_cost_oth_num	lv_cost_own	lv_cred_amt	lv_cred_loc_oth	lv_cred_rpd	lv_cred_yn	lv_disease_num_1	lv_disease_num_2	lv_gifts_1	lv_inc_share	lv_list	lv_member_owner_1	lv_member_owner_2	lv_no_sale	lv_oth_num	lv_own	lv_prim_care_1	lv_prim_care_2	lv_prod_type	lv_prod_type_oth	lv_purpose_1	lv_purpose_2	lv_rev	lv_sale_ltm	lv_slaughter_1	lv_slaughter_4	lv_t_value_1	lv_t_value_2	lv_t_value_3	lv_t_value_4	lv_t_value_5	lv_total_own_1	lv_total_own_2	lv_total_own_3	lv_total_own_4	lv_total_own_zero_1	lv_total_own_zero_2	lv_total_raise_1	lv_total_raise_2	lv_work_dy_1	lv_work_dy_2	lv_work_dy_3	mig_a_1_1	mig_a_mr_1	mig_a_mr_2	mig_a_mr_3	mig_b_1_1	mig_b_1_2	mig_b_mr_1	mig_b_mr_2	mig_b_mr_3	mig_b_mr_4	mig_c_1_1	mig_c_1_2	mig_c_mr_1	mig_c_mr_2	mig_c_mr_3	mig_c_mr_oth_1	mig_child_1	mig_child_2	mig_child_4	mig_child_id_1	mig_child_id_3	mig_ctry_mr_3	mig_ctry_mr_oth_1	mig_dest_1_1	mig_dest_mr_1	mig_dest_mr_oth_1	mig_job_1_1	mig_job_1_2	mig_job_mr_1	mig_job_mr_2	mig_job_mr_3	mig_pp1	mig_pp4	mig_pp5	mig_reg_1_1	mig_reg_1_4	mig_reg_mr_1	mig_reg_mr_2	mig_reg_mr_3	mig_reg_mr_4	mig_startyr_1_1	mig_startyr_1_2	mig_startyr_mr_1	mig_startyr_mr_2	mig_times_1	mig_times_2	mig_times_4	mig_who	momo_1	momo_1a	momo_2	momo_3	nfd_cons_1_1	nfd_cons_1_2	nfd_cons_1_3	nfd_cons_1_4	nfd_cons_1_5	nfd_cons_1_6	nfd_cons_1_7	nfd_cons_1a_1_1	nfd_cons_1a_1_2	nfd_cons_1a_1_3	nfd_cons_1a_3_1	nfd_cons_1a_4_1	nfd_cons_1a_5_1	nfd_cons_1a_5_2	nfd_cons_1a_5_3	nfd_cons_1a_5_5	nfd_cons_1a_6_2	nfd_cons_1a_7_1	nfd_cons_1a_7_2	nfd_cons_2_1_1	nfd_cons_2_1_2	nfd_cons_2_1_3	nfd_cons_2_2_1	nfd_cons_2_3_1	nfd_cons_2_4_1	nfd_cons_2_5_1	nfd_cons_2_5_2	nfd_cons_2_5_3	nfd_cons_2_5_4	nfd_cons_2_5_5	nfd_cons_2_5_6	nfd_cons_2_5_7	nfd_cons_2_5_8	nfd_cons_2_5_9	nfd_cons_2_6_1	nfd_cons_2_6_2	nfd_cons_2_7_1	nfd_cons_2_7_2	nfd_cons_2_7_3	nfd_cons_2_7_4	nfd_cons_2high_2_1	nfd_cons_2high_6_1	nfd_cons_2high_7_1	nfd_cons_2high_7_2	nfd_cons_2high_7_3	nfd_cons_2high_7_4	nfd_cons_2low_1_1	nfd_cons_2low_1_2	nfd_cons_2low_1_3	nfd_cons_2low_3_1	nfd_cons_2low_4_1	nfd_cons_2low_5_1	nfd_cons_2low_5_2	nfd_cons_2low_5_3	nfd_cons_2low_5_4	nfd_cons_2low_6_1	nfd_cons_2low_7_1	nfd_cons_2low_7_2	nfd_cons_3_1_1	nfd_cons_3_1_2	nfd_cons_3_1_3	nfd_cons_3_1_4	nfd_cons_3_3_1	nfd_cons_3_5_1	nfd_cons_3_6_1	nfd_cons_3_7_1	nfd_cons_3low_1_2	nfd_cons_3low_1_3	nfd_cons_3low_4_1	nfd_cons_3low_5_1	nfd_cons_3low_7_1	nfd_cons_3low_7_2	nfd_cons_4_1_2	nfd_cons_4_2_1	nfd_cons_4_3_1	nfd_cons_4_5_1	nfd_cons_4_5_2	nfd_cons_4_5_3	nfd_cons_4_5_4	nfd_cons_4_5_5	nfd_cons_4_5_6	nfd_cons_4_5_7	nfd_cons_4_5_9	nfd_cons_4_7_1	nfd_cons_4low_1_2	nfd_cons_4low_3_1	nfd_cons_4low_4_1	nfd_cons_4low_5_1	nfd_cons_4low_5_3	no_any_income_check	no_any_work_check	no_vacc_reason_1	no_vacc_reason_oth_1	nonagown_cap_1	nonagown_care_1	nonagown_clsd_1	nonagown_clsd_2	nonagown_clsd_3	nonagown_clsd_oth_1	nonagown_cred_amt_1	nonagown_cred_amt_2	nonagown_cred_loc_1	nonagown_cred_loc_2	nonagown_cred_loc_3	nonagown_cred_rpd_1	nonagown_cred_rpd_2	nonagown_cred_yn_1	nonagown_hh_own_1	nonagown_hh_own_2	nonagown_inc_2	nonagown_ind_1	nonagown_ind_2	nonagown_n	nonagown_nam_1	nonagown_nam_2	nonagown_no_sale_1	nonagown_no_sale_2	nonagown_nonhh_coown_1	nonagown_op_1	nonagown_op_lm_1	nonagown_prof_avg_1	nonagown_prof_avg_2	nonagown_prof_avg_n_1	nonagown_prof_avg_n_2	nonagown_prof_high_1	nonagown_prof_high_2	nonagown_prof_high_3	nonagown_prof_high_n_1	nonagown_prof_high_n_2	nonagown_prof_lm_1	nonagown_prof_lm_2	nonagown_prof_lm_lvl_1	nonagown_prof_lm_lvl_2	nonagown_prof_low_1	nonagown_prof_low_2	nonagown_prof_low_3	nonagown_prof_low_n_1	nonagown_prof_low_n_2	nonagown_reg_1	nonagown_start_1	nonagown_work_hr_1_1	nonagown_work_hr_2_1	nonagown_work_hr_avg_1_1	nonagown_work_hr_avg_2_1	nonagown_work_hr_avg_3_1	nonagown_work_hr_ck_1_1	nonagown_work_hr_ck_1_2	nonagown_work_hr_ck_2_1	nonagown_work_hr_ck_3_1	nonagown_work_hr_ck_4_1	nonagown_work_hr_high_1_1	nonagown_work_hr_high_1_2	nonagown_work_hr_high_2_1	nonagown_work_hr_high_3_1	nonagown_work_hr_low_1_1	nonagown_work_hr_low_1_2	nonagown_work_hr_low_2_1	nonagown_work_hr_low_3_1	nonagwork_dy_1_1	nonagwork_dy_1_2	nonagwork_dy_2_1	nonagwork_dy_2_2	nonagwork_dy_3_1	nonagwork_dy_4_1	nonagwork_dy_5_1	nonagwork_dy_6_1	nonagwork_dy_7_1	nonagwork_hr_1_1	nonagwork_hr_1_2	nonagwork_hr_2_1	nonagwork_hr_3_1	nonagwork_hr_4_1	nonagwork_hr_6_1	nonagwork_n_1	nonagwork_n_2	nonagwork_nam_1_1	nonagwork_nam_1_2	nonagwork_nam_2_1	nonagwork_nam_3_1	nonagwork_nam_4_1	nonagwork_nam_5_1	nonagwork_nam_7_1	nonagwork_occ_1_1	nonagwork_occ_1_2	nonagwork_occ_2_1	nonagwork_occ_3_1	nonagwork_occ_4_1	nonagwork_occ_5_1	nonagwork_occ_7_1	nonagwork_occ_oth_2_1	nonagwork_occ_oth_3_1	nonagwork_pay_add_1_1	nonagwork_pay_add_1_2	nonagwork_pay_add_2_1	nonagwork_pay_add_2_2	nonagwork_pay_add_3_1	nonagwork_pay_add_4_1	nonagwork_pay_add_6_1	nonagwork_pay_add_7_1	nonagwork_pay_amt_1_1	nonagwork_pay_amt_1_1_1	nonagwork_pay_amt_1_1_2	nonagwork_pay_amt_1_2	nonagwork_pay_amt_1_2_1	nonagwork_pay_amt_1_2_2	nonagwork_pay_amt_1_3_1	nonagwork_pay_amt_1_3_2	nonagwork_pay_amt_1_4	nonagwork_pay_amt_1_4_1	nonagwork_pay_amt_1_5_1	nonagwork_pay_amt_1_7_1	nonagwork_pay_amt_2_1	nonagwork_pay_amt_3_1	nonagwork_pay_amt_4_1	nonagwork_pay_amt_6_1	nonagwork_pay_amt_7_1	nonagwork_pay_control_1_1	nonagwork_pay_sch_1_1	nonagwork_pay_sch_2_1	nonagwork_pay_sch_2_2	nonagwork_pay_sch_4_1	nowork_reason_1	nowork_reason_2	nowork_reason_3	nowork_reason_4	nowork_reason_5	nowork_reason_6	nowork_reason_oth_2	nr_edu_completed_1	nr_edu_completed_2	nr_edu_completed_3	nr_edu_current_1	nr_edu_current_2	nr_edu_current_3	nr_edu_current_4	nr_edu_current_5	nr_fname_1	nr_fname_2	nr_fname_3	nr_gender_1	nr_lname_1	nr_lname_2	nr_mem_yn	nr_mig_reason_1	nr_mname_1	nr_mname_2	nr_nickname_2	nr_other_1	nr_other_2	nr_other_5	nr_relation_1	nr_relation_2	other_any_1	other_any_2	other_any_5	other_rent_lm_1	other_rent_ltm_1	other_source_1	other_source_2	other_source_6	other_ss_lm_1	other_ss_lm_2	other_ss_lm_3	other_ss_lm_4	other_ss_lm_5	other_ss_lm_6	other_ss_ltm_1	other_ss_ltm_2	other_ss_ltm_3	other_ss_ltm_4	other_ss_ltm_5	other_ss_ltm_6	pltry_buy_1	pltry_buy_2	pltry_buy_no_1	pltry_buy_price_1	pltry_buy_price_2	pltry_buy_price_3	pltry_cap	pltry_cap_oth	pltry_care	pltry_cost_1	pltry_cost_2	pltry_cost_3	pltry_cost_4	pltry_cost_ltm	pltry_cost_own	pltry_cred_amt	pltry_cred_loc	pltry_cred_loc_oth	pltry_cred_rpd	pltry_disease_1	pltry_disease_num_1	pltry_disease_num_2	pltry_disease_num_3	pltry_gifts_1	pltry_gifts_2	pltry_inc	pltry_list	pltry_member_owner_1	pltry_member_owner_2	pltry_member_owner_4	pltry_own	pltry_prim_care_1	pltry_prim_care_2	pltry_prod_type	pltry_purpose_1	pltry_purpose_3	pltry_rev	pltry_slaughter_1	pltry_slaughter_2	pltry_slaughter_4	pltry_stolen_1	pltry_stolen_2	pltry_t_value_1	pltry_t_value_2	pltry_t_value_3	pltry_t_value_4	pltry_total_own_1	pltry_total_own_2	pltry_total_own_3	pltry_total_own_4	pltry_total_own_zero_1	pltry_total_own_zero_2	pltry_total_own_zero_4	pltry_total_raise_1	pltry_total_raise_2	pltry_total_raise_3	pltry_total_raise_4	pltry_work_dy_1	pltry_work_dy_2	ppi_1	ppi_2	ppi_3	ppi_4	pull_confirm	pvt_freq_irreg_2	pvt_source_3	pvt_source_4	pvt_tot_cash_1	pvt_tot_inkind_1	pvt_tot_inkind_4 r_fname_1	r_fname_11	r_fname_2	r_fname_3	r_fname_4	r_fname_5	r_fname_6	r_fname_7	r_fname_8	r_gender_1	r_gender_11	r_gender_2	r_gender_3	r_gender_6	r_kids_baby_1	r_kids_baby_2	r_kids_baby_3	r_kids_baby_4	r_kids_baby_6	r_kids_yn_2	r_kids_yn_3	r_kids_yn_5	r_kids_yn_7	r_lname_1	r_lname_11	r_lname_2	r_lname_3	r_lname_4	r_lname_5	r_lname_6	r_lname_8	r_lname_9	r_marital_1	r_marital_2	r_marital_3	r_marital_4	r_marital_5	r_marital_6	r_marital_8	r_marital_age_1	r_marital_age_2	r_marital_age_4	r_marital_age_5	r_marital_age_7	r_marital_oth_2	r_members_confirm	r_mname_1	r_mname_10	r_mname_11	r_mname_12	r_mname_13	r_mname_18	r_mname_2	r_mname_3	r_mname_4	r_mname_5	r_mname_6	r_mname_7	r_mname_8	r_namesuff_1	r_namesuff_yn_1	r_namesuff_yn_11	r_namesuff_yn_2	r_namesuff_yn_5	r_nickname_2	r_nickname_3	r_nickname_yn_1	r_nickname_yn_2	r_other_1	r_other_2	r_other_3	r_ph1_1	r_ph1_2	r_ph1_3	r_ph1_ntwk_2	r_ph1_type_1	r_ph1_type_2	r_ph1_type_3	r_ph2_1	r_ph2_type_2	r_ph2_yn_1	r_ph2_yn_2	r_phone	r_rel_1	r_relation_1	r_relation_10	r_relation_11	r_relation_2	r_relation_3	r_relation_4	r_relation_5	r_relation_6	r_relation_7	r_relation_8	r_relation_9	r_sss_1	r_sss_2	r_sss_6	r_sss_7	reclass_nr_mem	reclass_r_mem	ref_1_name	ref_1_phone	ref_1_rel	ref_2_name	ref_2_phone	ref_2_rel	ref_3_name	ref_3_phone	ref_3_rel	save_1_1	save_1_2	save_1_3	save_2_1	save_3_1	save_4_1	save_4_2	save_loc	save_owner_1	select_indiv_survey_18to45	select_indiv_survey_46	select_indiv_survey_k15	select_indiv_survey_k3to8	shock_0	shock_1_1	shock_2_1	shock_2a_1	shock_2b_1	shs_strand_2	shs_strand_3	shs_strand_4	shs_strand_6	shs_track_2	shs_track_3	shs_track_4	shs_track_5	sss_yn_1	sss_yn_2	temp_no_woman_confirm	token	token_phone	unearn_dremit_yn_1	unearn_dremit_yn_2	unearn_dremit_yn_3	unearn_fremit_yn_1	unearn_fremit_yn_2	unearn_fremit_yn_3	unearn_gift_yn_1	unearn_gift_yn_2	unearn_gift_yn_3	unearn_gift_yn_4	unearn_govt_yn_1	unearn_govt_yn_2	unearn_govt_yn_3	unearn_govt_yn_4	unearn_govt_yn_5	unearn_ngo_yn_1	unearn_ngo_yn_3	unearn_other_yn_1	unearn_other_yn_2	vacc_bcg_1	vacc_bcg_2	vacc_covid	vacc_dpt_1	vacc_opv_1	work_any_30d_1	work_any_30d_2	work_any_30d_3	work_any_30d_5	work_any_30d_6	work_any_30d_8"


keep caseid fo_id fc_id variable comment $cvars
order caseid fo_id fc_id variable comment $cvars


// Create new variables for the values and labels
gen num_val = .
gen str_val = ""
gen label_val = ""  // New variable to hold labels

// Separate numeric and string variables
ds $cvars, has(type numeric)
local num_vars `r(varlist)' // list of numeric vars

ds $cvars, has(type string)
local str_vars `r(varlist)' // list of string vars

// Loop through each observation
forval i = 1/`=_N' {
    // Get the name of the variable stored in "variable"
    local varname = variable[`i']
    
    // Loop over numeric variables and check if the current variable matches
    foreach num_var of local num_vars {
        if "`varname'" == "`num_var'" {
            quietly replace num_val = `num_var'[`i'] in `i'
            // Assign the variable label to label_val
            quietly replace label_val = "`: var label `num_var''" in `i'
            continue
        }
    }
    
    // Loop over string variables and check if the current variable matches
    foreach str_var of local str_vars {
        if "`varname'" == "`str_var'" {
            quietly replace str_val = `str_var'[`i'] in `i'
            // Assign the variable label to label_val
            quietly replace label_val = "`: var label `str_var''" in `i'
            continue
        }
    }
}


keep caseid fo_id fc_id variable comment num_val str_val label_val

tostring num_val, replace
replace str_val= num_val if str_val=="" & num_val~="."
drop num_val
rename str_val value

save "${secure}\4_data\2_survey\comments.dta", replace