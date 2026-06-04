*===============================================================================
* FILE:     katrina_by_quartiles_0405inst.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile IV analysis)
* PRODUCES: "Prior-school instrument" IV robustness row for the Houston
*           grade-level achievement/behavior batteries (App Tables 4, 5 & 41).
*
* PURPOSE:  Re-estimates the Houston quartile peer-effect regressions by
*           INSTRUMENTING each student's current evacuee share with the eventual
*           2005-06 evacuee share at the student's PRIOR (2004-05) school and
*           grade. This addresses endogenous post-Katrina re-sorting of students
*           across campuses: the instrument is fixed by where a student was
*           BEFORE the hurricane. Reports OLS, first stage, 2SLS and reduced
*           form for each outcome, pooled and by quartile.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  /work/i/imberman/imberman/katrina_0405school.dta (instrument file)
*           Regression output to the log only.
*
* KEY STEPS:
*   - Build the instrument: collapse 2005-06 evacuee share by prior school x
*     grade, save as katrina_0405school.dta.
*   - Loop over grade band (elem / midhigh); build pre-Katrina lag controls.
*   - Identify each student's 2004-05 campus and merge its eventual evacuee
*     share as the instrument; zero it out pre-2005.
*   - Merge in pre-Katrina achievement quartiles.
*   - Run OLS / first stage / 2SLS (ivreg) / reduced form, pooled then by
*     quartile 1-4.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute working dir; repoint to globals)
*   - all use/merge/save paths /work/i/imberman/imberman/*.dta
*   - lag cutoff `l`lag'.year <= 2004` (last pre-Katrina year)
*   - INSTRUMENT build: `keep if year == 2005` (2005-06 evacuee share)
*   - prior-school mapping: `campus_0405 = l.campus if year==2005`,
*     `= l2.campus if year==2006`, and `katrina_frac_0405school = 0 if year<2005`
*
* NOTE: This is the Sept-2005-style evacuee-share instrument applied at the
*       student's pre-Katrina school. Documentation comments only — no
*       executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

**INSTRUMENT FOR EVACUEE SHARE USING THE EVENTUAL EVACUEE SHARE IN 0506 IN 0405 SCHOOL



clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****



* ---- Working directory & clear stale output files ----
  cd /work/i/imberman/imberman/   // PATH: repoint to your local globals
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml

* ---- BUILD INSTRUMENT: 2005-06 evacuee share by (prior school x grade) ----
* This is the excluded instrument for current evacuee share, keyed to the
* student's pre-Katrina (2004-05) campus.
*GENERATE DATASET OF 0506 EVAC SHARES
use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
keep if year == 2005   // YEAR HARDCODE: 2005 = first post-Katrina (2005-06) year; defines instrument value
collapse (mean) katrina_frac_grade, by(campus grade year)
rename katrina_frac_grade katrina_frac_0405school
rename campus campus_0405
sort campus_0405 grade year
save /work/i/imberman/imberman/katrina_0405school.dta, replace   // PATH: instrument file; repoint to your local globals


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  * ---- Load Houston analysis panel ----
  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  * ---- Build pre-Katrina lagged controls (value-added: nearest pre-2005 lag) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: 2004 = last pre-Katrina year
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004     // YEAR HARDCODE: 2004 = last pre-Katrina year
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  * ---- IV STEP: map each student to their 2004-05 (pre-Katrina) campus ----
  *IDENTIFY THE 0405 SCHOOL
  gen campus_0405 = .
  replace campus_0405 = l.campus if year == 2005    // YEAR HARDCODE: 2005 -> prior-year (2004-05) campus is the 1-year lag
  replace campus_0405 = l2.campus if year == 2006   // YEAR HARDCODE: 2006 -> 2004-05 campus is the 2-year lag

  * ---- Merge the instrument (eventual evacuee share at the 2004-05 school) ----
  *MERGE IN EVAC SHARE IN CURRENT GRADE FOR 0405 SCHOOL
  sort campus_0405 grade year
  merge campus_0405 grade year using /work/i/imberman/imberman/katrina_0405school.dta, nokeep _merge(_merge0405)   // PATH: instrument file; repoint to your local globals
  replace katrina_frac_0405school = 0 if year < 2005   // YEAR HARDCODE: pre-2005 years have zero evacuees -> instrument = 0
  keep if katrina_frac_0405school != .


  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1

  *GENERATE AVERAGE PEER SCORE
  gen taks_sd_min_math_nomiss = taks_sd_min_math != .
  gen taks_sd_min_read_nomiss = taks_sd_min_read != .
  
  * ---- Merge in BASELINE ACHIEVEMENT QUARTILES (incumbent pre-Katrina quartile) ----
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep   // PATH (commented out)
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint to your local globals; supplies *_quartile


  * ---- Grade x year interactions and campus dummies (FE entered via i.campus) ----
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year i.campus

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  di ""
  di "POOLED LINEAR MODEL"
  di ""

  * ---- POOLED estimates: OLS / first stage / 2SLS / reduced form (all quartiles) ----
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;

	*OLS;
	reg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);

	*FIRST STAGE;
	reg katrina_frac_grade  katrina_frac_0405school  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);

	*2SLS;
	ivreg `var' (katrina_frac_grade = katrina_frac_0405school)  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if  `var'_quartile != ., cluster(campus);

	*REDUCED FORM;
	reg `var' katrina_frac_0405school  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != . & `var'_quartile != ., cluster(campus);

  };

  foreach var of varlist perc_attn infractions {;

	*OLS;
	reg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);

	*FIRST STAGE;
	reg katrina_frac_grade  katrina_frac_0405school  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);

	*2SLS;
	ivreg `var' (katrina_frac_grade = katrina_frac_0405school)  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus);

	*REDUCED FORM;
	reg `var' katrina_frac_0405school  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var' != ., cluster(campus);

  };
  # delimit cr


 * ---- BY-QUARTILE estimates: OLS / first stage / 2SLS / reduced form ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""


  *FIRST STAGE
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read  {;


	*OLS;
	reg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*
		if `var'_quartile == `quartile' & `var' != ., cluster(campus);
	*FIRST STAGE;
	reg katrina_frac_grade  katrina_frac_0405school  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
		if `var'_quartile == `quartile' & `var' != ., cluster(campus);

	*2SLS;
	ivreg `var' (katrina_frac_grade = katrina_frac_0405school)  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*
		if `var'_quartile == `quartile' & `var' != ., cluster(campus);

	*REDUCED FORM;
	reg `var' katrina_frac_0405school  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*
		if `var'_quartile == `quartile' & `var' != ., cluster(campus);

  };

*CLOSE QUARTILE LOOP;
};


*CLOSE GRADELEVEL LOOP;
};


