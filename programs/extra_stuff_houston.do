*===============================================================================
* FILE:     extra_stuff_houston.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Auxiliary / scratch (Houston / HISD) -- NOT a numbered table on its own
* PRODUCES: Supplementary correlations for the Houston analysis cited in the text /
*           footnotes / referee responses. Treat as auxiliary scratch.
*
* PURPOSE:  Houston (HISD) counterpart of extra_stuff.do. Builds pre-Katrina
*           lagged TAKS scores (and attendance/infractions lags), then reports
*           correlations of native lagged achievement with campus- and grade-level
*           evacuee shares (and an any-evacuee dummy) -- a quasi-random-placement
*           check -- at both the student level and the school-grade level, looping
*           over elementary and middle/high grade bands. The Hoxby-Weingarth-style
*           quartile-interaction setup is built but the value-added regressions
*           are not run here (this is a scratch/diagnostic file).
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta (HISD student panel),
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta
*           (katrina_medians.dta merge is commented out)
* OUTPUTS:  temp.dta (intermediate); correlation output to the log.
*
* KEY STEPS:
*   - Loop over grade band ("elem","midhigh"); open HISD panel; xtset id year.
*   - Build pre-Katrina (<=2004) lags of math/read/attendance/infractions and the
*     gap-interacted lag terms.
*   - Merge in pre-Katrina quartile data; build grade x year interactions.
*   - pwcorr of lagged native scores vs evacuee shares (student & school-grade).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - PATHS: absolute /work/i/imberman/imberman/katrina_data.dta,
*     pre_katrina_quartiles.dta (and commented katrina_medians.dta) -- repoint.
*   - l`lag'.year <= 2004 (lags restricted to pre-Katrina years) in the lag loop.
*   - Evacuee shares (katrina_frac_campus / katrina_frac_grade) are defined =0
*     pre-Katrina upstream in the input dataset.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS


clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****



*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  * ---- Open HISD panel ----
  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  * ---- Build pre-Katrina lags (<=2004) of scores/attendance/infractions ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sd_min_math taks_sd_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: lag must be pre-Katrina (<=2004)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004     // YEAR HARDCODE
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
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep   // PATH (disabled): repoint locally
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  * ---- Merge in pre-Katrina baseline quartile data ----
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint locally


  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0


* ===========================================================================
* ---- AUX: correlations of pre-Katrina native lag scores with evacuee shares ----
* (quasi-random-placement check; student level, then collapsed to school-grade)
* ===========================================================================
***CORRELATIONS OF PRE-KATRINA NATIVE SCORES WITH EVACUEE SHARES AND HAVING ANY EVACUEES IN SCHOOL

gen anyevac_school = katrina_frac_campus > 0 if katrina_frac_campus != .
gen anyevac_grade = katrina_frac_grade > 0 if katrina_frac_grade != .

pwcorr ltaks_sd_min_math katrina_frac_campus if taks_sd_min_math_quartile != .  & katrina_frac_campus > 0, sig
pwcorr ltaks_sd_min_math anyevac_school  if taks_sd_min_math_quartile != ., sig
pwcorr ltaks_sd_min_math katrina_frac_grade  if taks_sd_min_math_quartile != .  & katrina_frac_grade > 0, sig
pwcorr ltaks_sd_min_math anyevac_grade  if taks_sd_min_math_quartile != ., sig

pwcorr ltaks_sd_min_read katrina_frac_campus  if taks_sd_min_math_quartile != .  & katrina_frac_campus > 0, sig
pwcorr ltaks_sd_min_read anyevac_school  if taks_sd_min_math_quartile != ., sig
pwcorr ltaks_sd_min_read katrina_frac_grade  if taks_sd_min_math_quartile != .  & katrina_frac_grade > 0, sig
pwcorr ltaks_sd_min_read anyevac_grade  if taks_sd_min_math_quartile != ., sig

save temp, replace

* ---- AUX: same correlations collapsed to school-grade level (math) ----
**** PWCORR AT SCHOOL-GRADE LEVEL - MATH
keep if taks_sd_min_math_quartile != .
collapse (mean) ltaks_sd* katrina_frac* anyevac*, by(campus year grade)

pwcorr ltaks_sd_min_math katrina_frac_campus if  katrina_frac_campus > 0, sig
pwcorr ltaks_sd_min_math anyevac_school , sig
pwcorr ltaks_sd_min_math katrina_frac_grade if  katrina_frac_grade > 0, sig
pwcorr ltaks_sd_min_math anyevac_grade, sig

use temp, clear

* ---- AUX: same correlations collapsed to school-grade level (reading) ----
**** PWCORR AT SCHOOL-GRADE LEVEL - READ
keep if taks_sd_min_read_quartile != .
collapse (mean) ltaks_sd* katrina_frac* anyevac*, by(campus year grade)

pwcorr ltaks_sd_min_read katrina_frac_campus  if  katrina_frac_campus > 0, sig
pwcorr ltaks_sd_min_read anyevac_school , sig
pwcorr ltaks_sd_min_read katrina_frac_grade  if  katrina_frac_grade > 0, sig
pwcorr ltaks_sd_min_read anyevac_grade , sig



}

