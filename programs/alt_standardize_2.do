*===============================================================================
* FILE:     alt_standardize_2.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Louisiana alternative score standardization #2)
* PRODUCES: Intermediate dataset alternative_standardization_2.dta, feeding the
*           "alternative standardization 2" LA robustness (quartile_analysis_
*           revision_alt_standard2, App Table 38).
*
* PURPOSE:  A second alternative standardization of LA LEAP scale scores. Instead
*           of standardizing within every grade x year, it fixes the normalization
*           to a single base year (2003-04, i.e. year==2004). Because not all
*           grades were tested in 2003-04, the grade-4 mean/SD is applied to grades
*           1-5, the grade-8 mean/SD to grades 6-8, and the grade-10 mean/SD to
*           grades 9-10. Produces z-scores (mathSTD/elaSTD) plus per-year, lagged,
*           and pre-Katrina score variables.
*
* INPUTS:   LA_leap00_09.dta                 (raw LEAP scale scores 2000-2009)
*           la_prepped_revisionFULL_SAMPLE.dta (prepped LA student panel)
* OUTPUTS:  leap_scale.dta                   (collapsed min scale scores by id-year)
*           la_means_2004.dta                (2003-04 grade means/SDs, grade-filled)
*           alternative_standardization_2.dta (LA panel w/ z-scores + lags)
*
* KEY STEPS:
*   - Collapse LEAP scale scores to one (min) math/ela score per id-year.
*   - Keep year==2004, compute grade-level mean & SD, keep grades 4/8/10, then
*     input blank grade rows and back-fill (g4 -> 3&5, g8 -> 6&7, g10 -> 9).
*   - Reload full sample, merge means by grade_num, standardize to 2003-04 scale.
*   - Build per-year scores, lags, and most-recent pre-Katrina (2000-2005) score.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `replace grade = "10" if grade == "HS"`.
*   - `keep if year == 2004` — base-year for standardization (2003-04 scale).
*   - Grade-fill rule: grade-4 scale -> grades 3&5, grade-8 -> 6&7, grade-10 -> 9
*     (the input/replace block keyed on grade==4|8|10).
*   - `forvalues year = 2000/2007` per-year score loop (widen for new years).
*   - `forvalues year = 2005(-1)2000` pre-Katrina score (2005 = last pre-year).
*   - No absolute paths; all .dta refs are relative to the working directory.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
****ALTERNATIVE STANDARDIZATION 2***
***STANDARDIZE USING 2002-03 SCALE***
***SINCE NOT ALL GRADES TESTED IN 2003-04 - APPLY GRADE 4 SCALE TO GRADES 1 - 5, GRADE 8 SCALE TO 6 - 8, AND GRADE 10 SCALE TO GRADES 9 & 10***


* ---- Setup: clear memory, close logs, set RNG seed ----
clear
set mem 1900m
capture log close

set seed 10563

* ---- Collapse LEAP scale scores to one (min) score per id-year ----
*COLLAPSE SCALE SCORES
use LA_leap00_09.dta
replace grade = "10" if grade == "HS"
gen grade_num = real(grade)
replace math_scaled = math_scale if math_scaled == .
replace ela_scaled = ela_scale if ela_scaled == .
replace math_scaled = . if math_scaled == 0
replace ela_scaled = . if ela_scaled == 0
collapse (min) math_scaled ela_scaled grade_num, by(id year)
drop if math_scaled == . & ela_scaled == .
sort id year
save leap_scale.dta, replace



* ---- Load prepped sample and merge in raw scale scores ----
*STANDARDIZE
use la_prepped_revisionFULL_SAMPLE.dta
drop *scale*
sort id year
merge id year using leap_scale.dta

/*
*MAKE ORIGINAL AND NEW SAMPLES CONSISTENT
replace math_scaled = . if mathSTD == .
replace ela_scaled = . if elaSTD == .
*/

keep id year katrina_sum rita katrina_district2 district_code percent_katrina grade_num math_scale ela_scale


* ---- SCORE STANDARDIZATION (1/2): fix normalization to 2003-04 base year ----
*LIMIT TO 2003-04
keep if year == 2004   // YEAR HARDCODE: 2003-04 is the fixed base year for this alt standardization

collapse (mean) math_mean= math_scale ela_mean= ela_scale (sd) math_sd=math_scale ela_sd=ela_scale, by(grade)
sort grade
keep if grade == 4 | grade == 8 | grade == 10   // only grades 4/8/10 tested in 2003-04

* ---- Grade-fill: g4 scale -> grades 3&5, g8 -> 6&7, g10 -> 9 ----
input
3 . . . .
5 . . . .
6 . . . .
7 . . . . 
9 . . . .
end

sort grade
foreach var of varlist math_mean ela_mean math_sd ela_sd {
  replace `var' = `var'[2] if grade == 3 | grade == 5
  replace `var' = `var'[6] if grade == 6 | grade == 7
  replace `var' = `var'[8] if grade == 9
}

save la_means_2004.dta, replace


* ---- Reload full sample and merge in 2003-04 grade means/SDs ----
*LOAD DATA AGAIN
use la_prepped_revisionFULL_SAMPLE.dta, clear
sort id year
merge id year using leap_scale.dta

tab _merge
drop _merge

sort grade_num
merge grade_num using la_means_2004.dta
tab _merge
drop _merge


/*
*MAKE ORIGINAL AND NEW SAMPLES CONSISTENT
replace math_scaled = . if mathSTD == .
replace ela_scaled = . if elaSTD == .
*/

drop mathSTD elaSTD

* ---- SCORE STANDARDIZATION (2/2): z-score against fixed 2003-04 mean/SD ----
*STANDARDIZE
gen mathSTD = (math_scaled - math_mean)/math_sd
gen elaSTD = (ela_scaled - ela_mean)/ela_sd

* ---- Build per-year z-score variables math2000..2007 / ela2000..2007 ----
*GENERATE LAGS
drop math2*  ela2*
forvalues year = 2000/2007 {   // YEAR HARDCODE: per-year score loop 2000-2007; widen for new years
  gen math`year'a = mathSTD if year == `year'
  egen math`year' = max(math`year'a), by(id)
  drop math`year'a

  gen ela`year'a = elaSTD if year == `year'
  egen ela`year' = max(ela`year'a), by(id)
  drop ela`year'a
}

drop math_lag* ela_lag*
sort id year
capture drop check1
gen check1=1 if id==id[_n-1]
gen math_lag=mathSTD[_n-1] if check1==1 & mathSTD!=. & mathSTD[_n-1]!=.
gen math_lagyear=year[_n-1] if check1==1 & mathSTD!=. & mathSTD[_n-1]!=.
gen math_laggrade=grade[_n-1] if check1==1 & mathSTD!=. & mathSTD[_n-1]!=.


sort id year ela_raw
gen ela_lag= elaSTD[_n-1] if check1==1 & elaSTD!=. & elaSTD[_n-1]!=.
gen ela_lagyear=year[_n-1] if check1==1 & elaSTD!=. & elaSTD[_n-1]!=.
gen ela_laggrade= grade[_n-1] if check1==1 & elaSTD!=. & elaSTD[_n-1]!=.


* ---- Most-recent pre-Katrina (2000-2005) z-score: math0005 / ela0005 ----
drop math0005 ela0005
gen math0005 = .
gen ela0005 = .
forvalues year = 2005(-1)2000 {   // YEAR HARDCODE: walk back from 2005 (last pre-Katrina year) to 2000
  replace math0005 = math`year' if math0005 == .
  replace ela0005 = ela`year' if ela0005 == .
}

* ---- Save alt-standardization-2 LA panel ----
sort id year
save alternative_standardization_2.dta, replace

