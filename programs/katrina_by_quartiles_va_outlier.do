*===============================================================================
* FILE:     katrina_by_quartiles_va_outlier.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Houston value-added quartile analysis)
* PRODUCES: Appendix Tables 4, 5 & 41 (one column/panel of the Houston
*           grade-level achievement and behavior robustness batteries):
*           the "drop high-evacuee-share schools" outlier specification.
*
* PURPOSE:  Re-estimates the Houston value-added peer-effect regressions after
*           DROPPING schools that received an unusually large share of Katrina
*           evacuees in 2005-06 (>10% of enrollment), to confirm the headline
*           quartile results are not driven by a handful of high-exposure
*           campuses. Outcomes are standardized math/reading TAKS scores,
*           attendance, and infractions; effects are estimated overall and
*           separately within each pre-Katrina achievement quartile.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta      (analysis panel)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (quartile sort)
* OUTPUTS:  Regression output to the log only (no table file is written here;
*           coefficients are transcribed into the appendix tables).
*
* KEY STEPS:
*   - Loop over grade band (elem / midhigh).
*   - Build pre-Katrina lagged test/attendance/infraction controls.
*   - Drop the 8 high-evacuee-share outlier campuses.
*   - Merge in pre-Katrina achievement quartiles.
*   - Run pooled value-added areg, then loop over quartiles 1-4.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/  (absolute working dir; repoint to globals)
*   - all use/merge paths /work/i/imberman/imberman/*.dta
*   - lag-construction cutoff `l`lag'.year <= 2004` (last pre-Katrina year)
*   - outlier campus ID list (23 17 227 273 60 72 271 253) is data/year-specific
*   - commented-out block uses year>=2005, year==2006 for evacuee-median build
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

*RUNS MODELS THAT DROP SCHOOS WITH VERY HIGH KATRINA SHARES IN 2005-06

*DROP ANY SCHOOL THAT HAS > 10% KATRINA IN 0506
  *CAMPUS ID'S 23, 17, 227, 273, 60, 72, 271, 253

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
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: 2004 = last pre-Katrina year; only pre-treatment lags allowed
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004     // YEAR HARDCODE: 2004 = last pre-Katrina year
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  * ---- OUTLIER TRIM: drop the 8 schools with >10% evacuees in 2005-06 ----
  *DROP OUTLIER SCHOOLS
  drop if campus == 23 | campus == 17 | campus == 227 | campus == 273 | campus == 60 | campus == 72 | campus == 271 | campus == 253   // DATA HARDCODE: high-evacuee campus IDs are sample/year-specific; recompute for new years

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1
  
  
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



*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- POOLED value-added regressions (all quartiles): evacuee share -> outcome ----
  # delimit ;
  foreach var of varlist taks_sd_min_math taks_sd_min_read {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if `var'_quartile != ., cluster(campus) absorb(campus);
  };
  # delimit cr

  # delimit ;
  foreach var of varlist perc_attn infractions{;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I*, cluster(campus) absorb(campus);
  };
  # delimit cr


 * ---- BY-QUARTILE value-added regressions (interaction of evacuee share x incumbent quartile) ----
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

*CLOSE GRADE LOOP;
};