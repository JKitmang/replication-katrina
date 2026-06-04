*===============================================================================
* FILE:     summary_stats_la.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (summary statistics)
* PRODUCES: Table 1 and Appendix Table 2 -- Louisiana (statewide) descriptive
*           statistics for evacuees vs. native (incumbent) students.
*
* PURPOSE:  Builds the Louisiana statewide analysis sample (same data prep as
*           the LA quartile/linear drivers) and reports summary statistics:
*           means of demographics, free-lunch, evacuee shares, standardized
*           test scores and discipline for evacuees (katrina_sum==1) vs.
*           natives (katrina_sum==0) in 2006, both unweighted and school-
*           weighted; sample-size (N) and number-of-schools tabulations; and
*           the distribution of school- and grade-level evacuee shares.
*
* INPUTS:   /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta
*           /work/i/imberman/imberman/la_data/alternative_standardization.dta
*           /work/i/imberman/imberman/la_data/discipline_prepped_microdata
*           /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta
* OUTPUTS:  temp2.dta (working file); summary statistics printed to log.
*
* KEY STEPS:
*   - Load LA full sample; merge in alternative-standardized scores, discipline,
*     and test-administrator (classroom) data.
*   - Build baseline achievement quartiles (math/ela) within grade x year.
*   - Apply grade/year sample restrictions; define the lag sample.
*   - Recode/define evacuee share (percent_katrina*) at school, grade, class.
*   - Report summary stats (unweighted, school-weighted, any-katrina) for 2006.
*   - Tabulate sample sizes and number of schools; collapse to school-grade for
*     the evacuee-share distribution.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Absolute paths /work/i/imberman/imberman/la_data/... (4 use/merge files)
*     and the commented Windows path D:\School\Katrina\... -- PATH: repoint.
*   - keep if year>=2000 & year<=2007 (analysis window).
*   - drop if year==2006/2007 & grade_num==4/5 (grade-year exclusions).
*   - lagsample thresholds year>2001 / >2003 / >2005 by grade.
*   - replace percent_*=0 if year<=2005 (pre-treatment shares are 0).
*   - forvalues year=2000/2005 lag-year loop.
*   - drop if year==2006 & sitecode==57028 (all-evacuee school).
*   - All summary stats conditioned on year==2006 (the reported post year).
*
* NOTE: Documentation comments only -- no executable code was modified.
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


* ---- Load LA statewide full sample ----
* PATH: repoint to your local globals
use /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta
* sample 3

drop  gender district_name school_name birth_month birth_day birth_year ela_raw math_raw sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


* ---- Merge in alternatively-standardized achievement (score standardization) ----
*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using /work/i/imberman/imberman/la_data/alternative_standardization.dta  // PATH: repoint to your local globals
drop _merge

* ---- Baseline achievement quartiles within grade x year (math & ela) ----
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

keep if year >= 2000 & year <= 2007   // YEAR HARDCODE: analysis window; widen for new years
keep if grade_num >= 4 & grade_num <= 10
drop if year == 2006 & grade_num == 4   // YEAR HARDCODE: grade-year not tested
drop if year == 2007 & grade_num == 4   // YEAR HARDCODE: grade-year not tested
drop if year == 2007 & grade_num == 5   // YEAR HARDCODE: grade-year not tested


* ---- Identify the lag sample (grades/years with a usable pre-Katrina lag) ----
*IDENTIFY THE LAG SAMPLE
gen lagsample = 0
replace lagsample = 1 if year > 2001 & grade_num == 10   // YEAR HARDCODE: lag availability by grade
replace lagsample = 1 if year > 2003 & grade_num == 8     // YEAR HARDCODE: lag availability by grade
replace lagsample = 1 if year > 2005 & (grade_num == 6 | grade_num == 7 | grade_num == 9)   // YEAR HARDCODE: lag availability by grade



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
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-2005 lags forced to be pre-Katrina scores
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE: post-2005 lags forced to be pre-Katrina scores


* ---- Baseline (pre-Katrina) achievement quartiles for sorting students ----
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


***********************************
* merge in the discipline data
***********************************
* ---- Merge in discipline microdata ----
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/discipline_prepped_microdata  // PATH: repoint to your local globals

tab _m

drop if _m==2


***********************************
* merge in the test administrator data
***********************************
* ---- Merge in test-administrator numbers (used to define classrooms) ----
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta  // PATH: repoint to your local globals

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
replace cameron_calcasieu=1 if district_code==10 | district_code==12



* redefine katrina_district2 so that cameron and calcasieu districts are also excluded in the peer effects regressions

replace katrina_district2=1 if cameron_calcasieu==1


* ---- Define evacuee shares (percent Rita / percent Katrina) ----
* define percent Rita

egen percent_ritaTIMESERIES2=mean(rita), by(district_code school_code year)
replace percent_ritaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: no evacuees before 2005-06, share=0


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
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: pre-Katrina school-year share=0


egen percent_katrinaTIMESERIESG=mean(katrina_sum), by(district_code school_code year grade_num)
replace percent_katrinaTIMESERIESG=0 if year<=2005   // YEAR HARDCODE: pre-Katrina grade-year share=0

*GENERATE COUNTS BY GRADE
egen katrina_number_grade = sum(katrina_sum), by(district_code school_code year grade_num)
replace katrina_number_grade = 0 if year <= 2005   // YEAR HARDCODE: pre-Katrina evacuee count=0
gen unit = 1
egen enroll_grade = sum(unit), by(district_code school_code year grade_num)


* gen white=(black==0 & asian==0 & hisp==0)

* gen grade_num=real(grade)



***************************
* define katrina peer averages of discplined vs not
****************************

* ---- Define discipline outcome and Katrina-discipline peer measures ----
*discipline only available in 2005 & later
gen discipline = inschool_suspensions + outschool_suspensions + inschool_expulsions + outschool_expulsions
replace discipline = 0 if discipline == . & (mathSTD != . | elaSTD != .) & year >= 2005   // YEAR HARDCODE: discipline data start 2005
replace discipline = . if year <2005   // YEAR HARDCODE: no discipline data before 2005


gen discipline05a=discipline if year==2005   // YEAR HARDCODE: baseline (2005) discipline status

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








* ---- Build evacuee peer-share-by-quartile measures (baseline achievement quartiles) ----
* NOTE: all Kfraction_* below are set to 0 if year<=2005 (no pre-Katrina evacuees)
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



**************
** try interacting lag with number of years between now and lag
**************
gen math_lagyear2=math_lagyear
gen ela_lagyear2=ela_lagyear

replace math_lagyear = . if year > 2005   // YEAR HARDCODE: only post-2005 obs need lag-year recovery
replace ela_lagyear = . if year > 2005    // YEAR HARDCODE: only post-2005 obs need lag-year recovery
forvalues year = 2000/2005 {   // YEAR HARDCODE: candidate pre-Katrina lag years 2000-2005
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




* ---- Final sample restriction and analysis weights ----
*DROP ONE SCHOOL IN 2006 THAT HAS ONLY EVACUEES
drop if year == 2006 & sitecode == 57028 & katrina_sum == 1   // YEAR HARDCODE/PATH: specific all-evacuee school in 2006



*RESTRICT TO STUDENTS IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_district2==0 & percent_katrina<.7
egen enrollment = sum(unit), by(year sitecode katrina_sum)
gen school_weight = 1/enrollment
drop if sitecode == .

gen white = ethnicity == "5"
gen female = 1 - male

* ==== TABLE 1 / APP TABLE 2: LA summary stats, evacuees vs. natives (2006) ====
* Each sum below reports a column: katrina_sum==1 (evacuees) vs ==0 (natives),
* across unweighted / school-weighted-all / school-weighted-any-katrina panels.
*UNWEIGHTED
sum female white hisp black asian free_lunchA percent_katrinaTIMESERIES2 percent_katrinaTIMESERIESG mathSTD elaSTD discipline if year == 2006 & katrina_sum == 1
sum female white hisp black asian free_lunchA percent_katrinaTIMESERIES2 percent_katrinaTIMESERIESG mathSTD elaSTD discipline if year == 2006 & katrina_sum == 0

*SCHOOL WEIGHTED - ALL
sum female white hisp black asian free_lunchA percent_katrinaTIMESERIES2 percent_katrinaTIMESERIESG mathSTD elaSTD discipline [aw = school_weight] if year == 2006 & katrina_sum == 1
sum female white hisp black asian free_lunchA percent_katrinaTIMESERIES2 percent_katrinaTIMESERIESG mathSTD elaSTD discipline  [aw = school_weight] if year == 2006 & katrina_sum == 0


*SCHOOL WEIGHTED - ANY KATRINA
sum female white hisp black asian free_lunchA percent_katrinaTIMESERIES2 percent_katrinaTIMESERIESG mathSTD elaSTD discipline [aw = school_weight] if year == 2006 & katrina_sum == 1 & percent_katrinaTIMESERIES2 > 0
sum female white hisp black asian free_lunchA percent_katrinaTIMESERIES2 percent_katrinaTIMESERIESG mathSTD elaSTD discipline  [aw = school_weight] if year == 2006 & katrina_sum == 0  & percent_katrinaTIMESERIES2 > 0


* ==== TABLE 1 / APP TABLE 2: sample sizes (N obs) by group, level, outcome ====
**TABULATE SAMPLE SIZES

*NATIVES

*ELEM
tab year if grade_num <= 5  & katrina_sum == 0 
tab year if grade_num <= 5 & (discipline != .)  & katrina_sum == 0 
tab year if grade_num <= 5 & (mathSTD != . & mathQD1 != .)  & katrina_sum == 0 
tab year if grade_num <= 5 & (elaSTD != . & elaQD1 != .)  & katrina_sum == 0 


*MIDHIGH
tab year if grade_num > 5  & katrina_sum == 0 & lagsample == 1
tab year if grade_num > 5 & (discipline != .) & lagsample == 1  & katrina_sum == 0 
tab year if grade_num > 5 & (mathSTD != . & mathQD1 != . & math_lag !=.) & lagsample == 1  & katrina_sum == 0 
tab year if grade_num > 5 & (elaSTD != . & elaQD1 != . & ela_lag != .) & lagsample == 1 & katrina_sum == 0 

*EVACUEES

*ELEM
tab year if grade_num <= 5  & katrina_sum == 1 & year >= 2006
tab year if grade_num <= 5 & (discipline != .)  & katrina_sum == 1  & year >= 2006
tab year if grade_num <= 5 & (mathSTD != . & mathQD1 != .)  & katrina_sum == 1  & year >= 2006
tab year if grade_num <= 5 & (elaSTD != . & elaQD1 != .)  & katrina_sum == 1  & year >= 2006


*MIDHIGH
tab year if grade_num > 5  & katrina_sum == 1 & lagsample == 1  & year >= 2006
tab year if grade_num > 5 & (discipline != .) & lagsample == 1  & katrina_sum == 1  & year >= 2006
tab year if grade_num > 5 & (mathSTD != . & mathQD1 != . & math_lag != .) & lagsample == 1  & katrina_sum == 1  & year >= 2006
tab year if grade_num > 5 & (elaSTD != . & elaQD1 != . & ela_lag != .) & lagsample == 1 & katrina_sum == 1 & year >= 2006

*NUMBER OF SCHOOLS

**ALL 
unique sitecode if year == 2006 & katrina_sum == 0
unique sitecode if year == 2006 & katrina_sum == 1

**POSITIVE EVAC SHARE
unique sitecode if year == 2006 & katrina_sum == 0 & percent_katrinaTIMESERIES2 > 0 & percent_katrinaTIMESERIES2 < .7
unique sitecode if year == 2006 & katrina_sum == 1 & percent_katrinaTIMESERIES2 > 0 & percent_katrinaTIMESERIES2 < .7


save temp2, replace   // PATH: working file written to current dir

* ==== TABLE 1 / APP TABLE 2: distribution of school/grade evacuee shares ====
*COLLAPSE TO SCHOOL-GRADE (CONDITION ON HAVING MATH SCORE)
keep if katrina_sum == 0 & mathQD1 != . & percent_katrinaTIMESERIES2 < .7
collapse (mean) percent_katrinaTIMESERIES* Kfraction* lagsample, by(sitecode grade_num year)

sum percent_katrinaTIMESERIES* Kfraction_*G if year == 2006 & grade_num <= 5 , detail
sum percent_katrinaTIMESERIES* Kfraction_*G if year == 2006 & grade_num >= 5 & lagsample == 1, detail

use temp2, clear

*COLLAPSE TO SCHOOL-GRADE (CONDITION ON HAVING ELA SCORE)
keep if katrina_sum == 0 & elaQD1 != . & percent_katrinaTIMESERIES2 < .7
collapse (mean) percent_katrinaTIMESERIES* Kfraction* lagsample, by(sitecode grade_num year)

sum percent_katrinaTIMESERIES* Kfraction_*G if year == 2006 & grade_num <= 5 , detail
sum percent_katrinaTIMESERIES* Kfraction_*G if year == 2006 & grade_num >= 5 & lagsample == 1, detail
