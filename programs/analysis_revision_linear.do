*===============================================================================
* FILE:     analysis_revision_linear.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (main difference-in-differences / linear-in-means driver, LA)
* PRODUCES: Table 2 and Table 5 (Louisiana statewide linear peer-effect
*           estimates), plus Appendix Tables 12 & 13. Also runs the evacuee-
*           balance regressions, by-race / by-gender splits, classroom
*           "bad-apple" specs, switching regressions, and exploratory quartile
*           specs (many later blocks are scratch / cut off by endsas;).
*
* PURPOSE:  Builds the Louisiana statewide value-added analysis sample and
*           estimates how the school- (and grade-) level share of evacuees
*           affects incumbent (native) students' standardized test scores and
*           discipline, using school FE, grade x year FE, and pre-Katrina lags.
*           Identification: evacuee share = 0 before 2005-06 (diff-in-diff).
*           This is the LINEAR-in-means companion to the quartile drivers.
*
* INPUTS:   /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta
*           /work/i/imberman/imberman/la_data/alternative_standardization.dta
*           /work/i/imberman/imberman/la_data/discipline_prepped_microdata
*           /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta
* OUTPUTS:  Regression output to log (areg/reg with cluster(sitecode)); no .dta
*           saved. Results are hand-collected into Tables 2 & 5 / App 12 & 13.
*
* KEY STEPS:
*   - Load LA full sample; merge alt-standardized scores, discipline, TA numbers.
*   - Build baseline achievement quartiles within grade x year.
*   - Apply grade/year restrictions; define lag sample and pre-Katrina lags.
*   - Define evacuee shares (school, grade, class) and Katrina peer measures.
*   - Evacuee-balance regs (pre/post scores on evacuee dummy).
*   - Linear models at SCHOOL level and GRADE level: overall + by race/gender.
*   - Classroom "bad-apple" regressions; usable-sample flags; switching regs.
*   - Many trailing exploratory/quartile blocks after endsas; (not executed).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Absolute paths /work/i/imberman/imberman/la_data/... (4 files) and the
*     commented Windows path D:\School\Katrina\... -- PATH: repoint.
*   - keep if year>=2000 & year<=2007; grade-year drops for 2006/2007.
*   - lagsample thresholds (year>2001 / >2003 / >2005 by grade).
*   - replace math_lag/ela_lag=...if year>2005; replace percent_*=0 if year<=2005;
*     Kfraction_*=0 / Knumber_*=0 if year<=2005 (pre-treatment shares 0).
*   - forvalues year=2000/2005 lag-year loop.
*   - drop if year==2006 & sitecode==57028 (all-evacuee school).
*   - Balance regs use year==2006 / year==2007; switching regs use year>2005.
*   - usable2 / usable3 flags hardcode specific grade x year cells (2004-2009).
*
* NOTE: Over-300-line file: full header + section banners + all year/path flags
*       + estimation/output flags; not every line individually annotated.
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


* ---- Load LA statewide full sample ----  PATH: repoint to your local globals
use /work/i/imberman/imberman/la_data/la_prepped_revisionFULL_SAMPLE.dta
* sample 3

drop  gender district_name school_name birth_month birth_day birth_year ela_raw math_raw sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


* ---- Merge in alternatively-standardized achievement (score standardization) ----
*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using /work/i/imberman/imberman/la_data/alternative_standardization.dta  // PATH: repoint
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
replace math_lag=math0005 if year>2005   // YEAR HARDCODE: post-2005 lags forced to pre-Katrina scores
replace ela_lag=ela0005 if year>2005     // YEAR HARDCODE: post-2005 lags forced to pre-Katrina scores


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
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/discipline_prepped_microdata  // PATH: repoint

tab _m

drop if _m==2


***********************************
* merge in the test administrator data
***********************************
capture drop _m
sort id year

merge id year, using /work/i/imberman/imberman/la_data/tanumbers06-09_prepped2.dta  // PATH: repoint (test-administrator numbers define classrooms)

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
replace percent_katrinaTIMESERIES2=0 if year<=2005   // YEAR HARDCODE: pre-Katrina school-year share=0 (key DiD identification)


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








* ---- Build evacuee peer-share / peer-count by baseline-quartile measures ----
* All Kfraction_*/Knumber_* below are set to 0 if year<=2005 (no pre-Katrina evacuees).
* These (Kfraction_*Q1G..Q4G etc.) feed the quartile peer-effect specifications.
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


egen Knumber_mathQ1G = sum(mathQD1*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_mathQ2G = sum(mathQD2*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_mathQ3G = sum(mathQD3*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_mathQ4G = sum(mathQD4*katrina_sum), by(district_code school_code year grade_num)


egen Knumber_elaQ1G = sum(elaQD1*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_elaQ2G = sum(elaQD2*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_elaQ3G = sum(elaQD3*katrina_sum), by(district_code school_code year grade_num)
egen Knumber_elaQ4G = sum(elaQD4*katrina_sum), by(district_code school_code year grade_num)


replace Kfraction_mathQ1G=0 if year<=2005
replace Kfraction_mathQ2G=0 if year<=2005
replace Kfraction_mathQ3G=0 if year<=2005
replace Kfraction_mathQ4G=0 if year<=2005

replace Kfraction_elaQ1G=0 if year<=2005
replace Kfraction_elaQ2G=0 if year<=2005
replace Kfraction_elaQ3G=0 if year<=2005
replace Kfraction_elaQ4G=0 if year<=2005



replace Knumber_mathQ1G=0 if year<=2005
replace Knumber_mathQ2G=0 if year<=2005
replace Knumber_mathQ3G=0 if year<=2005
replace Knumber_mathQ4G=0 if year<=2005

replace Knumber_elaQ1G=0 if year<=2005
replace Knumber_elaQ2G=0 if year<=2005
replace Knumber_elaQ3G=0 if year<=2005
replace Knumber_elaQ4G=0 if year<=2005


egen Tnumber_mathQ1G = sum(mathQD1*unit), by(district_code school_code year grade_num)
egen Tnumber_mathQ2G = sum(mathQD2*unit), by(district_code school_code year grade_num)
egen Tnumber_mathQ3G = sum(mathQD3*unit), by(district_code school_code year grade_num)
egen Tnumber_mathQ4G = sum(mathQD4*unit), by(district_code school_code year grade_num)


egen Tnumber_elaQ1G = sum(elaQD1*unit), by(district_code school_code year grade_num)
egen Tnumber_elaQ2G = sum(elaQD2*unit), by(district_code school_code year grade_num)
egen Tnumber_elaQ3G = sum(elaQD3*unit), by(district_code school_code year grade_num)
egen Tnumber_elaQ4G = sum(elaQD4*unit), by(district_code school_code year grade_num)



foreach var of varlist enroll_grade Tnumber_* {
  gen `var'_2 = `var'^2
  gen `var'_3 = `var'^3
  gen `var'_4 = `var'^4
}

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




*DROP ONE SCHOOL IN 2006 THAT HAS ONLY EVACUEES
drop if year == 2006 & sitecode == 57028 & katrina_sum == 1   // YEAR HARDCODE/PATH: specific all-evacuee school in 2006

* ==== EVACUEE-BALANCE REGRESSIONS (evacuee vs native, within school) ====
* Regress pre/post scores & discipline on the evacuee dummy (katrina_sum) with
* school FE -- shows quasi-random placement. Feeds the evacuee-balance table.
*******************
*******************
** TABLE about Evacuees *******
*******************
*******************

keep if  katrina_district2==0 & percent_katrina<.7

************************************************************************
* regress pre-hurricane math score on evacuee status with 2006 school dummies
* YEAR HARDCODE: balance regs below condition on year==2006 (and a few year==2007)
************************************************************************

* regress pre & post -hurrance scores on being a dummy for an evacuee, within post hurricane school


areg math0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2006 & mathQD1 != ., cluster(sitecode) absorb(sitecode) 

areg math0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2006 & mathQD1 != . & lagsample == 1, cluster(sitecode) absorb(sitecode)



areg mathSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2006 & mathQD1 != ., cluster(sitecode) absorb(sitecode)

areg mathSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2006 & mathQD1 != .  & lagsample == 1, cluster(sitecode) absorb(sitecode)


*areg mathSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2007 & mathQD1 != ., cluster(sitecode) absorb(sitecode)

areg mathSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2007 & mathQD1 != .  & lagsample == 1, cluster(sitecode) absorb(sitecode)





areg ela0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2006 & elaQD1 != ., cluster(sitecode) absorb(sitecode)

areg ela0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2006 & elaQD1 != .  & lagsample == 1, cluster(sitecode) absorb(sitecode)



areg elaSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2006 & elaQD1 != ., cluster(sitecode) absorb(sitecode)

areg elaSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2006 & elaQD1 != .  & lagsample == 1, cluster(sitecode) absorb(sitecode)



*areg elaSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2007 & elaQD1 != ., cluster(sitecode) absorb(sitecode)

areg elaSTD katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2007 & elaQD1 != .  & lagsample == 1, cluster(sitecode) absorb(sitecode)




areg discipline05 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2006, cluster(sitecode) absorb(sitecode)

areg discipline05 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2006  & lagsample == 1, cluster(sitecode) absorb(sitecode)


areg discipline katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2006, cluster(sitecode) absorb(sitecode)

areg discipline katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2006  & lagsample == 1, cluster(sitecode) absorb(sitecode)


*areg discipline katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & year==2007, cluster(sitecode) absorb(sitecode)

areg discipline katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0  & percent_katrina<.7 & grade_num>5 & year==2007  & lagsample == 1, cluster(sitecode) absorb(sitecode)




f

*RESTRICT TO NON-EVACUEES IN SCHOOLS THAT WERE NOT IN EVAC AREA
keep if katrina_sum != 1 & katrina_district2==0 & percent_katrina<.7

destring ethnicity, replace force
* ==== TABLE 2 / TABLE 5 (App 12-13): LINEAR-IN-MEANS, SCHOOL-LEVEL evacuee share ====
* areg outcome on percent_katrinaTIMESERIES2 (school-year evacuee share) with
* school FE + grade x year FE, clustered by sitecode. Blocks below = overall
* (Table 2 main column) then by race (Black/Hisp/White) and gender (Table 5 /
* App 12-13 heterogeneity panels). Outcomes: mathSTD, elaSTD, discipline.
*********LINEAR MODELS - SCHOOL LEVEL**************

*ALL

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & lagsample == 1 & mathQD1 !=., absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & lagsample == 1 & elaQD1 !=., absorb(sitecode) cluster(sitecode)

areg discipline  percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & lagsample == 1, absorb(sitecode) cluster(sitecode)



*BLACK

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 3 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 3 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 3 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 3 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)



areg discipline percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 3, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 3 & lagsample == 1 , absorb(sitecode) cluster(sitecode)


*HISPANIC

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 4 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 4 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 4 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 4 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)


areg discipline percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 4, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 4 & lagsample == 1  , absorb(sitecode) cluster(sitecode)

*WHITE

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 5 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 5 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 5 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 5 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)


areg discipline percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 5, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 5 & lagsample == 1  , absorb(sitecode) cluster(sitecode)



*FEMALE

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 0 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 0 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 0 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 0 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)

areg discipline percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 0, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 0 & lagsample == 1  , absorb(sitecode) cluster(sitecode)



*MALE

areg mathSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 1 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 1 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)


areg discipline percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 1, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 1 & lagsample == 1  , absorb(sitecode) cluster(sitecode)




* ==== TABLE 2 / TABLE 5 (App 12-13): LINEAR-IN-MEANS, GRADE-LEVEL evacuee share ====
* Same as above but evacuee share defined at school x grade x year
* (percent_katrinaTIMESERIESG). Overall column, then by race and gender.
*********LINEAR MODELS - GRADE LEVEL**************

*ALL

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & mathQD1 != ., absorb(sitecode) cluster(sitecode)


areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)

areg discipline percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & lagsample == 1  , absorb(sitecode) cluster(sitecode)

*BLACK

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 3 & mathQD1 != ., absorb(sitecode) cluster(sitecode)


areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 3 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 3 & elaQD1 != ., absorb(sitecode) cluster(sitecode)


areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 3 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)

areg discipline percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 3, absorb(sitecode) cluster(sitecode)


areg discipline discipline_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 3 & lagsample == 1  , absorb(sitecode) cluster(sitecode)


*HISPANIC

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 4 & mathQD1 != ., absorb(sitecode) cluster(sitecode)


areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 4 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 4 & elaQD1 != ., absorb(sitecode) cluster(sitecode)


areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 4 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)

areg discipline percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 4, absorb(sitecode) cluster(sitecode)


areg discipline discipline_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 4 & lagsample == 1  , absorb(sitecode) cluster(sitecode)

*WHITE

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 5 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 5 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 5 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 5 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)


areg discipline percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & ethnicity == 5, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & ethnicity == 5 & lagsample == 1  , absorb(sitecode) cluster(sitecode)



*FEMALE

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 0 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 0 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 0 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 0 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)

areg discipline percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 0, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 0 & lagsample == 1  , absorb(sitecode) cluster(sitecode)



*MALE

areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 1 & mathQD1 != ., absorb(sitecode) cluster(sitecode)

areg mathSTD math_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 1 & lagsample == 1 & mathQD1 !=. , absorb(sitecode) cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 1 & elaQD1 != ., absorb(sitecode) cluster(sitecode)

areg elaSTD ela_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 1 & lagsample == 1 & elaQD1 !=. , absorb(sitecode) cluster(sitecode)

areg discipline percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num<=5 & male == 1, absorb(sitecode) cluster(sitecode)

areg discipline discipline_lag_* percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if  grade_num>5 & male == 1 & lagsample == 1 , absorb(sitecode) cluster(sitecode)





F


*******************************
*******************************
*** what's the effect of number of katrina kids in my classrom
*** what's the effect of discplined katrina kids in my classroom
*******************************
*******************************





* ==== BAD-APPLE / CLASSROOM-LEVEL regressions ====
* Effect of the COUNT of evacuee classmates (and disciplined evacuee classmates)
* on own score, with school FE. Tests the "bad-apple" peer-effect structure.
* (Note: reached only if the preceding `f`/`F` stop markers are removed.)
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


egen obs_count_school_grade0005=count(math_lag*katrina_sum), by(district_code school_code grade_num year)


gen fraction_usable_katrinaquartiles= obs_count_school_grade0005/ obs_count_school_grade

gen byte usable=0
replace usable=1 if fraction_usable>.75 & fraction_usable!=.



* ---- usable2/usable3: flags for grade x year cells with reliable evacuee data ----
* YEAR HARDCODE: these enumerate specific grade x year combinations (2004-2009);
* update the cell list for a new-years replication.
* usable 2 is based off years and grades where we have lots of katrina evacuee status for that grade

gen byte usable2=0
replace usable2=1 if year==2004 & (grade_num==8 | grade_num==10)   // YEAR HARDCODE
replace usable2=1 if year==2005 & (grade_num==8 | grade_num==10)   // YEAR HARDCODE
replace usable2=1 if year==2006 & (grade_num>=5 & grade_num<=11)   // YEAR HARDCODE
replace usable2=1 if year==2007 & (grade_num>=6 & grade_num<=11)   // YEAR HARDCODE
replace usable2=1 if year==2008 & (grade_num>=7 & grade_num<=11)   // YEAR HARDCODE
replace usable2=1 if year==2009 & (grade_num>=8 & grade_num<=11)   // YEAR HARDCODE


* usable 3 is based off Scott's email summarizing where the data should be available

gen byte usable3=0
replace usable3=1 if year==2006 & (grade_num==3)   // YEAR HARDCODE
replace usable3=1 if (grade_num==4)
replace usable3=1 if year>=2006 & (grade_num==5)   // YEAR HARDCODE
replace usable3=1 if year>=2006 & (grade_num==6)   // YEAR HARDCODE
replace usable3=1 if year>=2006 & (grade_num==7)   // YEAR HARDCODE
replace usable3=1 if (grade_num==8)
replace usable3=1 if year>=2006 & (grade_num==9)   // YEAR HARDCODE
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
* ==== QUARTILE / monotonicity-boutique peer-effect specs (baseline quartiles) ====
* Within each own-ability quartile (mathQD*/elaQD*), regress score on evacuee
* peer share by evacuee quartile (Kfraction_*Q1G..Q4G) -- tests monotonicity vs.
* boutique/invidious-comparison structures. (Exploratory; the canonical versions
* live in the quartile_analysis / katrina_by_quartiles drivers.)
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









































* NOTE: endsas; halts execution here (SAS-style marker). Everything below is
* exploratory / scratch / alternative-specification code that is NOT run as part
* of the main table production.
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


areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & usable2==1, fe cluster(sitecode)


areg mathSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5 & usable2==1, fe cluster(sitecode)

areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num<=5 & usable2==1, fe cluster(sitecode)


areg elaSTD percent_katrinaTIMESERIESG free_lunchA male black hisp asian gryr* if katrina_sum!=1 & katrina_district2==0  & percent_katrina<.7 & grade_num>5 & usable2==1, fe cluster(sitecode)



******************************************
** switchers means table and regression ***
*****************************************

table year katrina_sum, c(mean switch n switch)

******************************
**run switching regression for years post-hurricane and for grades 4,5, 7,8, 10,11 ****
**********************************
* (Post-endsas scratch: school-switching robustness; year>2005 = post-hurricane.)
* elementary
areg switch percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryr* if katrina_district2==0   & percent_katrina<.3 & grade_num<=5 & grade_num>=4 & year>2005 & katrina_sum!=1, absorb(sitecode) cluster(sitecode)   // YEAR HARDCODE: post-hurricane only


* middle
areg switch percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008  if katrina_district2==0   & percent_katrina<.3 & grade_num<=8 & grade_num>=7 & year>2005 & katrina_sum!=1, absorb(sitecode) cluster(sitecode)   // YEAR HARDCODE: gryr 2005-2008 dummies; post-hurricane only


* high
areg switch percent_katrinaTIMESERIES2 free_lunchA male black hisp asian gryrgrade_4- gryrgrade_10  gryryear_2005- gryryear_2008 gryrgraXyea_4_2005- gryrgraXyea_10_2008 if katrina_district2==0   & percent_katrina<.3 & grade_num<=11 & grade_num>=10 & year>2005 & katrina_sum!=1, absorb(sitecode) cluster(sitecode)   // YEAR HARDCODE: gryr 2005-2008 dummies; post-hurricane only











* NOTE: second endsas; -- everything below is additional exploratory/scratch
* code (fully-interacted quartile specs, race x quartile, cross-school no-FE
* versions, end-of-file balance regs). Several blocks below condition on
* year>2005 (post-hurricane) or year==2006; YEAR HARDCODEs throughout, not run.
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


areg math0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year==2006, cluster(sitecode) absorb(sitecode)

areg math0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year==2006, cluster(sitecode) absorb(sitecode)

areg math0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & year==2006, cluster(sitecode) absorb(sitecode)



areg ela0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num<=5 & year==2006, cluster(sitecode) absorb(sitecode)


areg ela0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & grade_num>5 & year==2006, cluster(sitecode) absorb(sitecode)


areg ela0005 katrina_sum free_lunchA male black asian hisp gryr* if katrina_district2==0 & percent_katrina<.3 & year==2006, cluster(sitecode) absorb(sitecode)

