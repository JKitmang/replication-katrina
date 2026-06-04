*===============================================================================
* FILE:     quartile_analysis_revision_alt_standard2.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Robustness/variant (alternative-standardization version of the LA
*           nonlinear quartile peer-effects analysis)
* PRODUCES: Appendix Table 38 (per the dofile -> table map).
*
* PURPOSE:  Identical in structure to the workhorse quartile_analysis_revision_d.do,
*           but standardizes test scores using ONLY NON-EVACUEES (the
*           alternative_standardization_2.dta input). This guards against the
*           evacuees themselves shifting the grade x year score distribution used
*           to standardize and to form quartiles. All else (quartile-interacted
*           evacuee shares, math/ELA, no-lag/lag samples, own-quartile splits,
*           and the full robustness battery) mirrors revision_d. Outputs are
*           written to *_alt.xls files to keep them separate.
*
* INPUTS:   /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta
*           /work/i/imberman/imberman/la_data/alternative_standardization_2.dta
*               (non-evacuee-only standardization — the key difference from _d)
*           /work/i/imberman/imberman/la_data/discipline_prepped_microdata.dta
*           /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta
* OUTPUTS:  outreg2 results in /work/i/imberman/imberman/la_data/:
*           elem_school_alt.xls, midhigh_school_alt.xls,
*           elem_grade_alt.xls, midhigh_grade_alt.xls (no .dta saved).
*
* KEY STEPS:
*   - Load full LA panel; merge in NON-EVACUEE-ONLY standardized scores.
*   - Build baseline achievement quartiles (own ability + evacuee peers).
*   - Construct evacuee SHARE by quartile at school, grade, and class levels.
*   - Build pre-Katrina lagged-score controls interacted with years-since-lag.
*   - Restrict to non-evacuee incumbents outside the evacuation area.
*   - Run the quartile-interacted areg battery and outreg2 to *_alt files.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Standardization base year: 2003-04 scale-score means/SDs, NON-EVACUEES ONLY.
*   - keep if year >= 2000 & year <= 2007   (analysis window)
*   - drop if year == 2006/2007 & grade_num == 4/5  (grade-year coverage)
*   - lagsample defined by year > 2001/2003/2005 thresholds per grade.
*   - replace math_lag/ela_lag = ...0005 if year>2005 (pre-Katrina lag cap).
*   - All `replace ...=0 if year<=2005` lines: PRE-TREATMENT = no evacuees.
*   - forvalues year=2000/2005 (lag-year backfill loop).
*   - discipline05 off year==2005; med_percent_katrina off year==2006.
*   - year!=2005 / year>=2006 subsample restrictions in robustness blocks.
*   - ABSOLUTE PATHS: every /work/i/imberman/imberman/la_data/... path must be
*     repointed to your local globals.
*
* NOTE: Documentation comments only — no executable code was modified.
*       This file is a near-line-for-line clone of quartile_analysis_revision_d.do;
*       see that file for fuller block-by-block annotation. The differences are
*       (1) input alternative_standardization_2.dta and (2) *_alt output names.
*===============================================================================
********THIS PROGRAM USES AN ALTERNATIVE STANDARDIZATION PROCEDURE THAT STANDARDIZES BASED ON MEAN SCALE SCORES IN 2003-04 FOR ALL YEARS****
********SINCE TESTING ONLY DONE IN GRADES 4, 8 & 10 IN THIS YEAR, USE GRADE 4 MEAN AND SD FOR GRADES 3 - 5, GRADE 8 FOR 6 - 8, AND GRADE 10 FOR 9
******** & 10

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
set mem 1900m
capture log close

set seed 10563

*cd "D:\School\Katrina\LA DOE\Revision"
*log using la_log2_quartiles, text replace

* 6.14 try another run in which I use the true lag rather than capping at 2005 
set more off


* ---- LOAD DATA & MERGE IN NON-EVACUEE-ONLY STANDARDIZATION ----
* PATH: repoint to your local globals
use /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta
* sample 3

drop  gender district_name school_name birth_month birth_day birth_year ela_raw math_raw sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
* SCORE STANDARDIZATION (KEY DIFFERENCE vs _d): brings in mathSTD/elaSTD
* standardized on 2003-04 scale-score means/SDs computed from NON-EVACUEES ONLY.
* PATH: repoint to your local globals.
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using /work/i/imberman/imberman/la_data/alternative_standardization_2.dta
drop _merge

* ---- BASELINE ACHIEVEMENT QUARTILES (peers) ----
* fix the quartile analysis...calculate within each year rather than limiting to 2006
capture drop mathQUART elaQUART
capture drop mathQUARTa elaQUARTa

* BASELINE ACHIEVEMENT QUARTILES: within grade x year quartiles of pre-Katrina score
bysort grade_num year: quantiles math0005, gen(mathQUART) nq(4) stable
bysort grade_num year: quantiles ela0005, gen(elaQUART) nq(4) stable

capture drop mathQD*
capture drop elaQD*

tab mathQUART, gen(mathQD)
tab elaQUART, gen(elaQD)



* ---- GRADE/YEAR SAMPLE RESTRICTIONS ----
keep if year >= 2000 & year <= 2007   // YEAR HARDCODE: analysis window 2000-2007
keep if grade_num >= 4 & grade_num <= 10
drop if year == 2006 & grade_num == 4   // YEAR HARDCODE: uncovered grade-year
drop if year == 2007 & grade_num == 4   // YEAR HARDCODE: uncovered grade-year
drop if year == 2007 & grade_num == 5   // YEAR HARDCODE: uncovered grade-year


* ---- IDENTIFY THE LAG SAMPLE ----
gen lagsample = 0
replace lagsample = 1 if year > 2001 & grade_num == 10   // YEAR HARDCODE: grade 10 lag from 2002 on
replace lagsample = 1 if year > 2003 & grade_num == 8    // YEAR HARDCODE: grade 8 lag from 2004 on
replace lagsample = 1 if year > 2005 & (grade_num == 6 | grade_num == 7 | grade_num == 9)   // YEAR HARDCODE: grades 6/7/9 lag from 2006 on



summ mathSTD elaSTD

tab year
*********************************************************************
* drop all the old grade year interactions and use gradenum instead
*********************************************************************


drop gryr*


xi i.grade_num*i.year, prefix(gryr)


* make the lags all pre-katrina scores
* it is the most recent lag but always pre-katrina
* save originals as math_lag2 and ela_lag2

* ---- PRE-KATRINA LAGGED-SCORE CONTROLS ----
gen math_lag2=math_lag
gen ela_lag2=ela_lag
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-Katrina lag forced to pre-Katrina (0005) score
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE: post-Katrina lag forced to pre-Katrina (0005) score


* ---- BASELINE ACHIEVEMENT QUARTILES (own score for sorting students) ----
* get baseline score for sorting students (2004, falling back to 2003)
gen math0004=math2004
replace math0004=math2003 if math0004==. & math2003!=.
* replace math0004=math2002 if math0004==. & math2002!=.
* replace math0004=math2001 if math0004==. & math2001!=.
* replace math0004=math2000 if math0004==. & math2000!=.
* BASELINE ACHIEVEMENT QUARTILES: own pre-Katrina math/ELA quartiles
bysort grade_num year: quantiles math0004 , gen(math_0004QUART) nq(4) stable

gen ela0004=ela2004
replace ela0004=ela2003 if ela0004==. & ela2003!=.
* replace ela0004=ela2002 if ela0004==. & ela2002!=.
* replace ela0004=ela2001 if ela0004==. & ela2001!=.
* replace ela0004=ela2000 if ela0004==. & ela2000!=.
bysort grade_num year: quantiles ela0004 , gen(ela_0004QUART) nq(4) stable





* make 2005 and all its interactions with each grade the ommitted category
*drop gryr*_2005


***********************************
* ---- MERGE IN THE DISCIPLINE DATA (PATH: repoint to local globals) ----
***********************************
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/discipline_prepped_microdata

tab _m

drop if _m==2


***********************************
* ---- MERGE IN TEST ADMINISTRATOR DATA (classroom ids; PATH: repoint) ----
***********************************
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta

tab _m

drop if _m==2


summ mathSTD elaSTD

tab year



* ---- DEFINE CLASSROOM (school x year x test-administrator number) ----
* identify my class using TA numbers
egen class=group(sitecode year elamthtanumber)

***********************************
* recode the discipline data: missing means no discpline record for that student
***********************************
rename discpline_any discipline_any
recode discipline_any .=0

recode  disciplinedaycnt .=0

recode free_lunchA .=0 3=.

* define a dummy for cameron and calcasiu parishes

gen cameron_calcasieu=0
replace cameron_calcasieu=1 if district_code==10 | district_code==12



* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1


* ---- EVACUEE (RITA) SHARE AT SCHOOL x YEAR ----
* define percent Rita
egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: no evacuees pre-2005-06


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

* ---- REDEFINE PERCENT KATRINA (evacuee share, school x year and x grade) ----
egen percent_katrinaTIMESERIES2=mean(katrina_sum), by(district_code school_code year)
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06


egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-2005-06




* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

* ---- "BAD APPLE" SHARE: evacuee peers disciplined pre-Katrina ----
gen discipline05a=discipline_any if year==2005   // YEAR HARDCODE: 2005 baseline discipline status
egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005   // YEAR HARDCODE: no evacuees pre-2005-06


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








* ---- EVACUEE SHARE BY BASELINE QUARTILE — SCHOOL x YEAR (key RHS regressors) ----
* get fraction of all peers who are in each quartile
egen fraction_mathQ1=mean(mathQD1), by(district_code school_code year)
egen fraction_mathQ2=mean(mathQD2), by(district_code school_code year)
egen fraction_mathQ3=mean(mathQD3), by(district_code school_code year)
egen fraction_mathQ4=mean(mathQD4), by(district_code school_code year)


egen fraction_elaQ1=mean(elaQD1), by(district_code school_code year)
egen fraction_elaQ2=mean(elaQD2), by(district_code school_code year)
egen fraction_elaQ3=mean(elaQD3), by(district_code school_code year)
egen fraction_elaQ4=mean(elaQD4), by(district_code school_code year)





* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1=mean(mathQD1*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ2=mean(mathQD2*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ3=mean(mathQD3*katrina_sum), by(district_code school_code year)
egen Kfraction_mathQ4=mean(mathQD4*katrina_sum), by(district_code school_code year)


egen Kfraction_elaQ1=mean(elaQD1*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ2=mean(elaQD2*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ3=mean(elaQD3*katrina_sum), by(district_code school_code year)
egen Kfraction_elaQ4=mean(elaQD4*katrina_sum), by(district_code school_code year)





* YEAR HARDCODE: school-level evacuee share by quartile = 0 pre-2005-06
replace Kfraction_mathQ1=0 if year<=2005
replace Kfraction_mathQ2=0 if year<=2005
replace Kfraction_mathQ3=0 if year<=2005
replace Kfraction_mathQ4=0 if year<=2005

replace Kfraction_elaQ1=0 if year<=2005
replace Kfraction_elaQ2=0 if year<=2005
replace Kfraction_elaQ3=0 if year<=2005
replace Kfraction_elaQ4=0 if year<=2005






* ---- EVACUEE SHARE BY BASELINE QUARTILE — SCHOOL x YEAR x GRADE LEVEL ----
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





* YEAR HARDCODE: grade-level evacuee share by quartile = 0 pre-2005-06
replace Kfraction_mathQ1G=0 if year<=2005
replace Kfraction_mathQ2G=0 if year<=2005
replace Kfraction_mathQ3G=0 if year<=2005
replace Kfraction_mathQ4G=0 if year<=2005

replace Kfraction_elaQ1G=0 if year<=2005
replace Kfraction_elaQ2G=0 if year<=2005
replace Kfraction_elaQ3G=0 if year<=2005
replace Kfraction_elaQ4G=0 if year<=2005


*****************************************************
** Calculate percent Katrina at the Classroom Level
*****************************************************
*****************************************************

* get fraction of katrina peers who are in each quartile

egen Kfraction_mathQ1C=mean(mathQD1*katrina_sum), by(class)
egen Kfraction_mathQ2C=mean(mathQD2*katrina_sum), by(class)
egen Kfraction_mathQ3C=mean(mathQD3*katrina_sum), by(class)
egen Kfraction_mathQ4C=mean(mathQD4*katrina_sum), by(class)


egen Kfraction_elaQ1C=mean(elaQD1*katrina_sum), by(class)
egen Kfraction_elaQ2C=mean(elaQD2*katrina_sum), by(class)
egen Kfraction_elaQ3C=mean(elaQD3*katrina_sum), by(class)
egen Kfraction_elaQ4C=mean(elaQD4*katrina_sum), by(class)


* YEAR HARDCODE: class-level evacuee share by quartile = 0 pre-2005-06
replace Kfraction_mathQ1C=0 if year<=2005
replace Kfraction_mathQ2C=0 if year<=2005
replace Kfraction_mathQ3C=0 if year<=2005
replace Kfraction_mathQ4C=0 if year<=2005

replace Kfraction_elaQ1C=0 if year<=2005
replace Kfraction_elaQ2C=0 if year<=2005
replace Kfraction_elaQ3C=0 if year<=2005
replace Kfraction_elaQ4C=0 if year<=2005





**************
* ---- LAG x YEARS-SINCE-LAG INTERACTIONS (year_gap dummies) ----
** try interacting lag with number of years between now and lag
**************
gen math_lagyear2=math_lagyear
gen ela_lagyear2=ela_lagyear

replace math_lagyear = . if year > 2005   // YEAR HARDCODE: recompute lag-year only post-Katrina
replace ela_lagyear = . if year > 2005     // YEAR HARDCODE: recompute lag-year only post-Katrina
* YEAR HARDCODE: backfill lag year over pre-Katrina years 2000-2005
forvalues year = 2000/2005 {
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



* ---- ESTIMATION SAMPLE: incumbent natives outside the evacuation area ----
*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7

*===============================================================================
* ESTIMATION BATTERY BEGINS (App Table 38; structure mirrors revision_d)
* Each block re-runs the quartile-interacted areg for math & ELA, no-lag vs lag
* samples, all-students vs own-quartile splits; lincom lines test monotonicity
* (Q2-Q1, ...) and the boutique model (own quartile vs others). Outputs -> *_alt.
*===============================================================================

**************
** Overall Table ***   --> SCHOOL-LEVEL evacuee share
**************

*******************************
*******************************
*** Show that the pattern holds even before we split into quantiles of own ability
*******************************
*******************************

* ---- Clear prior *_alt outreg2 output files (PATH: repoint to local globals) ----
cap rm /work/i/imberman/imberman/la_data/elem_school_alt.txt
cap rm /work/i/imberman/imberman/la_data/elem_school_alt.xls
cap rm /work/i/imberman/imberman/la_data/midhigh_school_alt.txt
cap rm /work/i/imberman/imberman/la_data/midhigh_school_alt.xls


cap rm /work/i/imberman/imberman/la_data/elem_grade_alt.txt
cap rm /work/i/imberman/imberman/la_data/elem_grade_alt.xls
cap rm /work/i/imberman/imberman/la_data/midhigh_grade_alt.txt
cap rm /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls



*Elementary (NO LAG)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if mathQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_school_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All")
 
* check for monotonicty...what's the t test on coefficient bigger with each quartile
lincom Kfraction_mathQ2-Kfraction_mathQ1
lincom Kfraction_mathQ3-Kfraction_mathQ2
lincom Kfraction_mathQ4-Kfraction_mathQ3
lincom Kfraction_mathQ3-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ2


areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_school_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All")
lincom Kfraction_elaQ2-Kfraction_elaQ1
lincom Kfraction_elaQ3-Kfraction_elaQ2
lincom Kfraction_elaQ4-Kfraction_elaQ3
lincom Kfraction_elaQ3-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ2


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_school_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All")

lincom Kfraction_mathQ2-Kfraction_mathQ1
lincom Kfraction_mathQ3-Kfraction_mathQ2
lincom Kfraction_mathQ4-Kfraction_mathQ3
lincom Kfraction_mathQ3-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ2

areg elaSTD ela_lag_* Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_school_alt.xls, excel dec(2) ctitle("ELA, Non-Linaer, All")
lincom Kfraction_elaQ2-Kfraction_elaQ1
lincom Kfraction_elaQ3-Kfraction_elaQ2
lincom Kfraction_elaQ4-Kfraction_elaQ3
lincom Kfraction_elaQ3-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ2

****************************
** BY NATIVE LAGGED SCORE QUARTILE**
****************************


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/elem_school_alt.xls, excel dec(2) ctitle("Math, Linear, Quartile `quart'")

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_school_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart'")

* test monotonicity
lincom Kfraction_mathQ2-Kfraction_mathQ1
lincom Kfraction_mathQ3-Kfraction_mathQ2
lincom Kfraction_mathQ4-Kfraction_mathQ3
lincom Kfraction_mathQ3-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ2

* test boutique model...my own quartile always the most positive
lincom Kfraction_mathQ`quart'-Kfraction_mathQ1
lincom Kfraction_mathQ`quart'-Kfraction_mathQ2
lincom Kfraction_mathQ`quart'-Kfraction_mathQ3
lincom Kfraction_mathQ`quart'-Kfraction_mathQ4

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/elem_school_alt.xls, excel dec(2) ctitle("ELA, Linear, Quartile `quart'")

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_school_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart'")
* test monotonicity
lincom Kfraction_elaQ2-Kfraction_elaQ1
lincom Kfraction_elaQ3-Kfraction_elaQ2
lincom Kfraction_elaQ4-Kfraction_elaQ3
lincom Kfraction_elaQ3-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ2

* test boutique model...my own quartile always the most positive
lincom Kfraction_elaQ`quart'-Kfraction_elaQ1
lincom Kfraction_elaQ`quart'-Kfraction_elaQ2
lincom Kfraction_elaQ`quart'-Kfraction_elaQ3
lincom Kfraction_elaQ`quart'-Kfraction_elaQ4




*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_school_alt.xls, excel dec(2) ctitle("Math, Linear, Quartile `quart'")

areg mathSTD math_lag_* Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_school_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart'")

* test monotonicity
lincom Kfraction_mathQ2-Kfraction_mathQ1
lincom Kfraction_mathQ3-Kfraction_mathQ2
lincom Kfraction_mathQ4-Kfraction_mathQ3
lincom Kfraction_mathQ3-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ1
lincom Kfraction_mathQ4-Kfraction_mathQ2

* test boutique model...my own quartile always the most positive
lincom Kfraction_mathQ`quart'-Kfraction_mathQ1
lincom Kfraction_mathQ`quart'-Kfraction_mathQ2
lincom Kfraction_mathQ`quart'-Kfraction_mathQ3
lincom Kfraction_mathQ`quart'-Kfraction_mathQ4

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_school_alt.xls, excel dec(2) ctitle("ELA, Linear, Quartile `quart'")

areg elaSTD ela_lag_* Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_school_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart'")

* test monotonicity
lincom Kfraction_elaQ2-Kfraction_elaQ1
lincom Kfraction_elaQ3-Kfraction_elaQ2
lincom Kfraction_elaQ4-Kfraction_elaQ3
lincom Kfraction_elaQ3-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ1
lincom Kfraction_elaQ4-Kfraction_elaQ2

* test boutique model...my own quartile always the most positive
lincom Kfraction_elaQ`quart'-Kfraction_elaQ1
lincom Kfraction_elaQ`quart'-Kfraction_elaQ2
lincom Kfraction_elaQ`quart'-Kfraction_elaQ3
lincom Kfraction_elaQ`quart'-Kfraction_elaQ4

}


*********GRADE LEVEL************

*******************************
*******************************
*** Show that the pattern holds even before we split into quantiles of own ability
*******************************
*******************************

*Elementary (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All")

* check for monotonicty...what's the t test on coefficient bigger with each quartile


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All")


****************************
** BY NATIVE LAGGED SCORE QUARTILE**
****************************


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Linear, Quartile `quart'")

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart'")

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Linear, Quartile `quart'")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart'")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Linear, Quartile `quart'")

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart'")

areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Linear, Quartile `quart'")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart'")

}




*===============================================================================
*** Allow separate trends above and below median Free Reduced lunch***
* ROBUSTNESS: high- vs low-FRP school-specific time trend.
*===============================================================================
* calculate median percent free lunch
egen percent_free_lunchA=mean(free_lunchA) if year==2005, by(sitecode)   // YEAR HARDCODE: 2005 baseline FRP
egen percent_free_lunch=max(percent_free_lunchA), by(sitecode)

egen med_percent_lunchA=median(percent_free_lunchA) if year==2005
egen med_percent_lunch=max(med_percent_lunchA)


gen percent_lunchHIGH=percent_free_lunch>med_percent_lunch

gen trend=year
gen trend_percent_lunch=trend*percent_lunchHIGH




*******************************
*******************************
*** NOT SPLIT BY QUARTILES
*******************************
*******************************

*Elementary (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if mathQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
* check for monotonicty...what's the t test on coefficient bigger with each quartile
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, FRP Trend")


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if elaQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, FRP Trend")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, FRP Trend")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, FRP Trend")


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', FRP Trend")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', FRP Trend")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', FRP Trend")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_lunchHIGH trend_percent_lunch if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', FRP Trend")
}




*===============================================================================
*** Allow separate trends above and below median percent katrina***
* ROBUSTNESS: high- vs low-evacuee-share school-specific time trend.
*===============================================================================
* calculate mediean percent katrina
egen med_percent_katrinaA=median(percent_katrina)if year==2006   // YEAR HARDCODE: 2006 = first post-Katrina year

egen med_percent_katrina=max(med_percent_katrinaA) 



gen percent_katrinaHIGH=percent_katrina>med_percent_katrina

gen trend_percent_katrinaHIGH=trend*percent_katrinaHIGH

* since we already have year dummies, I will omit trend and just include trend interacted with percent_katrinaHIGH



*******************************
*******************************
*** NOT SPLIT BY QUARTILES
*******************************
*******************************

*Elementary (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if mathQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Median Kat Trend")

* check for monotonicty...what's the t test on coefficient bigger with each quartile


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if elaQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Median Kat Trend")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Median Kat Trend")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Median Kat Trend")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Median Kat Trend")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Median Kat Trend")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Median Kat Trend")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* percent_katrinaHIGH trend_percent_katrinaHIGH if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Median Kat Trend")
}




*===============================================================================
*** Use evacuee share with discplinary infractions ***
* BAD-APPLE MODEL: add share of evacuee peers disciplined pre-Katrina.
*===============================================================================


*******************************
*******************************
*** NOT SPLIT BY QUARTILES
*******************************
*******************************

*Elementary (NO LAG)

areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr*  if mathQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Discip")
* check for monotonicty...what's the t test on coefficient bigger with each quartile


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr*  if elaQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Discip")

*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD percent_katrinaDISCIPLINE2 math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr*  if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Discip")

areg elaSTD percent_katrinaDISCIPLINE2 ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr*  if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Discip")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Discip")

areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Discip")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* percent_katrinaDISCIPLINE2 Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Discip")

areg elaSTD ela_lag_* percent_katrinaDISCIPLINE2 Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Discip")
}



/*
*===============================================================================
*** Use evacuee share at the class level ***
* CLASS-LEVEL specification (Kfraction_*C); results displayed, no outreg2.
*===============================================================================



*******************************
*******************************
*** NOT SPLIT BY QUARTILES
*******************************
*******************************

*Elementary (NO LAG)

areg mathSTD  Kfraction_mathQ1C Kfraction_mathQ2C Kfraction_mathQ3C Kfraction_mathQ4C free_lunchA male black hisp asian gryr*  if mathQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)
* check for monotonicty...what's the t test on coefficient bigger with each quartile


areg elaSTD  Kfraction_elaQ1C Kfraction_elaQ2C Kfraction_elaQ3C Kfraction_elaQ4C free_lunchA male black hisp asian gryr*  if elaQD1 != . & grade_num<=5, absorb(sitecode) cluster(sitecode)


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD  math_lag_* Kfraction_mathQ1C Kfraction_mathQ2C Kfraction_mathQ3C Kfraction_mathQ4C free_lunchA male black hisp asian gryr*  if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD  ela_lag_* Kfraction_elaQ1C Kfraction_elaQ2C Kfraction_elaQ3C Kfraction_elaQ4C free_lunchA male black hisp asian gryr*  if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)



forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1C Kfraction_mathQ2C Kfraction_mathQ3C Kfraction_mathQ4C free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1C Kfraction_elaQ2C Kfraction_elaQ3C Kfraction_elaQ4C free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5, absorb(sitecode) cluster(sitecode)



*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1C Kfraction_mathQ2C Kfraction_mathQ3C Kfraction_mathQ4C free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* Kfraction_elaQ1C Kfraction_elaQ2C Kfraction_elaQ3C Kfraction_elaQ4C free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
}




*===============================================================================
*** Use grade level evacuee share and exclude years< 2006 & absorb sitecode & year
* ROBUSTNESS: school x year FE, post-Katrina only (uses year >= 2006 below).
*===============================================================================

gen double sitecode_year = sitecode*100000 + year   // YEAR HARDCODE: encodes year into school-year FE id


*Elementary (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 != . & grade_num<=5 & year >= 2006, absorb(sitecode_year) cluster(sitecode_year)

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5 & year >= 2006, absorb(sitecode) cluster(sitecode_year)


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != . & year >= 2006, absorb(sitecode) cluster(sitecode_year)

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != . & year >= 2006, absorb(sitecode) cluster(sitecode_year)



forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""


*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5 & year>=2006, absorb(sitecode_year) cluster(sitecode)

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5  & year>=2006, absorb(sitecode_year) cluster(sitecode)



*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1  & year>=2006, absorb(sitecode_year) cluster(sitecode)

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1  & year>=2006, absorb(sitecode_year) cluster(sitecode)
}
*/






*===============================================================================
*** normal quartile regs but exclude schools with percent_katrina>.10 ***
* ROBUSTNESS: drop high-evacuee-share schools (outlier/leverage check).
*===============================================================================


**********ALL****************

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 !=. & grade_num<=5 & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Outliers")


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5 & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Outliers")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != . & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Outliers")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != . & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* percent_katrina* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Outliers")


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5 & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Outliers")


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5 & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Outliers")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1 & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Outliers")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1 & percent_katrina<.10, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Outliers")

}



*===============================================================================
*** normal quartile regs but exclude 2005  ***
* ROBUSTNESS: drop the 2005 transition year (year!=2005 below).
*===============================================================================


*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 != . & grade_num<=5 & year!=2005 , absorb(sitecode) cluster(sitecode)   // YEAR HARDCODE: exclude 2005
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, No 2005")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5 & year!=2005, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, No 2005")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != . & year!=2005, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, No 2005")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != . & year!=2005, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, No 2005")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5 & year!=2005 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', No 2005")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5 & year!=2005, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', No 2005")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1 & year!=2005, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', No 2005")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1 & year!=2005, absorb(sitecode) cluster(sitecode)
}
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', No 2005")


*===============================================================================
**************FULL SAMPLE AND MID/HIGH W/O LAGS******************
* ROBUSTNESS: full sample (no grade<=5 restriction) and mid/high without lags.
*===============================================================================


*FULL SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 != . , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Full Sample")


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Full Sample")


*LAG SAMPLE (NO LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, No Lags")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, No Lags")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""


*FULL SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Full Sample")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Full Sample")


*LAG SAMPLE (NO LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', No Lags")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', No Lags")
}



*===============================================================================
*********************USE LINEAR LAGS INSTEAD OF INTERACTION WITH YEARS SINCE LAG**************
* ROBUSTNESS: single linear lag instead of lag x years-since-lag interactions.
*===============================================================================



*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 != . & grade_num<=5  , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Linear Lag")


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Linear Lag")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != . , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Linear Lag")

areg elaSTD ela_lag Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != . , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Linear Lag")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5  , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Linear Lag")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Linear Lag")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Linear Lag")

areg elaSTD ela_lag Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Linear Lag")
}




*===============================================================================
*********************DROP ANY SCHOOLS WITH NO EVACUEES IN 2005-06**************
* ROBUSTNESS: keep only schools that received evacuees in 2005-06 (common support).
*===============================================================================
gen percent_katrina_0506a = percent_katrinaTIMESERIES2 if year == 2006   // YEAR HARDCODE: 2006 evacuee share
egen percent_katrina_0506 = max(percent_katrina_0506a), by(sitecode)


*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD1 != . & grade_num<=5  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Positive Katrina in 0506")


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD1 != . & grade_num<=5  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Positive Katrina in 0506")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != .  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, All, Positive Katrina in 0506")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != .  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, All, Positive Katrina in 0506")

forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*Elementary SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if mathQD`quart' == 1 & grade_num<=5   & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Positive Katrina in 0506")

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if elaQD`quart' == 1 & grade_num<=5  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/elem_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Positive Katrina in 0506")


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("Math, Non-Linear, Quartile `quart', Positive Katrina in 0506")

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1  & percent_katrina_0506 > 0 , absorb(sitecode) cluster(sitecode)
outreg2 Kfraction_* using /work/i/imberman/imberman/la_data/midhigh_grade_alt.xls, excel dec(2) ctitle("ELA, Non-Linear, Quartile `quart', Positive Katrina in 0506")
}






* create histogram of the number of evacuees by classroom level

egen count_class=count(id), by(class)

hist count_katrina_class if year==2006 & count_class>5 & count_katrina_class!=0

hist count_katrina_class if year==2006 & count_class>5 & count_katrina_class!=0, fraction
 



endsas;







