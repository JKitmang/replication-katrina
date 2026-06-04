*===============================================================================
* FILE:     alt_scale.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Dataset construction (Louisiana raw clean, scale-score version)
* PRODUCES: Intermediate dataset alternative_scaled.dta (raw LEAP scale scores,
*           lagged, feeding the LA scale-score robustness specifications, e.g.
*           App Table 29 quartile_analysis_revision_full_scale).
*
* PURPOSE:  Builds a student-by-year LA panel that carries RAW (un-standardized)
*           LEAP scale scores rather than within grade-year z-scores. It collapses
*           the LEAP scale-score file to one min score per id-year, merges those
*           raw scores onto the prepped LA sample together with the alternatively-
*           standardized data, then generates the lagged-score and 2000-2005
*           "most-recent pre-Katrina score" variables used downstream.
*
* INPUTS:   LA_leap00_09.dta                 (raw LEAP scale scores 2000-2009)
*           la_prepped_revisionFULL_SAMPLE.dta (prepped LA student panel)
*           alternative_standardization.dta  (output of alt_standardize.do)
* OUTPUTS:  leap_scale.dta                   (collapsed min scale scores by id-year)
*           alternative_scaled.dta           (LA panel w/ raw scale scores + lags)
*
* KEY STEPS:
*   - Collapse LEAP scale scores to one (min) math/ela score per id-year.
*   - Merge raw scale scores + alternative standardization onto prepped sample.
*   - Force new and original samples consistent (drop where STD is missing).
*   - Build per-year score variables math2000..math2007 / ela2000..ela2007.
*   - Build most-recent lag (math_lag/ela_lag) and 2000-2005 pre-Katrina score.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `replace grade = "10" if grade == "HS"` (HS coded as grade 10).
*   - `forvalues year = 2000/2007` per-year score loop (widen for new years).
*   - `forvalues year = 2005(-1)2000` building math0005/ela0005 = most recent
*     pre-Katrina (2000-2005) score; 2005 is the last pre-treatment year.
*   - No absolute paths; all .dta refs are relative to the working directory.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
****ALTERNATIVE STANDARDIZATION***
***USE ONLY NEVER KATRINA STUDENTS IN NON-KATRINA DISTRICTS & SCHOOLS***

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


* ---- Load prepped LA panel and merge in alt-standardized + raw scale scores ----
use la_prepped_revisionFULL_SAMPLE.dta

*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using alternative_standardization.dta
drop _merge


drop *scale*
sort id year
merge id year using leap_scale.dta


*MAKE ORIGINAL AND NEW SAMPLES CONSISTENT
replace math_scaled = . if mathSTD == .
replace ela_scaled = . if elaSTD == .


* ---- Build per-year score variables math2000..2007 / ela2000..2007 ----
*GENERATE LAGS
drop math2*  ela2*
forvalues year = 2000/2007 {   // YEAR HARDCODE: per-year score loop 2000-2007; widen for new years
  gen math`year'a = math_scaled if year == `year'
  egen math`year' = max(math`year'a), by(id)
  drop math`year'a

  gen ela`year'a = ela_scaled if year == `year'
  egen ela`year' = max(ela`year'a), by(id)
  drop ela`year'a
}

drop math_lag* ela_lag*
sort id year
capture drop check1
gen check1=1 if id==id[_n-1]
gen math_lag=math_scaled[_n-1] if check1==1 & math_scaled!=. & math_scaled[_n-1]!=.
gen math_lagyear=year[_n-1] if check1==1 & math_scaled!=. & math_scaled[_n-1]!=.
gen math_laggrade=grade[_n-1] if check1==1 & math_scaled!=. & math_scaled[_n-1]!=.


sort id year ela_raw
gen ela_lag= ela_scaled[_n-1] if check1==1 & ela_scaled!=. & ela_scaled[_n-1]!=.
gen ela_lagyear=year[_n-1] if check1==1 & ela_scaled!=. & ela_scaled[_n-1]!=.
gen ela_laggrade= grade[_n-1] if check1==1 & ela_scaled!=. & ela_scaled[_n-1]!=.


* ---- Most-recent pre-Katrina (2000-2005) score: math0005 / ela0005 ----
drop math0005 ela0005
gen math0005 = .
gen ela0005 = .
forvalues year = 2005(-1)2000 {   // YEAR HARDCODE: walk back from 2005 (last pre-Katrina year) to 2000
  replace math0005 = math`year' if math0005 == .
  replace ela0005 = ela`year' if ela0005 == .
}

* ---- Save raw-scale LA panel ----
sort id year
save alternative_scaled.dta, replace

