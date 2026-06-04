*===============================================================================
* FILE:     school_level_means.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Dataset construction (Louisiana school-level aggregation)
* PRODUCES: Intermediate dataset school_level_means.dta — the school x year file
*           of evacuee quartile shares and controls used by the LA school-level
*           SPS placebo/trend programs (school_level_placebo_b.do, school-trend.do)
*           that feed Table 9 and App Tables 25-26.
*
* PURPOSE:  Takes the prepped LA student panel with alternative standardization,
*           sorts incumbents and evacuees into pre-Katrina achievement quartiles,
*           builds school-level (and grade/class-level) shares of Katrina evacuees
*           in each quartile, then collapses to the school x year level keeping
*           only non-evacuees in non-evacuee-area schools. The collapsed file lets
*           the placebo/trend programs ask whether evacuee shares correlate with
*           a school's pre-existing performance level or trend.
*
* INPUTS:   la_prepped_revisionFULL_SAMPLE.dta (prepped LA student panel)
*           alternative_standardization.dta    (z-scores + lags, from alt_standardize.do)
*           discipline_prepped_microdata        (LA discipline records)
*           tanumbers06-09_prepped2.dta         (test-administrator IDs -> class)
* OUTPUTS:  school_level_means.dta              (school x year evacuee shares/controls)
*
* KEY STEPS:
*   - Merge alt-standardized scores; build math/ela pre-Katrina quartiles.
*   - Restrict grades 4-10 / years 2000-2007; drop untested grade-years.
*   - Merge discipline and test-administrator (class) data.
*   - Recode evacuee flags; build percent_katrina time series (=0 pre-2006).
*   - Build school-, grade-, and class-level Katrina shares by quartile.
*   - Restrict to non-evacuees in non-evacuee-area schools; collapse to school x yr.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `keep if year >= 2000 & year <= 2007` analysis window.
*   - `keep if grade_num >= 4 & grade_num <= 10` grade window.
*   - drop grade 4 in 2006/2007 and grade 5 in 2007 (untested grade-years).
*   - lagsample rule keyed on year>2001 (g10), year>2003 (g8), year>2005 (g6/7/9).
*   - Cameron/Calcasieu district codes 10 & 12 forced into katrina_district2.
*   - All `... if year<=2005 -> 0` evacuee-share zeroing: 2005 = last pre-Katrina year.
*   - `gen math0004=math2004 ... replace ... math2003`: 2003-04 baseline for sorting.
*   - `forvalues year = 2000/2005` lag-year recovery loop.
*   - `percent_katrina<.7` clean-sample threshold.
*   - No absolute paths; all .dta refs are relative to the working directory.
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================


* ---- Author working notes (development history) ----
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

*cd "D:\School\Katrina\LA DOE\Revision"   // PATH: repoint to your local globals (commented out)
*log using la_log2_quartiles, text replace

* 6.14 try another run in which I use the true lag rather than capping at 2005 
set more off


* ---- Load prepped LA panel and merge alternatively-standardized scores ----
use la_prepped_revisionFULL_SAMPLE.dta
* sample 3

drop  gender district_name school_name birth_month birth_day birth_year ela_raw math_raw sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using alternative_standardization.dta
drop _merge


* ---- BASELINE ACHIEVEMENT QUARTILES: sort by pre-Katrina (math0005/ela0005) score ----
* fix the quartile analysis...calculate within each year rather than limiting to 2006

capture drop mathQUART elaQUART
capture drop mathQUARTa elaQUARTa

bysort grade_num year: quantiles math0005, gen(mathQUART) nq(4) stable   // baseline achievement quartiles (math), within grade x year
bysort grade_num year: quantiles ela0005, gen(elaQUART) nq(4) stable     // baseline achievement quartiles (ela), within grade x year

capture drop mathQD*
capture drop elaQD*

tab mathQUART, gen(mathQD)
tab elaQUART, gen(elaQD)



* ---- Grade/year sample restrictions ----
*MAKE GRADE/YEAR RESTRICTIONS

keep if year >= 2000 & year <= 2007   // YEAR HARDCODE: analysis window 2000-2007; widen for new years
keep if grade_num >= 4 & grade_num <= 10   // grade window 4-10
drop if year == 2006 & grade_num == 4   // YEAR HARDCODE: grade 4 untested 2006
drop if year == 2007 & grade_num == 4   // YEAR HARDCODE: grade 4 untested 2007
drop if year == 2007 & grade_num == 5   // YEAR HARDCODE: grade 5 untested 2007


* ---- Identify the lag sample (grades w/ a usable pre-Katrina lag by year) ----
*IDENTIFY THE LAG SAMPLE
gen lagsample = 0
replace lagsample = 1 if year > 2001 & grade_num == 10   // YEAR HARDCODE: g10 lag available after 2001
replace lagsample = 1 if year > 2003 & grade_num == 8    // YEAR HARDCODE: g8 lag available after 2003
replace lagsample = 1 if year > 2005 & (grade_num == 6 | grade_num == 7 | grade_num == 9)   // YEAR HARDCODE: g6/7/9 lag available after 2005



summ mathSTD elaSTD

tab year
*********************************************************************
* drop all the old grade year interactions and use gradenum instead
*********************************************************************


drop gryr*


* make the lags all pre-katrina scores
* it is the most recent lag but always pre-katrina
* save originals as math_lag2 and ela_lag2

gen math_lag2=math_lag
gen ela_lag2=ela_lag
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-2005, force lag to most recent pre-Katrina score
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE: post-2005, force lag to most recent pre-Katrina score


* ---- BASELINE ACHIEVEMENT QUARTILES: 2003-04 score for sorting students ----
* get baseline score for sorting students
gen math0004=math2004                                 // YEAR HARDCODE: prefer 2004 baseline score
replace math0004=math2003 if math0004==. & math2003!=.   // YEAR HARDCODE: fall back to 2003
* replace math0004=math2002 if math0004==. & math2002!=.
* replace math0004=math2001 if math0004==. & math2001!=.
* replace math0004=math2000 if math0004==. & math2000!=.
bysort grade_num year: quantiles math0004 , gen(math_0004QUART) nq(4) stable   // baseline achievement quartiles off 2003-04 score

gen ela0004=ela2004                                 // YEAR HARDCODE: prefer 2004 baseline score
replace ela0004=ela2003 if ela0004==. & ela2003!=.   // YEAR HARDCODE: fall back to 2003
* replace ela0004=ela2002 if ela0004==. & ela2002!=.
* replace ela0004=ela2001 if ela0004==. & ela2001!=.
* replace ela0004=ela2000 if ela0004==. & ela2000!=.
bysort grade_num year: quantiles ela0004 , gen(ela_0004QUART) nq(4) stable   // baseline achievement quartiles off 2003-04 score





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


* ---- Merge in test-administrator IDs (used to define classroom) ----
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



* ---- Define classroom from site x year x test-administrator number ----
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
replace cameron_calcasieu=1 if district_code==10 | district_code==12   // district codes 10 & 12 = Cameron/Calcasieu (Rita-affected)



* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1


* ---- Define percent Rita (school x year evacuee share, 0 pre-treatment) ----
* define percent Rita

egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 for all pre-Katrina years (<=2005)


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

* ---- Redefine percent Katrina at school x year and school x year x grade ----
egen percent_katrinaTIMESERIES2=mean(katrina_sum), by(district_code school_code year)
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)


egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)




* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

* ---- Katrina peer share weighted by pre-Katrina (2005) discipline status ----
gen discipline05a=discipline_any if year==2005   // YEAR HARDCODE: 2005 = last pre-Katrina year for evacuees' discipline record

egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005   // YEAR HARDCODE: share = 0 pre-Katrina (<=2005)


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








* ---- School x year Katrina shares by baseline achievement quartile ----
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





* Zero out evacuee quartile shares for all pre-Katrina years.
replace Kfraction_mathQ1=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)
replace Kfraction_mathQ2=0 if year<=2005
replace Kfraction_mathQ3=0 if year<=2005
replace Kfraction_mathQ4=0 if year<=2005

replace Kfraction_elaQ1=0 if year<=2005
replace Kfraction_elaQ2=0 if year<=2005
replace Kfraction_elaQ3=0 if year<=2005
replace Kfraction_elaQ4=0 if year<=2005






* ---- School x year x grade Katrina shares by baseline quartile (suffix G) ----
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





replace Kfraction_mathQ1G=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)
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


replace Kfraction_mathQ1C=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)
replace Kfraction_mathQ2C=0 if year<=2005
replace Kfraction_mathQ3C=0 if year<=2005
replace Kfraction_mathQ4C=0 if year<=2005

replace Kfraction_elaQ1C=0 if year<=2005
replace Kfraction_elaQ2C=0 if year<=2005
replace Kfraction_elaQ3C=0 if year<=2005
replace Kfraction_elaQ4C=0 if year<=2005





* ---- Interact lag score with year-gap between now and the lagged test ----
**************
** try interacting lag with number of years between now and lag
**************
gen math_lagyear2=math_lagyear
gen ela_lagyear2=ela_lagyear

replace math_lagyear = . if year > 2005   // YEAR HARDCODE: recompute lag-year only for post-Katrina obs (>2005)
replace ela_lagyear = . if year > 2005
forvalues year = 2000/2005 {   // YEAR HARDCODE: recover which pre-Katrina year (2000-2005) supplied the lag
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

* ---- Build grade x year fixed-effect interaction dummies (gryr*) ----
xi i.grade_num*i.year, prefix(gryr)


* ---- Restrict to native (non-evacuee) students in non-evacuee-area schools ----
*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7   // percent_katrina<.7 clean-sample threshold hardcoded


* ---- Collapse to school x year; save school_level_means.dta ----
*COLLAPSE TO SCHOOL LEVEL
collapse (mean) Kfraction_* percent_katrinaTIMESERIES* free_lunchA male black hisp asian gryr* , by(sitecode year)
sort sitecode year
save school_level_means.dta, replace
