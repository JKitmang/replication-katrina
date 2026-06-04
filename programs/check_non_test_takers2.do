*===============================================================================
* FILE:     check_non_test_takers2.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Louisiana test-taking / attrition check)
* PRODUCES: App Table 11 (LA test-taking, with katrina_by_quartiles_testtaking).
*
* PURPOSE:  Tests whether the evacuee share affects whether NATIVE students show
*           up to take the LEAP test (a selective-attrition check on the achievement
*           results). It rebuilds the LA student panel exactly as the main LA
*           quartile programs do (alt-standardized scores, pre-Katrina achievement
*           quartiles, school/grade/class evacuee shares), then collapses to the
*           school x grade x year level and regresses the fraction of test-takers
*           (and enrollment changes) on the evacuee share/quartile shares.
*
* INPUTS:   la_prepped_revisionFULL_SAMPLE.dta      (prepped LA student panel)
*           alternative_standardization_small.dta   (alt-standardized scores + lags)
*           discipline_prepped_microdata             (LA discipline records)
*           tanumbers06-09_prepped2.dta              (test-administrator IDs -> class)
*           num_kids_bygrade                         (enrollment counts per school x grade x year)
* OUTPUTS:  None saved; regression output to the log.
*
* KEY STEPS:
*   - Build math/ela pre-Katrina achievement quartiles; restrict grades 4-10 / 2000-2007.
*   - Merge discipline + test-administrator data; define classroom.
*   - Recode evacuee flags; build school/grade/class evacuee shares by quartile.
*   - Restrict to non-evacuees in non-evacuee-area schools.
*   - Collapse to school x grade x year; merge enrollment counts.
*   - Regress fraction of test-takers / enrollment change on evacuee shares.
*   - (Everything after the first `endsas;` is unreachable scratch — see flag below.)
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - `cd "D:\School\Katrina\LA DOE\Revision"` absolute path (see PATH flag below).
*   - `keep if year >= 2000 & year <= 2007`; grade window 4-10; drop untested grade-years.
*   - lagsample rule: year>2001 (g10), year>2003 (g8), year>2005 (g6/7/9).
*   - Cameron/Calcasieu district codes 10 & 12 -> katrina_district2.
*   - All `... if year<=2005 -> 0` evacuee-share zeroing (2005 = last pre-Katrina year).
*   - `gen math0004=math2004 ... math2003` 2003-04 baseline for quartile sorting.
*   - `forvalues year=2000/2005` lag-year recovery; `percent_katrina<.7` / `<.3` thresholds.
*   - usable2/usable3 grade-year availability tables (years 2004-2009 hardcoded).
*   - No Sept-13 instrument here (this is the LA, not Houston, branch).
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
* ---- Setup ----
clear
set mem 1900m
capture log close

set seed 10563

cd "D:\School\Katrina\LA DOE\Revision"   // PATH: repoint to your local globals
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
merge id year using alternative_standardization_small.dta
drop _merge

* fix the quartile analysis...calculate within each year rather than limiting to 2006

capture drop mathQUART elaQUART
capture drop mathQUARTa elaQUARTa

* ---- BASELINE ACHIEVEMENT QUARTILES: sort by pre-Katrina (math0005/ela0005) score ----
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


xi i.grade_num*i.year, prefix(gryr)


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


***********************************
* merge in the discipline data
* ---- Merge in discipline microdata ----
***********************************
capture drop _m
sort id year

merge id year, using discipline_prepped_microdata

tab _m

drop if _m==2


***********************************
* merge in the test administrator data
* ---- Merge in test-administrator IDs (used to define classroom) ----
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

* define a dummy for cameron and calcasiu parishes

gen cameron_calcasieu=0
replace cameron_calcasieu=1 if district_code==10 | district_code==12   // district codes 10 & 12 = Cameron/Calcasieu (Rita-affected)



* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1


* ---- Define percent Rita / percent Katrina shares (0 pre-treatment) ----
* define percent Rita

egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)


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

egen percent_katrinaTIMESERIES2=mean(katrina_sum), by(district_code school_code year)
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)


egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE: evacuee share = 0 pre-Katrina (<=2005)




* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

gen discipline05a=discipline_any if year==2005

egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005


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





replace Kfraction_mathQ1=0 if year<=2005
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


replace Kfraction_mathQ1C=0 if year<=2005
replace Kfraction_mathQ2C=0 if year<=2005
replace Kfraction_mathQ3C=0 if year<=2005
replace Kfraction_mathQ4C=0 if year<=2005

replace Kfraction_elaQ1C=0 if year<=2005
replace Kfraction_elaQ2C=0 if year<=2005
replace Kfraction_elaQ3C=0 if year<=2005
replace Kfraction_elaQ4C=0 if year<=2005





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



*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7





* ---- ACTIVE ANALYSIS (App Table 11): test-taking & enrollment vs. evacuee share ----
* collapse the data to the number of kids in each school grade and year that took the math or ela test...regress fraction taking on percent katrina


* collapse the data to capture fraction katrina and number of test takers at the school*grade*year level

* I don't restrict the count to non-evacuees since that would create a mechanical correlation with fraction evacuee and fraction taker

collapse Kfraction_math* Kfraction_ela* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* (count) mathCOUNT=mathSTD elaCOUNT=elaSTD  if katrina_district2==0   & percent_katrinaTIMESERIES2<.7, by(sitecode year grade_num)

* merge in the number of kids in each grade for that school
sort sitecode year grade_num

merge sitecode year grade_num using num_kids_bygrade

* calculate fraction of takers
gen fraction_takers_math=mathCOUNT/num_grade
gen fraction_takers_ela=elaCOUNT/num_grade


* calculate year to year change in enrollment

sort sitecode grade_num year 
gen enrollment_change=num_grade - num_grade[_n-1] if year==year[_n-1]+1 & sitecode==sitecode[_n-1] & grade_num==grade_num[_n-1]
gen enrollment_change_ratio=num_grade/num_grade[_n-1] if year==year[_n-1]+1 & sitecode==sitecode[_n-1] & grade_num==grade_num[_n-1]


gen percent_katrina_2006a=percent_katrinaTIMESERIES if year==2006   // YEAR HARDCODE: 2006 = first post-Katrina year
egen percent_katrina_2006=max(percent_katrina_2006a), by(sitecode)

* regression of enrollment change on katrina fraction
areg enrollment_change Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if grade_num>=6, absorb(sitecode) cluster(sitecode)

gen grade_year = year*100 + grade_num
xtset sitecode grade_year
reg l.enrollment_change percent_katrina_2006 free_lunchA male black hisp asian gryr* if year==2006, cluster(sitecode)
reg l.enrollment_change_ratio percent_katrina_2006 free_lunchA male black hisp asian gryr* if grade_num >=6 & year==2006, cluster(sitecode)



* ---- Regress fraction of test-takers on evacuee quartile / linear shares ----
* regression that fraction on percent katrina
areg fraction_takers_math Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if grade_num>=6, absorb(sitecode) cluster(sitecode)


areg fraction_takers_math percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if grade_num>=6, absorb(sitecode) cluster(sitecode)


areg fraction_takers_ela Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if grade_num>=6, absorb(sitecode) cluster(sitecode)


areg fraction_takers_ela percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if grade_num>=6, absorb(sitecode) cluster(sitecode)


* ===============================================================================
* END OF ACTIVE PROGRAM. Everything below the following `endsas;` is unreachable
* scratch / exploratory code (extra peer-effect, Rita, switcher, and evacuee
* regressions). `endsas;`/`f` halt execution, so these blocks do NOT run and do
* NOT feed any published table. Left in place for the authors' reference.
* ===============================================================================
endsas;















endsas;


*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7





endsas;
**************
** Overall Table ***
**************

*******************************
*******************************
*** Show that the pattern holds even before we split into quantiles of own ability
*******************************
*******************************

*FULL SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if elaQD1 != ., absorb(sitecode) cluster(sitecode)


*LAG SAMPLE (NO LAG - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != . & math_lag != ., absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != . & ela_lag != ., absorb(sitecode) cluster(sitecode)


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

****************************
** BY NATIVE LAGGED SCORE QUARTILE**
****************************


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""

*FULL SAMPLE (NO LAG)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)


*LAG SAMPLE (NO LAG - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1 & math_lag != ., absorb(sitecode) cluster(sitecode)


areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1 & ela_lag != ., absorb(sitecode) cluster(sitecode)


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)

areg mathSTD math_lag_* Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & mathQD`quart' == 1, absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if lagsample == 1 & elaQD`quart' == 1, absorb(sitecode) cluster(sitecode)

}

f














*******************************
*******************************
*** what's the effect of number of katrina kids in my classrom
*** what's the effect of discplined katrina kids in my classroom
*******************************
*******************************





**************
** bad apple/ classroom level regs ***
**************

*******************************
*******************************
*** what's the effect of number of katrina kids in my classrom
*** what's the effect of discplined katrina kids in my classroom
*******************************
*******************************

areg mathSTD count_katrinaDISCIPLINE_class count_katrina_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* count_katrinaDISCIPLINE_class count_katrina_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5, absorb(sitecode) cluster(sitecode)



areg elaSTD count_katrinaDISCIPLINE_class count_katrina_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* count_katrinaDISCIPLINE_class count_katrina_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5, absorb(sitecode) cluster(sitecode)


* include just the count of disciplined kids

areg mathSTD count_katrinaDISCIPLINE_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* count_katrinaDISCIPLINE_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5, absorb(sitecode) cluster(sitecode)



areg elaSTD count_katrinaDISCIPLINE_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* count_katrinaDISCIPLINE_class free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5, absorb(sitecode) cluster(sitecode)








**************************************************************
**************************************************************
**************************************************************
**************************************************************
** Run entire set of regressions with percent katrina defined at school*grade level
**************************************************************
**************************************************************
**************************************************************




*******************************
*******************************
*** Now limit the sample to grade*years where we have lots of data to measure percent katrina....define usable as where we know katrina status on 75% or more of the grade
*******************************
*******************************
*******************************

egen obs_count_school_grade=count(katrina_sum), by(district_code school_code grade_num year)


egen obs_count_school_grade0405=count(math_lag*katrina_sum), by(district_code school_code grade_num year)


gen fraction_usable_katrinaquartiles= obs_count_school_grade0405/ obs_count_school_grade

gen byte usable=0
replace usable=1 if fraction_usable>.75 & fraction_usable!=.



* usable 2 is based off years and grades where we have lots of katrina evacuee status for that grade

gen byte usable2=0
replace usable2=1 if year==2004 & (grade_num==8 | grade_num==10)
replace usable2=1 if year==2005 & (grade_num==8 | grade_num==10)
replace usable2=1 if year==2006 & (grade_num>=5 & grade_num<=11)
replace usable2=1 if year==2007 & (grade_num>=6 & grade_num<=11)
replace usable2=1 if year==2008 & (grade_num>=7 & grade_num<=11)
replace usable2=1 if year==2009 & (grade_num>=8 & grade_num<=11)


* usable 3 is based off Scott's email summarizing where the data should be available

gen byte usable3=0
replace usable3=1 if year==2006 & (grade_num==3)
replace usable3=1 if (grade_num==4)
replace usable3=1 if year>=2006 & (grade_num==5)
replace usable3=1 if year>=2006 & (grade_num==6)
replace usable3=1 if year>=2006 & (grade_num==7)
replace usable3=1 if (grade_num==8)
replace usable3=1 if year>=2006 & (grade_num==9)
replace usable3=1 if (grade_num==10)

/*
	Year -->	2004	2005	2006	2007
Grade

Elem (no lags)
3			N	N	Y	N
4			Y	Y	Y	Y
5			N	N	Y	Y

Midhigh (with lags)
6			N	N	Y	Y
7			N	N	Y	Y
8			Y	Y	Y	Y
9			N	N	Y	Y
10			N	Y	Y	Y

*/


**************
** Overall Table ***
**************

*******************************
*******************************
*** Show that the pattern holds even before we split into quantiles of own ability
*******************************
*******************************

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5  & usable3==1, absorb(sitecode) cluster(sitecode)


areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5  & usable3==1, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5  & usable3==1, absorb(sitecode) cluster(sitecode)


areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5  & usable3==1, absorb(sitecode) cluster(sitecode)











*******************************
*******************************
*** within each quartile of own past performance, ask how fraction katrina in each quartile matters
*******************************
*******************************


***
* after each regression, test for monotonicity, botiqueing
****

****Run it for elementary ****
areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD1==1 & usable3==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD2==1 & usable3==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD3==1 & usable3==1, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD4==1 & usable3==1, absorb(sitecode) cluster(sitecode)



* middle and high schools
areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD1==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ1G_MH if e(sample)


areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD2==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ2G_MH if e(sample)


areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD3==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ3G_MH if e(sample)

areg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD4==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ4G_MH if e(sample)



* results for ELA elementary


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD1==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ1G_elem if e(sample)


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD2==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ2G_elem if e(sample)


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD3==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ3G_elem if e(sample)

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & elaQD4==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ4G_elem if e(sample)




* results for ELA middle and high


areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD1==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ1G_MH if e(sample)


areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD2==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ2G_MH if e(sample)


areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD3==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ3G_MH if e(sample)

areg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD4==1 & usable3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ4G_MH if e(sample)










*******************************
*******************************
*** Run quartile specifications without lagged dependent variable
*******************************
*******************************
*******************************


* middle and high schools
areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD1==1 & usable3==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD2==1 & usable3==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD3==1 & usable3==1, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD4==1 & usable3==1, absorb(sitecode) cluster(sitecode)



* results for ELA middle and high


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD1==1 & usable3==1, absorb(sitecode) cluster(sitecode)


areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD2==1 & usable3==1, absorb(sitecode) cluster(sitecode)


areg elaSTD  Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD3==1 & usable3==1, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & elaQD4==1 & usable3==1, absorb(sitecode) cluster(sitecode)









































endsas;


*******************************
*******************************
*** try regressions with student fixed effects rather than school fixed effects and lagged variables
*******************************
*******************************

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5, absorb(id) cluster(sitecode)




/*

mean of usable by grade and year
-------------------------------------------------------------------------------------------------
       |                                        grade_num                                        
  year |       3        4        5        6        7        8        9       10       11       12
-------+-----------------------------------------------------------------------------------------
       | 
  2004 |          .000948                             .806252           .695116      .75      .45
       |           47,444                              42,447             2,191      156       20
       | 
  2005 |          .003554                             .976159           .994789  .937564        1
       |           51,204                              47,020            35,119    1,938       35
       | 
  2006 |       0   .00187  .986988  .987422  .982278  .962408  .998521  .998922  .998254  .995426
       |  48,073   52,418   46,727   47,860   50,390   50,144   56,807   41,753   36,075    1,749
       | 
  2007 |  .00047        0  .003401  .992556  .988321   .98694  .986425  .999496  .995676  .946269
       |   2,129   46,722   45,280   46,483   45,722   44,945   53,113   39,659   33,995    1,340
       | 
  2008 |       0  .000125  .000077  .007634   .99628  .990729  .990293  .981568  .994628  .924979
       |      35    7,988   38,826   44,670   44,087   43,147   47,799   37,598   32,948    1,173
       | 
  2009 |       0  .004107        0  .000101  .012733   .99103  .991089  .990281  .983545   .94303
       |       8      487    6,961   39,770   43,272   42,031   46,349   34,881   31,297      825
-------------------------------------------------------------------------------------------------

*/













* middle and high schools
areg mathSTD math_lag Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD1==1 & usable2==1, absorb(sitecode) cluster(sitecode)


areg mathSTD math_lag Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD2==1  & usable2==1, absorb(sitecode) cluster(sitecode)


areg mathSTD math_lag Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD3==1  & usable2==1, absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD4==1  & usable2==1, absorb(sitecode) cluster(sitecode)



*******************************
*******************************
*** Run quartile specifications without lagged dependent variable
*******************************
*******************************
*******************************



areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD1==1  & usable2==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD2==1  & usable2==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD3==1  & usable2==1, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num<=5 & mathQD4==1  & usable2==1, absorb(sitecode) cluster(sitecode)



* middle and high schools
areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD1==1  & usable2==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD2==1  & usable2==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD3==1  & usable2==1, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrina<.7 & grade_num>5 & mathQD4==1  & usable2==1, absorb(sitecode) cluster(sitecode)



************************************************************************
* run basic specification include lagged dependent variable at the grade level, limit to most usable of the observations
************************************************************************
xtset sitecode


xtreg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & usable2==1, fe cluster(sitecode)


xtreg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5 & usable2==1, fe cluster(sitecode)

xtreg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & usable2==1, fe cluster(sitecode)


xtreg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5 & usable2==1, fe cluster(sitecode)













************************************************************************
* run basic specification include lagged dependent variable
************************************************************************

xtset sitecode

xtreg mathSTD math_lag percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5, fe cluster(sitecode)


xtreg mathSTD math_lag percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5, fe cluster(sitecode)

xtreg elaSTD ela_lag percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5, fe cluster(sitecode)


xtreg elaSTD ela_lag percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5, fe cluster(sitecode)






************************************************************************
* run basic specification no lagged dependent variable
************************************************************************

xtset sitecode

xtreg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5, fe cluster(sitecode)


xtreg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5, fe cluster(sitecode)

xtreg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5, fe cluster(sitecode)


xtreg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5, fe cluster(sitecode)




************************************************************************
* run basic specification no lagged dependent variable, define percent katrina at grade level
************************************************************************

xtset sitecode

xtreg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5, fe cluster(sitecode)


xtreg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5, fe cluster(sitecode)

xtreg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5, fe cluster(sitecode)


xtreg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5, fe cluster(sitecode)

















*******************
*******************
** TABLE Rita *******
*******************
*******************

************************************************************************
* run basic specification but include percent Rita, include lagged dependent variable
************************************************************************

xtset sitecode

xtreg mathSTD math0005 percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num<=5, fe cluster(sitecode)


xtreg mathSTD math0005 percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num>5, fe cluster(sitecode)

xtreg elaSTD ela0005 percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num<=5, fe cluster(sitecode)


xtreg elaSTD ela0005 percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num>5, fe cluster(sitecode)

* xtreg elaSTD percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num>5, fe 








endsas;
*************************************************************************
*************************************************************************
*************************************************************************
*************************************************************************
**RERUN ALL quantiles stuff but include percent_katrina Discipline *****
*************************************************************************
*************************************************************************
*************************************************************************
*************************************************************************
*************************************************************************





*******************************
*******************************
*** within each quartile of own past performance, ask how fraction katrina in each quartile matters
*******************************
*******************************

****Run it for just elementary for now ****
areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & mathQD1==1, absorb(sitecode) cluster(sitecode)

* predict fitted_mathQ1_elem if e(sample)

areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & mathQD2==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ2_elem if e(sample)


areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & mathQD3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ3_elem if e(sample)

areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & mathQD4==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ4_elem if e(sample)



* middle and high schools
* list of grade year interactions needed for middle and high 
* gryr*
areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & mathQD1==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ1_MH if e(sample)


areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & mathQD2==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ2_MH if e(sample)


areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & mathQD3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ3_MH if e(sample)

areg mathSTD percent_katrinaDISCIPLINE2 Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & mathQD4==1, absorb(sitecode) cluster(sitecode)
* predict fitted_mathQ4_MH if e(sample)



* results for ELA elementary


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & elaQD1==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ1_elem if e(sample)


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & elaQD2==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ2_elem if e(sample)


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & elaQD3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ3_elem if e(sample)

areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num<=5 & elaQD4==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ4_elem if e(sample)




* results for ELA middle and high


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & elaQD1==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ1_MH if e(sample)


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & elaQD2==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ2_MH if e(sample)


areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & elaQD3==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ3_MH if e(sample)

areg elaSTD percent_katrinaDISCIPLINE2 Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & grade_num>5 & elaQD4==1, absorb(sitecode) cluster(sitecode)
* predict fitted_elaQ4_MH if e(sample)






































endsas;

**************
** Quantiles table ***
**************

*******************************
*******************************
*** within each quartile of own past performance, ask how fraction katrina in each quartile matters
*******************************
*******************************

****Run it for just grades 5 6 9 10 11 ****
areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & mathQD1==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & mathQD2==1, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & mathQD3==1, absorb(sitecode) cluster(sitecode)



areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & mathQD4==1, absorb(sitecode) cluster(sitecode)



**Run it for Middle and High ***
areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11) & mathQD1==1, absorb(sitecode) cluster(sitecode)


areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11)& mathQD2==1, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11)& mathQD3==1, absorb(sitecode) cluster(sitecode)



areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11)& mathQD4==1, absorb(sitecode) cluster(sitecode)





****ELA RESULTS at the GRADE*School level 
****Run it for just grades 5 6 8 9 ****
areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & elaQD1==1, absorb(sitecode) cluster(sitecode)


areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & elaQD2==1, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & elaQD3==1, absorb(sitecode) cluster(sitecode)



areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==5) & elaQD4==1, absorb(sitecode) cluster(sitecode)



**Run it for Middle and High ***
areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11) & elaQD1==1, absorb(sitecode) cluster(sitecode)


areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11)& elaQD2==1, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11)& elaQD3==1, absorb(sitecode) cluster(sitecode)



areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0   & percent_katrinaTIMESERIES2<.7 & (grade_num==6 | grade_num==9 | grade_num==10 | grade_num==11)& elaQD4==1, absorb(sitecode) cluster(sitecode)










endsas;



*******************
*******************
** TABLE Rita *******
*******************
*******************

************************************************************************
* run basic specification but include percent Rita
************************************************************************


xtreg mathSTD percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num<=5, fe cluster(sitecode)


xtreg mathSTD percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008  if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num>5, fe cluster(sitecode)

xtreg elaSTD percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num<=5, fe cluster(sitecode)


xtreg elaSTD percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008  if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num>5, fe cluster(sitecode)

* xtreg elaSTD percent_katrinaTIMESERIES2 percent_ritaTIMESERIES2 free_lunchA male black hisp asian   gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008 if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.3 & grade_num>5, fe 









*******************
*******************
** TABLE about Evacuees *******
*******************
*******************

************************************************************************
* regress pre-hurricane math score on evacuee status with 2006 school dummies
************************************************************************

* regress pre-hurrance scores on being a dummy for an evacuee, within post hurricane school


xtreg math0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.3 & grade_num<=5 & year==2006, cluster(sitecode) fe

xtreg math0405 katrina_sum free_lunchA male black asian hisp gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008  if katrina_district2==0  & percent_katrina<.3 & grade_num>5 & year==2006, cluster(sitecode) fe

xtreg math0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.3 & year==2006, cluster(sitecode) fe



xtreg ela0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.3 & grade_num<=5 & year==2006, cluster(sitecode) fe


xtreg ela0405 katrina_sum free_lunchA male black asian hisp gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008  if katrina_district2==0  & percent_katrina<.3 & grade_num>5 & year==2006, cluster(sitecode) fe


xtreg ela0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.3 & year==2006, cluster(sitecode) fe




******************************************
** switchers means table and regression ***
*****************************************

table year katrina_sum, c(mean switch n switch)

******************************
**run switching regression for years post-hurricane and for grades 4,5, 7,8, 10,11 ****
**********************************
* elementary
areg switch percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_district2==0   & percent_katrina<.3 & grade_num<=5 & grade_num>=4 & year>2005 & katrina_sum!=1, absorb(sitecode) cluster(sitecode)


* middle
areg switch percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008  if katrina_district2==0   & percent_katrina<.3 & grade_num<=8 & grade_num>=7 & year>2005 & katrina_sum!=1, absorb(sitecode) cluster(sitecode)


* high 
areg switch percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008 if katrina_district2==0   & percent_katrina<.3 & grade_num<=11 & grade_num>=10 & year>2005 & katrina_sum!=1, absorb(sitecode) cluster(sitecode)











endsas;




* now regress on own outcomes on fraction of peers in each category, interactions , interactions of katrina students, and IV for peers with katrina fraction in each group


* repeat the canonical regression

areg mathSTD percent_katrinaTIMESERIES2  free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)



areg mathSTD percent_katrinaTIMESERIES2  free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)


areg elaSTD percent_katrinaTIMESERIES2  free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)



areg elaSTD percent_katrinaTIMESERIES2  free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)




* run the canonincal regression but include both katrina and rita fractions

areg mathSTD percent_katrinaTIMESERIES2  percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg mathSTD percent_katrinaTIMESERIES2  percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)


areg elaSTD percent_katrinaTIMESERIES2  percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5, absorb(sitecode) cluster(sitecode)


areg elaSTD percent_katrinaTIMESERIES2  percent_ritaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)





* try original regression with fraction katrina in each quartile, but not fully interacted

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg mathSTD Kfraction_mathQ1 Kfraction_mathQ2 Kfraction_mathQ3 Kfraction_mathQ4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)


areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5, absorb(sitecode) cluster(sitecode)

areg elaSTD Kfraction_elaQ1 Kfraction_elaQ2 Kfraction_elaQ3 Kfraction_elaQ4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5, absorb(sitecode) cluster(sitecode)


* try interacting race with each quartile of percent katrina...include school fixed effects
areg mathSTD blackxKFractionQ1 blackxKFractionQ2 blackxKFractionQ3 blackxKFractionQ4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year>2005, absorb(sitecode) cluster(sitecode)


areg mathSTD blackxKFractionQ1 blackxKFractionQ2 blackxKFractionQ3 blackxKFractionQ4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year>2005, absorb(sitecode) cluster(sitecode)

areg elaSTD blackxKFractionQ1ela blackxKFractionQ2ela blackxKFractionQ3ela blackxKFractionQ4ela free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year>2005, absorb(sitecode) cluster(sitecode)

areg elaSTD blackxKFractionQ1ela blackxKFractionQ2ela blackxKFractionQ3ela blackxKFractionQ4ela free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year>2005, absorb(sitecode) cluster(sitecode)





* look at effects of katrina kids in each quartile
* limit ourselves to years after the hurricane...because quartiles are determined on the two pre-years

areg mathSTD Q1xKFractionQ1 Q1xKFractionQ2 Q1xKFractionQ3 Q1xKFractionQ4 Q2xKFractionQ1 Q2xKFractionQ2 Q2xKFractionQ3 Q2xKFractionQ4 Q3xKFractionQ1 Q3xKFractionQ2 Q3xKFractionQ3 Q3xKFractionQ4 Q4xKFractionQ1 Q4xKFractionQ2 Q4xKFractionQ3 Q4xKFractionQ4 mathQD1 mathQD3 mathQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year>2005, absorb(sitecode) cluster(sitecode)


areg mathSTD Q1xKFractionQ1 Q1xKFractionQ2 Q1xKFractionQ3 Q1xKFractionQ4 Q2xKFractionQ1 Q2xKFractionQ2 Q2xKFractionQ3 Q2xKFractionQ4 Q3xKFractionQ1 Q3xKFractionQ2 Q3xKFractionQ3 Q3xKFractionQ4 Q4xKFractionQ1 Q4xKFractionQ2 Q4xKFractionQ3 Q4xKFractionQ4 mathQD1 mathQD3 mathQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year>2005, absorb(sitecode) cluster(sitecode)




* look at effects of katrina kids in each quartile ELA
areg elaSTD Q1xKFractionQ1ela Q1xKFractionQ2ela Q1xKFractionQ3ela Q1xKFractionQ4ela Q2xKFractionQ1ela Q2xKFractionQ2ela Q2xKFractionQ3ela Q2xKFractionQ4ela Q3xKFractionQ1ela Q3xKFractionQ2ela Q3xKFractionQ3ela Q3xKFractionQ4ela Q4xKFractionQ1ela Q4xKFractionQ2ela Q4xKFractionQ3ela Q4xKFractionQ4ela elaQD1 elaQD3 elaQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year>2005, absorb(sitecode) cluster(sitecode)


areg elaSTD Q1xKFractionQ1ela Q1xKFractionQ2ela Q1xKFractionQ3ela Q1xKFractionQ4ela Q2xKFractionQ1ela Q2xKFractionQ2ela Q2xKFractionQ3ela Q2xKFractionQ4ela Q3xKFractionQ1ela Q3xKFractionQ2ela Q3xKFractionQ3ela Q3xKFractionQ4ela Q4xKFractionQ1ela Q4xKFractionQ2ela Q4xKFractionQ3ela Q4xKFractionQ4ela elaQD1 elaQD3 elaQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year>2005, absorb(sitecode) cluster(sitecode)




*****************************************************
************Scott's Specification *******************
*****************************************************

* include all years but allow quartile dummies to come on only after 2005

areg mathSTD Q1xKFractionQ1 Q1xKFractionQ2 Q1xKFractionQ3 Q1xKFractionQ4 Q2xKFractionQ1 Q2xKFractionQ2 Q2xKFractionQ3 Q2xKFractionQ4 Q3xKFractionQ1 Q3xKFractionQ2 Q3xKFractionQ3 Q3xKFractionQ4 Q4xKFractionQ1 Q4xKFractionQ2 Q4xKFractionQ3 Q4xKFractionQ4 mathQD1_after mathQD3_after mathQD4_after free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5, absorb(sitecode) cluster(sitecode)


areg mathSTD Q1xKFractionQ1 Q1xKFractionQ2 Q1xKFractionQ3 Q1xKFractionQ4 Q2xKFractionQ1 Q2xKFractionQ2 Q2xKFractionQ3 Q2xKFractionQ4 Q3xKFractionQ1 Q3xKFractionQ2 Q3xKFractionQ3 Q3xKFractionQ4 Q4xKFractionQ1 Q4xKFractionQ2 Q4xKFractionQ3 Q4xKFractionQ4 mathQD1_after mathQD3_after mathQD4_after free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 , absorb(sitecode) cluster(sitecode)




* look at effects of katrina kids in each quartile ELA
areg elaSTD Q1xKFractionQ1ela Q1xKFractionQ2ela Q1xKFractionQ3ela Q1xKFractionQ4ela Q2xKFractionQ1ela Q2xKFractionQ2ela Q2xKFractionQ3ela Q2xKFractionQ4ela Q3xKFractionQ1ela Q3xKFractionQ2ela Q3xKFractionQ3ela Q3xKFractionQ4ela Q4xKFractionQ1ela Q4xKFractionQ2ela Q4xKFractionQ3ela Q4xKFractionQ4ela elaQD1_after elaQD3_after elaQD4_after free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5, absorb(sitecode) cluster(sitecode)


areg elaSTD Q1xKFractionQ1ela Q1xKFractionQ2ela Q1xKFractionQ3ela Q1xKFractionQ4ela Q2xKFractionQ1ela Q2xKFractionQ2ela Q2xKFractionQ3ela Q2xKFractionQ4ela Q3xKFractionQ1ela Q3xKFractionQ2ela Q3xKFractionQ3ela Q3xKFractionQ4ela Q4xKFractionQ1ela Q4xKFractionQ2ela Q4xKFractionQ3ela Q4xKFractionQ4ela elaQD1_after elaQD3_after elaQD4_after free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 , absorb(sitecode) cluster(sitecode)







*****************************************************************************
* run the same stuff but without school fixed effects...identify off cross school variation
*****************************************************************************


reg mathSTD Q1xKFractionQ1 Q1xKFractionQ2 Q1xKFractionQ3 Q1xKFractionQ4 Q2xKFractionQ1 Q2xKFractionQ2 Q2xKFractionQ3 Q2xKFractionQ4 Q3xKFractionQ1 Q3xKFractionQ2 Q3xKFractionQ3 Q3xKFractionQ4 Q4xKFractionQ1 Q4xKFractionQ2 Q4xKFractionQ3 Q4xKFractionQ4 mathQD1 mathQD3 mathQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year>2005, cluster(sitecode)


reg mathSTD Q1xKFractionQ1 Q1xKFractionQ2 Q1xKFractionQ3 Q1xKFractionQ4 Q2xKFractionQ1 Q2xKFractionQ2 Q2xKFractionQ3 Q2xKFractionQ4 Q3xKFractionQ1 Q3xKFractionQ2 Q3xKFractionQ3 Q3xKFractionQ4 Q4xKFractionQ1 Q4xKFractionQ2 Q4xKFractionQ3 Q4xKFractionQ4 mathQD1 mathQD3 mathQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year>2005, cluster(sitecode)




* look at effects of katrina kids in each quartile ELA
reg elaSTD Q1xKFractionQ1ela Q1xKFractionQ2ela Q1xKFractionQ3ela Q1xKFractionQ4ela Q2xKFractionQ1ela Q2xKFractionQ2ela Q2xKFractionQ3ela Q2xKFractionQ4ela Q3xKFractionQ1ela Q3xKFractionQ2ela Q3xKFractionQ3ela Q3xKFractionQ4ela Q4xKFractionQ1ela Q4xKFractionQ2ela Q4xKFractionQ3ela Q4xKFractionQ4ela elaQD1 elaQD3 elaQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year>2005, cluster(sitecode)


reg elaSTD Q1xKFractionQ1ela Q1xKFractionQ2ela Q1xKFractionQ3ela Q1xKFractionQ4ela Q2xKFractionQ1ela Q2xKFractionQ2ela Q2xKFractionQ3ela Q2xKFractionQ4ela Q3xKFractionQ1ela Q3xKFractionQ2ela Q3xKFractionQ3ela Q3xKFractionQ4ela Q4xKFractionQ1ela Q4xKFractionQ2ela Q4xKFractionQ3ela Q4xKFractionQ4ela elaQD1 elaQD3 elaQD4 free_lunchA male black asian hisp gryr* if katrina_sum!=1 & katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year>2005, cluster(sitecode)




* regress pre-hurrance scores on being a dummy for an evacuee, within post hurricane school


areg math0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year==2006, cluster(sitecode) absorb(sitecode)

areg math0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year==2006, cluster(sitecode) absorb(sitecode)

areg math0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & year==2006, cluster(sitecode) absorb(sitecode)



areg ela0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year==2006, cluster(sitecode) absorb(sitecode)


areg ela0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year==2006, cluster(sitecode) absorb(sitecode)


areg ela0405 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & year==2006, cluster(sitecode) absorb(sitecode)

