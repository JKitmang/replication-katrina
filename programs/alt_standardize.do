*===============================================================================
* FILE:     alt_standardize.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Dataset construction (Louisiana alternative score standardization)
* PRODUCES: Intermediate dataset alternative_standardization.dta, which feeds the
*           main LA quartile/peer analyses (e.g. quartile_analysis_revision_d and
*           the "alternative standardization" robustness, App Table 38).
*
* PURPOSE:  Standardizes LA LEAP scale scores within grade x year, but computes
*           the standardizing mean and SD using ONLY never-Katrina students in
*           non-Katrina districts/schools (everkatrina==0, katrina_district2==0,
*           percent_katrina<.7). This removes any mechanical effect of the
*           evacuee influx on the normalization. Produces z-scores (mathSTD/elaSTD)
*           plus the per-year, lagged, and pre-Katrina score variables.
*
* INPUTS:   LA_leap00_09.dta                 (raw LEAP scale scores 2000-2009)
*           la_prepped_revisionFULL_SAMPLE.dta (prepped LA student panel)
* OUTPUTS:  leap_scale.dta                   (collapsed min scale scores by id-year)
*           la_means.dta                     (grade x year means/SDs on clean sample)
*           alternative_standardization.dta  (LA panel w/ z-scores + lags)
*
* KEY STEPS:
*   - Collapse LEAP scale scores to one (min) math/ela score per id-year.
*   - Recode evacuee flags (Rita -> Katrina; Cameron/Calcasieu -> Katrina dist).
*   - Restrict to never-Katrina, non-Katrina-district sample; compute grade x year
*     mean & SD; save la_means.dta.
*   - Reload full sample, merge means, standardize: STD = (scale - mean)/sd.
*   - Build per-year scores, lags, and most-recent pre-Katrina (2000-2005) score.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `replace grade = "10" if grade == "HS"`.
*   - Cameron/Calcasieu district codes 10 & 12 forced into katrina_district2.
*   - `percent_katrina < .7` clean-sample threshold.
*   - `forvalues year = 2000/2007` per-year score loop (widen for new years).
*   - `forvalues year = 2005(-1)2000` pre-Katrina score (2005 = last pre-year).
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



* ---- Load prepped sample, merge raw scale scores, recode evacuee flags ----
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


gen cameron_calcasieu=0
replace cameron_calcasieu=1 if district_code==10 | district_code==12   // district codes 10 & 12 = Cameron/Calcasieu (Rita-affected)


* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1



***********************************************
***********************************************

***************************
* redefine percent katrina
****************************
***********************************************
***********************************************
***********************************************

* create katrina_district3 which is a variable for EVER being in a katrina district

egen katrina_district3=max(katrina_district2), by(id)

replace katrina_district3=0 if katrina_district3==.

** do it within school and grade and class 
** include the Rita kids as katrina kids

capture drop percent_katrinaTIMESERIES2

**
replace katrina_sum=1 if rita==1

* make kids with missing katrina_sum 0 if katrina_district3 is 0

replace katrina_sum=0 if katrina_sum==. & katrina_district3==0



* ---- SCORE STANDARDIZATION (1/2): grade x year mean & SD on clean sample ----
* Use only never-Katrina students in non-evacuee districts/schools, so the
* normalization is unaffected by the evacuee influx.
*RESTRICT TO STANDARDIZING SAMPLE TO GET MEAN & SD BY GRADE AND YEAR
egen everkatrina = max(katrina_sum), by(id)
keep if everkatrina == 0 & katrina_district2 == 0 & percent_katrina < .7   // clean standardizing sample; .7 share threshold hardcoded

collapse (mean) math_mean= math_scale ela_mean= ela_scale (sd) math_sd=math_scale ela_sd=ela_scale, by(grade year)
sort grade year
save la_means.dta, replace


* ---- Reload full sample and merge in grade x year means/SDs ----
*LOAD DATA AGAIN
use la_prepped_revisionFULL_SAMPLE.dta, clear
sort id year
merge id year using leap_scale.dta

tab _merge
drop _merge

sort grade_num year
merge grade_num year using la_means.dta
tab _merge
drop _merge


/*
*MAKE ORIGINAL AND NEW SAMPLES CONSISTENT
replace math_scaled = . if mathSTD == .
replace ela_scaled = . if elaSTD == .
*/

drop mathSTD elaSTD

* ---- SCORE STANDARDIZATION (2/2): z-score each student's scale score ----
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

* ---- Save alternatively-standardized LA panel ----
sort id year
save alternative_standardization.dta, replace

