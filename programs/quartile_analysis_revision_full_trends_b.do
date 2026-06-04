*===============================================================================
* FILE:     quartile_analysis_revision_full_trends_b.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (Louisiana quartile peer-effects analysis)
* PRODUCES: Appendix Tables 23 & 24 (LA quartile peer effects WITH school-specific
*           linear time trends -- "Full Trend" and "Partial Trend" specifications)
*
* PURPOSE:  Re-estimates the LA non-linear (by-quartile) peer-effects regressions
*           after adding school-specific linear time trends to the controls, to
*           check that the cross-quartile pattern is not an artifact of differential
*           pre-trends across schools. Native (non-evacuee) standardized test scores
*           are regressed on the school*grade*year share of Katrina/Rita evacuees in
*           each baseline-achievement quartile, separately by the native student's
*           own baseline quartile, for elementary (no lag) and middle/high (lagged
*           dependent variable) samples, in math and ELA.
*
* INPUTS:   la_prepped_revisionFULL_SAMPLE.dta  (main LA student-year panel)
*           alternative_standardization.dta     (statewide-standardized scores: *STD)
*           discipline_prepped_microdata.dta    (discipline records)
*           tanumbers06-09_prepped2.dta         (test-administrator / class IDs)
* OUTPUTS:  elem_trend.xls   (elementary, grades<=5 -> App Table 23/24 panels)
*           midhigh_trend.xls(middle/high, grades>5, lag sample -> App Table 23/24)
*
* KEY STEPS:
*   - Load FULL_SAMPLE; merge in statewide-standardized scores, discipline, TA data.
*   - Build baseline math/ELA achievement quartiles within grade*year (mathQD*, elaQD*).
*   - Restrict to grades 4-10, years 2000-2007; define the "lag sample" by grade.
*   - Redefine percent-Katrina (incl. Rita; add Cameron/Calcasieu to evac districts).
*   - Build Kfraction_*Q*G = school*grade*year share of evacuees in each quartile.
*   - Build year-gap-interacted lagged scores (math_lag_*, ela_lag_*).
*   - Keep natives only; add school-specific linear trends (xi i.sitecode*time).
*   - Run FULL TREND then PARTIAL TREND regressions, overall and by native quartile.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/la_data           (absolute path; repoint)
*   - commented Windows path: D:\School\Katrina\LA DOE\Revision
*   - keep if year >= 2000 & year <= 2007            (analysis window)
*   - drop if year==2006/2007 & grade==4/5           (untested grade-years)
*   - lagsample thresholds: year>2001(g10), >2003(g8), >2005(g6/7/9)
*   - replace math/ela_lag = ...0005 if year>2005    (cap lag at pre-Katrina score)
*   - math0004 = math2004/2003 baseline-sort source years
*   - percent_rita / percent_katrina / Kfraction* = 0 if year<=2005 (pre-treatment)
*   - discipline05a defined if year==2005
*   - forvalues year=2000/2005 lag-year backfill loop
*   - gen time = year - 2001                          (trend origin year)
*   - replace _IsitX* = 0 if year>=2006               (Partial Trend cutoff)
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
****ADDS SCHOOL-SPECIFIC LINEAR TRENDS****


* 7.14.10  we switched to using the entire data set...so recode as 0 ( iei non-katrina all students who were never in a Katrina or Rita district)

* 6.24.10 I prepped the TA (test administrator numbers) for 2006-2009...and merge in...test the bad apple model

* 4/22/10  I switched to using scaled scores, try lagged dependent variable on rhs..I've updated the lag to use data back to 2000

* run it with and without lagged dependent
* run it defining percent katrina at school*year and school*year*grade level


* for the lagged dependent variable (math_lag and ela_lag) , I start with the most recent lag.  I then insist that the lag be a pre-katrina score...so in 2007 I allow a 2006 score to be the lag

* for the quartiles of katrina kids performance I use the most recent test score 

* one remaining issue is how I classify non-evacuees into quartiles...I previously used 2000-2005 data which is a little wierd bc those years are also included in the regression

* now I predict math and ela scores and sort into quartiles off predicted values

clear
set mem 8000m
set matsize 4000
capture log close

set seed 10563

*cd "D:\School\Katrina\LA DOE\Revision"   // PATH: repoint to your local globals (commented-out Windows path)
*log using la_log2_quartiles, text replace

* 6.14 try another run in which I use the true lag rather than capping at 2005
set more off

* ---- Load main LA student-year panel ----
cd /work/i/imberman/imberman/la_data   // PATH: repoint to your local globals

use la_prepped_revisionFULL_SAMPLE.dta
* sample 5

drop  gender district_name school_name birth_month birth_day birth_year ela_raw ela_scale math_raw math_scale sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


* ---- Merge in statewide-standardized scores (score standardization: *STD vars) ----
*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using alternative_standardization.dta
drop _merge



* ---- BASELINE ACHIEVEMENT QUARTILES: sort students into within-grade*year quartiles of math0005/ela0005 ----
* fix the quartile analysis...calculate within each year rather than limiting to 2006

capture drop mathQUART elaQUART
capture drop mathQUARTa elaQUARTa

bysort grade_num year: quantiles math0005, gen(mathQUART) nq(4) stable
bysort grade_num year: quantiles ela0005, gen(elaQUART) nq(4) stable

capture drop mathQD*
capture drop elaQD*

tab mathQUART, gen(mathQD)
tab elaQUART, gen(elaQD)



* ---- Grade/year sample restrictions ----
*MAKE GRADE/YEAR RESTRICTIONS

keep if year >= 2000 & year <= 2007   // YEAR HARDCODE: analysis window 2000-2007; widen for new years
keep if grade_num >= 4 & grade_num <= 10
drop if year == 2006 & grade_num == 4   // YEAR HARDCODE: grade 4 not tested in 2006
drop if year == 2007 & grade_num == 4   // YEAR HARDCODE: grade 4 not tested in 2007
drop if year == 2007 & grade_num == 5   // YEAR HARDCODE: grade 5 not tested in 2007


* ---- Identify the lag sample (grades/years where a lagged score is available) ----
*IDENTIFY THE LAG SAMPLE
gen lagsample = 0
replace lagsample = 1 if year > 2001 & grade_num == 10   // YEAR HARDCODE: lag available for g10 from 2002
replace lagsample = 1 if year > 2003 & grade_num == 8     // YEAR HARDCODE: lag available for g8 from 2004
replace lagsample = 1 if year > 2005 & (grade_num == 6 | grade_num == 7 | grade_num == 9)   // YEAR HARDCODE: g6/7/9 from 2006



summ mathSTD elaSTD

tab year
*********************************************************************
* drop all the old grade year interactions and use gradenum instead
*********************************************************************


drop gryr*


* ---- Grade x year fixed-effect dummies ----
xi i.grade_num*i.year, prefix(gryr)


* ---- Cap lagged dependent variable at last pre-Katrina score ----
* make the lags all pre-katrina scores
* it is the most recent lag but always pre-katrina
* save originals as math_lag2 and ela_lag2

gen math_lag2=math_lag
gen ela_lag2=ela_lag
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-Katrina obs use pre-2005 score as lag
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE: post-Katrina obs use pre-2005 score as lag


* ---- BASELINE ACHIEVEMENT QUARTILES (alt source: 2004/2003 scores) for sorting students ----
* get baseline score for sorting students
gen math0004=math2004
replace math0004=math2003 if math0004==. & math2003!=.
* replace math0004=math2002 if math0004==. & math2002!=.
* replace math0004=math2001 if math0004==. & math2001!=.
* replace math0004=math2000 if math0004==. & math2000!=.
bysort grade_num year: quantiles math0004 , gen(math_0004QUART) nq(4) stable

gen ela0004=ela2004
replace ela0004=ela2003 if ela0004==. & ela2003!=.
* replace ela0004=ela2002 if ela0004==. & ela2002!=.
* replace ela0004=ela2001 if ela0004==. & ela2001!=.
* replace ela0004=ela2000 if ela0004==. & ela2000!=.
bysort grade_num year: quantiles ela0004 , gen(ela_0004QUART) nq(4) stable





* make 2005 and all its interactions with each grade the ommitted category
*drop gryr*_2005


* ---- Merge in discipline microdata ----
***********************************
* merge in the discipline data
***********************************
capture drop _m
sort id year

merge id year, using discipline_prepped_microdata

tab _m

drop if _m==2


* ---- Merge in test-administrator numbers (used to define classes) ----
***********************************
* merge in the test administrator data
***********************************
capture drop _m
sort id year

merge id year, using tanumbers06-09_prepped2.dta

tab _m

drop if _m==2


summ mathSTD elaSTD

tab year



* identify my class using TA numbers

egen class=group(sitecode year elamthtanumber)

***********************************
* recode the discipline data: missing means no discpline record for that student
***********************************
rename discpline_any discipline_any
recode discipline_any .=0

recode  disciplinedaycnt .=0

recode free_lunchA .=0 3=.

* ---- Flag Cameron/Calcasieu (Rita-affected) districts, later folded into evac area ----
* define a dummy for cameron and calcasiu parishes

gen cameron_calcasieu=0
replace cameron_calcasieu=1 if district_code==10 | district_code==12



* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1


* ---- Define school*year share of Rita evacuees (0 in pre-treatment years) ----
* define percent Rita

egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: no evacuees before 2005-06


***********************************************
***********************************************

***************************
* redefine percent katrina
****************************
* ---- INSTRUMENT/TREATMENT VAR: redefine evacuee share. Whole-state sample => natives
*      who were never in a Katrina/Rita district are coded katrina_sum=0; Rita kids
*      counted as evacuees; share set to 0 in pre-treatment years. ----
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

egen percent_katrinaTIMESERIES2=mean(katrina_sum), by(district_code school_code year)
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: 0 evacuees pre-2005-06

egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE: 0 evacuees pre-2005-06




* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

* ---- Bad-apple measure: peer share of evacuees who had a 2005 discipline record ----
gen discipline05a=discipline_any if year==2005   // YEAR HARDCODE: baseline discipline measured in 2005

egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005   // YEAR HARDCODE: 0 evacuees pre-2005-06


* count the number of katrina kids in my class
egen count_katrinaDISCIPLINE_class=sum(katrina_sum*discipline05), by(class)
replace count_katrinaDISCIPLINE_class=. if sitecode==. | elamth==.

egen count_katrina_class=sum(katrina_sum), by(class)
replace count_katrina_class=. if sitecode==. | elamth==.


**********************
* determine if we see a student two years in a row and whether or not they have switched schools

* non switchers are those observed two consecutive years and have the same school code both times
capture drop switch

sort id year
gen switch =0 if id==id[_n-1] & year==year[_n-1]+1 & sitecode==sitecode[_n-1] & sitecode!=.
replace switch =1 if id==id[_n-1] & year==year[_n-1]+1 & sitecode!=sitecode[_n-1] & sitecode!=.



* ---- (DISABLED, wrapped in /* ... */ below) auxiliary decile-distribution
*      comparison of natives vs evacuees; not part of App Tables 23/24 ----
****************************************************
* create the distribution graph for Scott and Adriana
***************************************************

* run a collapse command to get the 04 05 percentiles of math and ela scores
/*
collapse (p10) mathp10=mathSTD elap10=elaSTD  (p20) mathp20=mathSTD elap20=elaSTD  (p30) mathp30=mathSTD elap30=elaSTD  (p40) mathp40=mathSTD elap40=elaSTD  (p50) mathp50=mathSTD elap50=elaSTD  (p60) mathp60=mathSTD elap60=elaSTD  (p70) mathp70=mathSTD elap70=elaSTD  (p80) mathp80=mathSTD elap80=elaSTD  (p90) mathp90=mathSTD elap90=elaSTD   if year==2005 | year==2004, by(sitecode)

sort sitecode
save percentiles0405, replace
endsas;


* merge in test score percentiles for each school based on 04 05 data
drop _m

sort sitecode

merge sitecode using percentiles0405


* for each every student in 2006, ask what percentile of 2004/ 2005 distribution they would fall in

gen math_decile1=0 if mathSTD!=. & year==2006
gen math_decile2=0 if mathSTD!=. & year==2006
gen math_decile3=0 if mathSTD!=. & year==2006
gen math_decile4=0 if mathSTD!=. & year==2006
gen math_decile5=0 if mathSTD!=. & year==2006
gen math_decile6=0 if mathSTD!=. & year==2006
gen math_decile7=0 if mathSTD!=. & year==2006
gen math_decile8=0 if mathSTD!=. & year==2006
gen math_decile9=0 if mathSTD!=. & year==2006
gen math_decile10=0 if mathSTD!=. & year==2006


replace math_decile1=1 if year==2006 & mathSTD!=. & mathSTD<=mathp10
replace math_decile2=1 if year==2006 & mathSTD>mathp10 & mathSTD<=mathp20
replace math_decile3=1 if year==2006 & mathSTD>mathp20 & mathSTD<=mathp30
replace math_decile4=1 if year==2006 & mathSTD>mathp30 & mathSTD<=mathp40
replace math_decile5=1 if year==2006 & mathSTD>mathp40 & mathSTD<=mathp50
replace math_decile6=1 if year==2006 & mathSTD>mathp50 & mathSTD<=mathp60
replace math_decile7=1 if year==2006 & mathSTD>mathp60 & mathSTD<=mathp70
replace math_decile8=1 if year==2006 & mathSTD>mathp70 & mathSTD<=mathp80
replace math_decile9=1 if year==2006 & mathSTD>mathp80 & mathSTD<=mathp90
replace math_decile10=1 if year==2006 & mathSTD!=. & mathSTD>mathp90



gen ela_decile1=0 if elaSTD!=. & year==2006
gen ela_decile2=0 if elaSTD!=. & year==2006
gen ela_decile3=0 if elaSTD!=. & year==2006
gen ela_decile4=0 if elaSTD!=. & year==2006
gen ela_decile5=0 if elaSTD!=. & year==2006
gen ela_decile6=0 if elaSTD!=. & year==2006
gen ela_decile7=0 if elaSTD!=. & year==2006
gen ela_decile8=0 if elaSTD!=. & year==2006
gen ela_decile9=0 if elaSTD!=. & year==2006
gen ela_decile10=0 if elaSTD!=. & year==2006


replace ela_decile1=1 if year==2006 & elaSTD!=. & elaSTD<=elap10
replace ela_decile2=1 if year==2006 & elaSTD>elap10 & elaSTD<=elap20
replace ela_decile3=1 if year==2006 & elaSTD>elap20 & elaSTD<=elap30
replace ela_decile4=1 if year==2006 & elaSTD>elap30 & elaSTD<=elap40
replace ela_decile5=1 if year==2006 & elaSTD>elap40 & elaSTD<=elap50
replace ela_decile6=1 if year==2006 & elaSTD>elap50 & elaSTD<=elap60
replace ela_decile7=1 if year==2006 & elaSTD>elap60 & elaSTD<=elap70
replace ela_decile8=1 if year==2006 & elaSTD>elap70 & elaSTD<=elap80
replace ela_decile9=1 if year==2006 & elaSTD>elap80 & elaSTD<=elap90
replace ela_decile10=1 if year==2006 & elaSTD!=. & elaSTD>elap90


* now summ these decile dummies for native students versus katrina students in the relevant schools

summ math_decile* ela_decile* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3


summ math_decile* ela_decile* if katrina_sum==1 & katrina_district2==0 & percent_katrina<.3

endsas;
*/






* ---- PEER QUARTILE SHARES: fraction of all peers in each baseline quartile (school*year) ----
* get fraction of all peers who are in each quartile
egen fraction_mathQ1=mean(mathQD1), by(district_code school_code year)
egen fraction_mathQ2=mean(mathQD2), by(district_code school_code year)
egen fraction_mathQ3=mean(mathQD3), by(district_code school_code year)
egen fraction_mathQ4=mean(mathQD4), by(district_code school_code year)


egen fraction_elaQ1=mean(elaQD1), by(district_code school_code year)
egen fraction_elaQ2=mean(elaQD2), by(district_code school_code year)
egen fraction_elaQ3=mean(elaQD3), by(district_code school_code year)
egen fraction_elaQ4=mean(elaQD4), by(district_code school_code year)





* ---- KEY REGRESSORS: school*year share of EVACUEE peers in each baseline quartile ----
* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1=mean(mathQD1*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ2=mean(mathQD2*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ3=mean(mathQD3*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ4=mean(mathQD4*katrina_sum), by(district_code school_code year)


egen Kfraction_elaQ1=mean(elaQD1*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ2=mean(elaQD2*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ3=mean(elaQD3*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ4=mean(elaQD4*katrina_sum), by(district_code school_code year)





replace Kfraction_mathQ1=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06
replace Kfraction_mathQ2=0 if year<=2005
replace Kfraction_mathQ3=0 if year<=2005
replace Kfraction_mathQ4=0 if year<=2005

replace Kfraction_elaQ1=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06
replace Kfraction_elaQ2=0 if year<=2005
replace Kfraction_elaQ3=0 if year<=2005
replace Kfraction_elaQ4=0 if year<=2005




* ---- KEY REGRESSORS (grade level): school*GRADE*year evacuee share by quartile (the *G vars used in regressions) ----
** Now calculate the fraction of katrina peers within each school district code and gradenum

* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1G=mean(mathQD1*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_mathQ2G=mean(mathQD2*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_mathQ3G=mean(mathQD3*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_mathQ4G=mean(mathQD4*katrina_sum), by(district_code school_code year grade_num)


egen Kfraction_elaQ1G=mean(elaQD1*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_elaQ2G=mean(elaQD2*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_elaQ3G=mean(elaQD3*katrina_sum), by(district_code school_code year grade_num)
egen Kfraction_elaQ4G=mean(elaQD4*katrina_sum), by(district_code school_code year grade_num)





replace Kfraction_mathQ1G=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06
replace Kfraction_mathQ2G=0 if year<=2005
replace Kfraction_mathQ3G=0 if year<=2005
replace Kfraction_mathQ4G=0 if year<=2005

replace Kfraction_elaQ1G=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06
replace Kfraction_elaQ2G=0 if year<=2005
replace Kfraction_elaQ3G=0 if year<=2005
replace Kfraction_elaQ4G=0 if year<=2005



* ---- Year-gap interactions: split lagged score by # years between current obs and the lag ----
**************
** try interacting lag with number of years between now and lag
**************
gen math_lagyear2=math_lagyear
gen ela_lagyear2=ela_lagyear

replace math_lagyear = . if year > 2005   // YEAR HARDCODE: recompute lag-year only for post-Katrina obs
replace ela_lagyear = . if year > 2005
forvalues year = 2000/2005 {              // YEAR HARDCODE: candidate pre-Katrina lag years 2000-2005
  replace math_lagyear = `year' if math0005 == math`year' & math_lag != . & year > 2005
  replace ela_lagyear = `year' if ela0005 == ela`year' & ela_lag != . & year > 2005
}

gen year_gap=year-math_lagyear
tab year_gap, gen(year_gapD)


gen year_gapE=year-ela_lagyear
tab year_gapE, gen(year_gapED)



gen math_lag_1=math_lag*year_gapD1
gen math_lag_2=math_lag*year_gapD2
gen math_lag_3=math_lag*year_gapD3
gen math_lag_4=math_lag*year_gapD4
gen math_lag_5=math_lag*year_gapD5
gen math_lag_6=math_lag*year_gapD6
gen math_lag_7=math_lag*year_gapD7



gen ela_lag_1=ela_lag*year_gapED1
gen ela_lag_2=ela_lag*year_gapED2
gen ela_lag_3=ela_lag*year_gapED3
gen ela_lag_4=ela_lag*year_gapED4
gen ela_lag_5=ela_lag*year_gapED5
gen ela_lag_6=ela_lag*year_gapED6
gen ela_lag_7=ela_lag*year_gapED7



* ---- ESTIMATION SAMPLE: natives only, in non-evac-area schools, <70% evacuee ----
*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7


cap rm elem_trend.txt
cap rm elem_trend.xls

cap rm midhigh_trend.txt
cap rm midhigh_trend.xls


**************
** Overall Table ***
**************

*******************************
*******************************
*** Show that the pattern holds even before we split into quantiles of own ability
*******************************
*******************************

* ---- FULL TREND specification: school-specific linear trends over full window ----
*      (xi i.sitecode*time creates _IsitX* school-trend terms) -> App Tables 23 & 24
gen time = year - 2001   // YEAR HARDCODE: trend origin = 2001 (time=0 in 2001)
xi i.sitecode*time

*ELEMENTARY
* App Table 23/24 "Full Trend" -- elementary (grades<=5), math, ALL natives
reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if mathQD1 != . & grade_num <= 5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, All")

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if elaQD1 != . & grade_num <= 5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, All")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & mathQD1 != . & grade_num >5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, All")

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & elaQD1 != . & grade_num >5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, All")

* ---- FULL TREND, by native baseline quartile (loop quart=1..4) -> App Tables 23/24 ----
****************************
** BY NATIVE LAGGED SCORE QUARTILE**
****************************


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*ELEMENTARY
* App Table 23/24 "Full Trend" -- elementary, math, native quartile `quart'
reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if mathQD`quart' == 1 & grade_num <= 5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, Math, Quartile `quart'")

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if elaQD`quart' == 1 & grade_num<=5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Quartile `quart'")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & mathQD`quart' == 1 & grade_num>5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, Math, Quartile `quart'")

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & elaQD`quart' == 1 & grade_num>5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Full Trend, ELA, Quartile `quart'")

}


* ---- PARTIAL TREND specification: zero out school trends in post-Katrina years ----
*      (school trends only fit pre-2006 data) -> App Tables 23 & 24
****PARTIAL TREND****


foreach var of varlist _IsitX* {
  replace `var' = 0 if year >= 2006   // YEAR HARDCODE: trends apply pre-2006 only (Partial Trend)
}


*ELEMENTARY

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if mathQD1 != . & grade_num <= 5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, All")

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if elaQD1 != . & grade_num <= 5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, All")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & mathQD1 != . & grade_num >5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, All")

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & elaQD1 != . & grade_num >5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, All")

****************************
** BY NATIVE LAGGED SCORE QUARTILE**
****************************


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*ELEMENTARY

reg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if mathQD`quart' == 1 & grade_num <= 5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Quartile `quart'")

reg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if elaQD`quart' == 1 & grade_num<=5,  cluster(sitecode)
outreg2 Kfraction_* using elem_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Quartile `quart'")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & mathQD`quart' == 1 & grade_num>5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, Math, Quartile `quart'")

reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if lagsample == 1 & elaQD`quart' == 1 & grade_num>5,  cluster(sitecode)
outreg2 Kfraction_* using midhigh_trend.xls, excel dec(2) ctitle("Partial Trend, ELA, Quartile `quart'")

}

f


