*===============================================================================
* FILE:     katrina_by_quartiles_va_class.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston VA quartile peer-effects, CLASS level)
* PRODUCES: Appendix Tables 4 & 5 - the CLASSROOM-level evacuee-share row of the
*           Houston grade-level achievement robustness battery (elementary only,
*           where classroom links exist).
*
* PURPOSE:  Robustness check that measures the evacuee share at the CLASSROOM
*           level (katrina_frac_class) rather than school-grade. Restricted to
*           elementary grades (teacher/classroom identifiers available) and to
*           pre/initial years (year <= 2005) where the classroom assignment is
*           plausibly exogenous. First runs an EXOGENEITY test (regressing the
*           2004-05 native lagged scores on the 2005-06 classroom evacuee share),
*           then estimates the class-share effect on incumbent outcomes pooled
*           and within each pre-Katrina achievement quartile, writing results
*           with outreg2.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta  (with class/teacher ids)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (incumbent quartiles)
* OUTPUTS:  outreg_quartile_class.* (Excel) - class-level coefficients; plus log.
*
* KEY STEPS:
*   - Loop over grade level (elem only here).
*   - Build pre-Katrina test-score lags (lags <= 2004).
*   - Merge incumbent pre-Katrina achievement quartiles.
*   - Build classroom evacuee-count indicators and class size.
*   - EXOGENEITY TEST: regress lagged native scores on class evacuee share for
*     year <= 2005.
*   - Pooled class-share VA model (year <= 2005) and quartile-specific models,
*     each written to outreg_quartile_class.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and use/merge absolute paths -> PATH.
*   - l`lag'.year <= 2004 (twice) -> YEAR HARDCODE: pre-Katrina lags only.
*   - year <= 2005 (exogeneity test x4; pooled models; quartile models) ->
*     YEAR HARDCODE: classroom analysis restricted to the first post-Katrina
*     year and earlier (initial random classroom placement window).
*   - Commented bottom blocks reference year>=2005, year==2006 (Sept-2005 median
*     construction) -- update if reactivated.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE

*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS


*TESTS CLASS LEVEL REGRESSIONS


clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****



* ---- Working directory + clear stale outreg files ----
  cd /work/i/imberman/imberman/   // PATH: repoint to your local globals
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


*LOOP OVER GRADE LEVEL
foreach grade in "elem" {

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  * ---- Build pre-Katrina test-score lags (value-added controls) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: pre-Katrina lags only (<=2004)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: pre-Katrina lag (<=2004)
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1
  
  
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  * ---- Merge incumbent pre-Katrina achievement quartiles (BASELINE ACHIEVEMENT QUARTILES) ----
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint to your local globals

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0

* ---- Build classroom evacuee-count indicators and class size ----
*GENERATE EVACUEE COUNTS IN EACH CLASS
keep if katrina_count_class != .
gen katrina_class_0 = katrina_count_class == 0
gen katrina_class_1 = katrina_count_class == 1
gen katrina_class_2 = katrina_count_class == 2
gen katrina_class_3 = katrina_count_class >= 3
gen katrina_class_any = katrina_class_0 == 0
egen class_size = sum(unit), by(campus teacher_num grade year)

xi i.grade*i.year

gen double campusyeargrade = campus*1000000 + year*100  + grade

* ---- EXOGENEITY TEST: lagged native scores on classroom evacuee share ----
*TEST FOR EXOGENEITY BY REGRESSING 2005-06 KATRINA CLASS COUNT ON 2004-05 TEST SCORES OF NATIVES
areg ltaks_sd_min_math katrina_frac_class female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if year <= 2005, absorb(campus) cluster(campus)   // YEAR HARDCODE: initial placement window (<=2005)
areg ltaks_sd_min_read katrina_frac_class female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if year <= 2005, absorb(campus) cluster(campus)   // YEAR HARDCODE: <=2005
areg lperc_attn katrina_frac_class female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if year <= 2005, absorb(campus) cluster(campus)   // YEAR HARDCODE: <=2005
areg linfractions katrina_frac_class female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if year <= 2005, absorb(campus) cluster(campus)   // YEAR HARDCODE: <=2005

*GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
xi i.grade*i.year

* ---- Pooled class-share VA model (year<=2005), school FE; outreg2 -> App Tables 4/5 class row ----
*RUN LINEAR MODEL
  di ""
  di "POOLED LINEAR MODEL"
  di ""
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read{;
	areg `var'  katrina_frac_class  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if  year <= 2005 & `var'_quartile != ., cluster(campus) absorb(campus);   /* YEAR HARDCODE: <=2005 */
	outreg2 katrina_frac_class using outreg_quartile_class, excel nocons bdec(2);
  };
  foreach var of varlist perc_attn infractions {;
	areg `var'  katrina_frac_class  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if  year <= 2005, cluster(campus) absorb(campus);   /* YEAR HARDCODE: <=2005 */
	outreg2 katrina_frac_class using outreg_quartile_class, excel nocons bdec(2);
  };
  # delimit cr


 * ---- Re-estimate within each baseline achievement quartile (year<=2005); outreg2 quartile rows ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {
 
  di "" 
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	
	foreach var of varlist taks_sd_min_math taks_sd_min_read {;
		areg `var' katrina_frac_class  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*
			if `var'_quartile == `quartile' & year <= 2005, cluster(campus) absorb(campus);   /* YEAR HARDCODE: <=2005 */
		outreg2 katrina_frac_class using outreg_quartile_class, excel nocons bdec(2);

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


* NOTE: The block below is COMMENTED OUT (inactive). It builds evacuee
* fractions by 2005 score-median and saves katrina_medians.dta. Contains
* YEAR HARDCODEs (keep if year>=2005; median replaced if year==2006) and
* PATH absolutes -- repoint if reactivated.
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