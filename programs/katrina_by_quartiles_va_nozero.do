*===============================================================================
* FILE:     katrina_by_quartiles_va_nozero.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile analysis)
* PRODUCES: "Drop zero-evacuee schools" robustness row for the Houston
*           grade-level achievement/behavior batteries (App Tables 4, 5 & 41).
*
* PURPOSE:  Re-estimates the Houston value-added quartile peer-effect
*           regressions restricting to schools that received a POSITIVE evacuee
*           share in 2005-06. This identifies effects off the schools actually
*           treated by the natural experiment rather than off the comparison
*           between treated and never-treated campuses.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
* OUTPUTS:  Regression output to the log only.
*
* KEY STEPS:
*   - Loop over grade band (elem / midhigh).
*   - Build pre-Katrina lagged controls.
*   - Build campus-level 2005-06 evacuee share, merge quartiles.
*   - Keep only campuses with positive 2005-06 evacuee share.
*   - Run pooled value-added areg, then loop over quartiles 1-4.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute working dir; repoint to globals)
*   - all use/merge paths /work/i/imberman/imberman/*.dta
*   - lag cutoff `l`lag'.year <= 2004` (last pre-Katrina year)
*   - `if year == 2005` defines the 2005-06 evacuee-share measure
*   - commented-out trailing block uses year>=2005, year==2006
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

***DROPS SCHOOLS W/ NO EVACUEES IN 2005-06****


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


  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1

  * ---- Campus-level 2005-06 evacuee share (used to drop zero-evacuee schools) ----
  **GENERATE MEASURE FOR EVACS IN 2005-06
  gen temp = katrina_frac_campus if year == 2005   // YEAR HARDCODE: 2005 = first post-Katrina (2005-06) year
  egen katrina_frac_campus_0506 = max(temp), by(campus)


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


  * ---- Grade x year interactions and campus fixed effects ----
  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0

  * ---- SAMPLE RESTRICTION: keep only campuses with a positive 2005-06 evacuee share ----
  *LIMIT TO SCHOOLS WITH POSITIVE EVAC SHARE IN 2005-06
  keep if katrina_frac_campus_0506 > 0 & katrina_frac_campus_0506 != .

*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- POOLED value-added regressions (all quartiles): evacuee share -> outcome ----
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile !=., cluster(campus) absorb(campus);
  };
  foreach var of varlist perc_attn infractions {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus) absorb(campus);
  };
  # delimit cr


 * ---- BY-QUARTILE value-added regressions (evacuee share x incumbent quartile) ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if `var'_quartile == `quartile', cluster(campus) absorb(campus);

	};



*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};




/*
    ***KATRINA SHARE BY QUARTILE****;

	foreach var in "math" "read" {;
		areg taks_sd_min_`var'  katrina_frac_`var'_median_1 katrina_frac_`var'_median_2
			female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if taks_sd_min_`var'_quartile == `quartile', cluster(campus) absorb(campus);


		*TEST FOR MONOTONICITY/BOUTIQUE;
		lincom katrina_frac_`var'_median_2 - katrina_frac_`var'_median_1;

		*TEST FOR LINEAR IN MEANS;
		lincom katrina_frac_`var'_median_2 + katrina_frac_`var'_median_1;

		outreg2 katrina_frac_`var'_median_1 katrina_frac_`var'_median_2 
			 using outreg_quartile_grade, excel nocons bdec(2);
	};
*/


* ---- INACTIVE BLOCK (commented out): builds evacuee-by-median shares from
*      hisd_data.dta. Uses YEAR HARDCODES year>=2005 and year==2006 and the
*      PATH /work/i/imberman/imberman/. Not executed in this variant. ----
/*
*GENERATE EVACUEE QUARTILES BASED ON 2005

use /work/i/imberman/imberman/hisd_data.dta, clear


*KEEP ONLY THOSE WHO ARE IN TESTED GRADES 3 - 11
keep if grade >= 3 & grade <= 11

*LIMIT TO POST 2005
keep if year >= 2005
drop unit
gen unit = 1

  xtset id year

  *GENERATE TEST SCORE MEDIANS
  foreach depvar of varlist taks_sd_min_math taks_sd_min_read {
    foreach percentile of numlist  50 {
	  egen `depvar'_percentile_`percentile' = pctile(`depvar'), p(`percentile') by(grade year)
    }
    forvalues median = 1/2 {
	gen `depvar'_median_`median' = 0
    }
    replace `depvar'_median_1 = 1 if `depvar' <= `depvar'_percentile_50 & `depvar' & `depvar' != .
    replace `depvar'_median_2 = 1 if `depvar' > `depvar'_percentile_50 & `depvar' != .

   *GENERATE INDICATOR FOR MISSING TEST SCORE
    gen `depvar'_median_0 = 0
    replace `depvar'_median_0 = 1 if `depvar' == .


    *REPLACE 2006 MEDIAN W/ 2005 SO THAT ALL EVACUEES ARE EVALUATED ON THEIR 2005 MEDIAN
    replace `depvar'_median_1 = l.`depvar'_median_1 if year == 2006
    replace `depvar'_median_2 = l.`depvar'_median_2 if year == 2006
    replace `depvar'_median_0 = l.`depvar'_median_0 if year == 2006

  }


    *GENERATE ENROLLMENT IN EACH SCHOOL IN GRADES 3 - 11
    egen enroll_campus_3_11 = sum(unit), by(campus year)
    gen tested_math = taks_sd_min_math != .
    gen tested_read = taks_sd_min_read != .
    egen tested_math_campus_3_11 = sum(tested_math), by(campus year)
    egen tested_read_campus_3_11 = sum(tested_read), by(campus year)  

  *GENEARTE EVACUEE FRACTIONS IN EACH QUARTILE
  foreach median of numlist 1/2 {
    gen katrina_median_`median'_math = katrina*taks_sd_min_math_median_`median'
    gen katrina_median_`median'_read = katrina*taks_sd_min_read_median_`median'
    egen katrina_count_math_median_`median' = sum(katrina_median_`median'_math), by (campus year)
    gen katrina_frac_math_median_`median' = katrina_count_math_median_`median'/tested_math_campus_3_11
    egen katrina_count_read_median_`median' = sum(katrina_median_`median'_read), by(campus year)
    gen katrina_frac_read_median_`median' = katrina_count_read_median_`median'/tested_read_campus_3_11
  }

keep campus year *median*

*COLLAPSE TO SUMMARY BY CAMPUS
collapse (mean) katrina_count*  katrina_frac*, by(campus year)


sort campus year
save /work/i/imberman/imberman/katrina_medians.dta, replace

*/