*===============================================================================
* FILE:     quartile_analysis_revision_full_b_tests.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Louisiana peer-effect model tests, WITH Bonferroni)
* PRODUCES: Formal tests of competing peer-effect models for Louisiana
*           (monotonicity / invidious comparison / boutique-ability-grouping /
*           Duflo-et-al. bad-apple propositions), Bonferroni-corrected variant.
*
* PURPOSE:  Identical to quartile_analysis_revision_full_b_tests_nobon.do EXCEPT
*           the joint Wald `test ..., mtest(b)` commands apply a Bonferroni
*           multiplicity correction. After estimating by-quartile peer-effects
*           regressions for the four native baseline-achievement quartiles, the
*           models are stacked in a SUR (suest) system and tested against each
*           theoretical peer-effects model. The "nobon" sister file reports the
*           uncorrected numbers used in Table 8 / Appendix Table 20.
*
* INPUTS:   la_prepped_revisionFULL_SAMPLE.dta  (main LA student-year panel)
*           alternative_standardization.dta     (statewide-standardized scores: *STD)
*           discipline_prepped_microdata.dta    (discipline records)
*           tanumbers06-09_prepped2.dta         (test-administrator / class IDs)
* OUTPUTS:  No saved dataset; the suest + test (Bonferroni) results are printed to
*           the log.
*
* KEY STEPS:
*   - Same data-prep backbone as the other LA quartile files (load FULL_SAMPLE,
*     merge standardized/discipline/TA data, build baseline quartiles, restrict
*     grades/years, define lag sample, redefine percent-Katrina incl. Rita +
*     Cameron/Calcasieu, build Kfraction_*Q*G school*grade*year evacuee shares).
*   - Keep natives only; LIMIT to lag sample.
*   - Per native quartile 1-4, run math & ELA regressions and estimates store.
*   - suest the four models (clustered by school) for math, then ELA.
*   - Run the model-test battery with mtest(b) (Bonferroni).
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
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
***CONDUCTS VARIOUS TESTS USING AN SUR MODEL ACROSS ALL QUARTILES***


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
set matsize 8000
capture log close

set seed 10563

*cd "D:\School\Katrina\LA DOE\Revision"   // PATH: repoint to your local globals (commented Windows path)
*log using la_log2_quartiles, text replace

* 6.14 try another run in which I use the true lag rather than capping at 2005
set more off

* ---- Load main LA student-year panel ----
cd /work/i/imberman/imberman/la_data   // PATH: repoint to your local globals

use la_prepped_revisionFULL_SAMPLE.dta


drop  gender district_name school_name birth_month birth_day birth_year ela_raw math_raw sci_raw sci_scale scienceachievement soc_raw soc_scale ethnicity00_03 special_ed spec_ed2 school_type home_school ela_numcorrect sci_numcorrect ela_test_status math_test_status sci_test_status soc_test_status ela_achieve math_achieve social_achieve mathMEAN mathSD elaMEAN elaSD neworleans_returning_school neworleans_evacueedistrict new_orleans_area


* ---- Merge in statewide-standardized scores (score standardization: *STD vars) ----
*MERGE IN ALTERNATIVELY STANDARDIZED ACHIEVEMENT DATA
drop *STD *_lag *_lagyear *0005 math200* ela200*
sort id year
merge id year using alternative_standardization.dta
drop _merge

* ---- BASELINE ACHIEVEMENT QUARTILES: within-grade*year quartiles of math0005/ela0005 ----
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

keep if year >= 2000 & year <= 2007   // YEAR HARDCODE: analysis window 2000-2007
keep if grade_num >= 4 & grade_num <= 10
drop if year == 2006 & grade_num == 4   // YEAR HARDCODE: grade 4 not tested in 2006
drop if year == 2007 & grade_num == 4   // YEAR HARDCODE: grade 4 not tested in 2007
drop if year == 2007 & grade_num == 5   // YEAR HARDCODE: grade 5 not tested in 2007


* ---- Identify the lag sample (grades/years where a lagged score is available) ----
*IDENTIFY THE LAG SAMPLE
gen lagsample = 0
replace lagsample = 1 if year > 2001 & grade_num == 10   // YEAR HARDCODE: g10 lag from 2002
replace lagsample = 1 if year > 2003 & grade_num == 8     // YEAR HARDCODE: g8 lag from 2004
replace lagsample = 1 if year > 2005 & (grade_num == 6 | grade_num == 7 | grade_num == 9)   // YEAR HARDCODE: g6/7/9 from 2006



summ mathSTD elaSTD

tab year
*********************************************************************
* drop all the old grade year interactions and use gradenum instead
*********************************************************************
 
*sample 3

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


***********************************
* merge in the discipline data
***********************************
* ---- Merge in discipline microdata ----
capture drop _m
sort id year

merge id year, using discipline_prepped_microdata

tab _m

drop if _m==2


***********************************
* merge in the test administrator data
***********************************
* ---- Merge in test-administrator numbers (used to define classes) ----
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
*      never in a Katrina/Rita district coded 0; Rita kids = evacuees; 0 pre-treatment. ----
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

* ---- Bad-apple measure: peer share of evacuees with a 2005 discipline record ----
gen discipline05a=discipline_any if year==2005   // YEAR HARDCODE: baseline discipline measured in 2005

egen discipline05=max(discipline05a), by(id)

egen percent_katrinaDISCIPLINE2=mean(katrina_sum*discipline05), by(district_code school_code year)
replace percent_katrinaDISCIPLINE2=0 if year<=2005   // YEAR HARDCODE: 0 evacuees pre-2005-06


* count the number of katrina kids in my class
egen count_katrinaDISCIPLINE_class=sum(katrina_sum*discipline05), by(class)
replace count_katrinaDISCIPLINE_class=. if sitecode==. | elamth==.

egen count_katrina_class=sum(katrina_sum), by(class)
replace count_katrina_class=. if sitecode==. | elamth==.






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

replace math_lagyear = . if year > 2005   // YEAR HARDCODE: recompute lag-year only post-Katrina
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



**************
** Overall Table ***
**************

* ---- Restrict to lag sample (middle/high grades with lagged dependent variable) ----
*LIMIT TO LAG SAMPLE
keep if lagsample == 1

* ---- School FE as explicit dummies (suest cannot use areg's absorbed FE) ----
**SUR CANNOT BE DONE WITH AREG SO NEED TO USE DUMMY VARIABLES
xi i.sitecode

* ---- Per-quartile regressions, stored for the SUR system (math`q', ela`q') ----
****************************
** BY NATIVE LAGGED SCORE QUARTILE**
****************************


forvalues quart = 1/4 {

di ""
di "****************"
di "QUARTILE `quart'"
di "****************"
di ""


*LAG SAMPLE (WITH LAGS - 2002 & LATER, MIDHIGH ONLY)


reg mathSTD math_lag_* Kfraction_mathQ1G Kfraction_mathQ2G Kfraction_mathQ3G Kfraction_mathQ4G free_lunchA male black hisp asian gryr* _I* if mathQD`quart' == 1
estimates store math`quart'


reg elaSTD ela_lag_* Kfraction_elaQ1G Kfraction_elaQ2G Kfraction_elaQ3G Kfraction_elaQ4G free_lunchA male black hisp asian gryr* _I* if elaQD`quart' == 1
estimates store ela`quart'

}

  # delimit ;

* ---- MATH: stack the four quartile models in a SUR system, cluster by school ----
*      All `test ..., mtest(b)` blocks below are the BONFERRONI-corrected model tests.
*MATH TESTS;
suest math1 math2 math3 math4, vce(cluster sitecode);




  * ---- TEST: all 16 evacuee-quartile coefficients, Bonferroni-corrected (MATH) ----
  *DO BONFERRINI CORRECTIONS FOR ALL SINGLE COEFFICIENT ESTIMATES;
  test 	[math1_mean]Kfraction_mathQ1G [math1_mean]Kfraction_mathQ2G [math1_mean]Kfraction_mathQ3G [math1_mean]Kfraction_mathQ4G
	[math2_mean]Kfraction_mathQ1G [math2_mean]Kfraction_mathQ2G [math2_mean]Kfraction_mathQ3G [math2_mean]Kfraction_mathQ4G
	[math3_mean]Kfraction_mathQ1G [math3_mean]Kfraction_mathQ2G [math3_mean]Kfraction_mathQ3G [math3_mean]Kfraction_mathQ4G
	[math4_mean]Kfraction_mathQ1G [math4_mean]Kfraction_mathQ2G [math4_mean]Kfraction_mathQ3G [math4_mean]Kfraction_mathQ4G
	, mtest(b);

  * ---- TEST: WEAK MONOTONICITY (MATH), Bonferroni -- Q1 share = Q4 share per quartile ----
  *WEAK MONOTONICITY ;
  test 	([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ4G)  
	([math2_mean]Kfraction_mathQ1G = [math2_mean]Kfraction_mathQ4G)	/*FOR MONOTONICITY THESE SHOUDL BE POSITIVE */
	([math3_mean]Kfraction_mathQ1G = [math3_mean]Kfraction_mathQ4G)
	([math4_mean]Kfraction_mathQ1G = [math4_mean]Kfraction_mathQ4G)
	, mtest(b);




  * ---- TEST: STRONG MONOTONICITY 1 (MATH), Bonferroni -- adjacent-quartile equality ----
  *STRONG MONOTONICITY 1;
  test 	([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ2G)	/*FOR MONOTONICITY THESE SHOULD BE POSITIVE */
	([math1_mean]Kfraction_mathQ2G = [math1_mean]Kfraction_mathQ3G)
	([math1_mean]Kfraction_mathQ3G = [math1_mean]Kfraction_mathQ4G)
	([math2_mean]Kfraction_mathQ1G = [math2_mean]Kfraction_mathQ2G)  
	([math2_mean]Kfraction_mathQ2G = [math2_mean]Kfraction_mathQ3G)
	([math2_mean]Kfraction_mathQ3G = [math2_mean]Kfraction_mathQ4G)
	([math3_mean]Kfraction_mathQ1G = [math3_mean]Kfraction_mathQ2G)  
	([math3_mean]Kfraction_mathQ2G = [math3_mean]Kfraction_mathQ3G)
	([math3_mean]Kfraction_mathQ3G = [math3_mean]Kfraction_mathQ4G)
	([math4_mean]Kfraction_mathQ1G = [math4_mean]Kfraction_mathQ2G)  
	([math4_mean]Kfraction_mathQ2G = [math4_mean]Kfraction_mathQ3G)
	([math4_mean]Kfraction_mathQ3G = [math4_mean]Kfraction_mathQ4G)
	, mtest(b);


  * ---- TEST: STRONG MONOTONICITY 2 (MATH) -- all four shares equal, per native quartile ----
  *STRONG MONOTONICITY 2;
  test 	([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ2G = [math1_mean]Kfraction_mathQ3G = [math1_mean]Kfraction_mathQ4G);
  test	([math2_mean]Kfraction_mathQ1G = [math2_mean]Kfraction_mathQ2G = [math2_mean]Kfraction_mathQ3G = [math2_mean]Kfraction_mathQ4G);
  test	([math3_mean]Kfraction_mathQ1G = [math3_mean]Kfraction_mathQ2G = [math3_mean]Kfraction_mathQ3G = [math3_mean]Kfraction_mathQ4G);
  test	([math4_mean]Kfraction_mathQ1G = [math4_mean]Kfraction_mathQ2G = [math4_mean]Kfraction_mathQ3G = [math4_mean]Kfraction_mathQ4G);



  * ---- TEST: INVIDIOUS COMPARISON (MATH), Bonferroni -- higher peers hurt, lower help ----
  *INVIDIOUS COMPARISON - HIGHER ACHIEVERS WORSE FOR YOU & LOWER ACHIEVERS BETTER FOR YOU;

  test 	 [math1_mean]Kfraction_mathQ2G  /* THESE SHOULD BE POSITIVE FOR IC */
	 [math1_mean]Kfraction_mathQ3G  
	 [math1_mean]Kfraction_mathQ4G
	 [math2_mean]Kfraction_mathQ3G
	 [math2_mean]Kfraction_mathQ4G
	 [math3_mean]Kfraction_mathQ4G
	 [math2_mean]Kfraction_mathQ1G	/* THESE SHOULD BE NEGATIVE FOR IC */
	 [math3_mean]Kfraction_mathQ1G
	 [math3_mean]Kfraction_mathQ2G
	 [math4_mean]Kfraction_mathQ1G
	 [math4_mean]Kfraction_mathQ2G
	 [math4_mean]Kfraction_mathQ3G
	, mtest(b);

  * ---- TEST: ABILITY GROUPING / BOUTIQUE (MATH), Bonferroni -- own quartile beats higher ----
  *ABILITY GROUPING (BOUTIQUE/TRACKING) - YOUR OWN QUARTILE BEATS HIGHER QUARTILES;
  test 	([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ2G) /* THESE SHOULD BE POSITIVE FOR AG */
 	([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ3G)
	([math1_mean]Kfraction_mathQ1G = [math1_mean]Kfraction_mathQ4G)
	([math2_mean]Kfraction_mathQ2G = [math2_mean]Kfraction_mathQ3G)
	([math2_mean]Kfraction_mathQ2G = [math2_mean]Kfraction_mathQ4G)
	([math3_mean]Kfraction_mathQ3G = [math3_mean]Kfraction_mathQ4G)
	, mtest(b);

   * ---- TEST: DUFLO ET AL. PROP 1 (MATH), Bonferroni -- own-quartile effect flips at median ----
   *DUFLO, ET. AL.  --> PROP 1 - TEST IF BELOW MEDIAN NATIVES HAVE NEGATIVE IMPACTS FROM BEING COMBINED W/ OWN QUARTILE WHILE ABOVE MEDIAN;
   *HAVE POSITIVE IMPACTS FROM BEING COMBINED W/ OWN QUARTILE;
   test [math1_mean]Kfraction_mathQ1G
	[math2_mean]Kfraction_mathQ2G 
	[math3_mean]Kfraction_mathQ3G
	[math4_mean]Kfraction_mathQ4G
	, mtest(b);


   *DUFLO, ET. AL. --> PROP 3 - 
	f() INCREASING IN PEER ACHIEVEMENT IF (Q_NATIVE_KAT), Q4G4 > 0, Q14 > 0, & Q4G4 > Q14 AND Q11 < 0, Q4G1 < 0, & Q11 > Q4G1
		NULL IS THAT f() INCREASING
		REJECT NULL IF
			Q4G4 < 0
			Q14 < 0
			Q11 > 0
			Q4G1 > 0
			Q4G4 < Q14 or
			Q11 < Q4G1
	NOTE THAT THIS IS A STRONGER TEST THAN DUFLO ET. AL. MIGHT SUGGEST AS IN THIER CONTEXT REJECT IF Q4G4 <= Q4G1 OR Q11 <= Q14;

   * ---- TEST: DUFLO ET AL. PROP 3 (MATH) -- f() monotone increasing in peer achievement ----
   test ([math4_mean]Kfraction_mathQ4G)	/*  NEGATIVE = REJECT */
 	([math1_mean]Kfraction_mathQ4G)
	([math4_mean]Kfraction_mathQ1G)	/* POSITIVE = REJECT */
	([math1_mean]Kfraction_mathQ1G)
	([math4_mean]Kfraction_mathQ4G = [math1_mean]Kfraction_mathQ4G) /* NEGATIVE = REJECT */
	([math1_mean]Kfraction_mathQ1G = [math4_mean]Kfraction_mathQ1G)
	, mtest(b);

	*IF f() CONSTANT THEN INCREASE (DECREASE) IN PEER SCORES
		(1) INCREASE (DECREASE) ACHIEVEMENT IN ABOVE MEDIAN
		(2) DECREASE (INCREASE) ACHIEVEMENT JUST BELOW MEDIAN
		(3) NO EFFECT FAR BELOW MEDIAN
		HENCE REJECT IF

			Q4G4 < 0		(1)
			Q3G4 < 0
			Q4G1 > 0
			Q3G1 > 0
			
	 		Q2G4 > 0		(2)
			Q2G1 < 0

			Q14 > 0		(3)
		OR	Q14 < 0	
	;

  * ---- TEST: DUFLO ET AL. constant-f() implications (MATH) -- single-crossing pattern ----
  test 	[math4_mean]Kfraction_mathQ4G	/* NEGATIVE = REJECT */
	[math3_mean]Kfraction_mathQ4G
	[math2_mean]Kfraction_mathQ1G

	[math4_mean]Kfraction_mathQ1G	/* POSITIVE = REJECT */
	[math3_mean]Kfraction_mathQ1G
	[math2_mean]Kfraction_mathQ4G

	[math1_mean]Kfraction_mathQ4G	/* REJECT IF NOT = 0 */
	, mtest(b);



* ---- ELA: same SUR + Bonferroni-corrected test battery as MATH above (ELA panel) ----
*ELA TESTS;
suest ela1 ela2 ela3 ela4, vce(cluster sitecode);


  *DO BONFERRINI CORRECTIONS FOR ALL SINGLE COEFFICIENT ESTIMATES;
  test 	[ela1_mean]Kfraction_elaQ1G [ela1_mean]Kfraction_elaQ2G [ela1_mean]Kfraction_elaQ3G [ela1_mean]Kfraction_elaQ4G
	[ela2_mean]Kfraction_elaQ1G [ela2_mean]Kfraction_elaQ2G [ela2_mean]Kfraction_elaQ3G [ela2_mean]Kfraction_elaQ4G
	[ela3_mean]Kfraction_elaQ1G [ela3_mean]Kfraction_elaQ2G [ela3_mean]Kfraction_elaQ3G [ela3_mean]Kfraction_elaQ4G
	[ela4_mean]Kfraction_elaQ1G [ela4_mean]Kfraction_elaQ2G [ela4_mean]Kfraction_elaQ3G [ela4_mean]Kfraction_elaQ4G 
	, mtest(b);

  *WEAK MONOTONICITY;
  test 	([ela1_mean]Kfraction_elaQ1G = [ela1_mean]Kfraction_elaQ4G)  
	([ela2_mean]Kfraction_elaQ1G = [ela2_mean]Kfraction_elaQ4G)	/*FOR MONOTONICITY THESE SHOULD BE POSITIVE */
	([ela3_mean]Kfraction_elaQ1G = [ela3_mean]Kfraction_elaQ4G)
	([ela4_mean]Kfraction_elaQ1G = [ela4_mean]Kfraction_elaQ4G)
	, mtest(b);


  *STRONG MONOTONICITY 1;
  test 	([ela1_mean]Kfraction_elaQ1G = [ela1_mean]Kfraction_elaQ2G)	/*FOR MONOTONICITY THESE SHOULD BE POSITIVE */  
	([ela1_mean]Kfraction_elaQ2G = [ela1_mean]Kfraction_elaQ3G)
	([ela1_mean]Kfraction_elaQ3G = [ela1_mean]Kfraction_elaQ4G)
	([ela2_mean]Kfraction_elaQ1G = [ela2_mean]Kfraction_elaQ2G)  
	([ela2_mean]Kfraction_elaQ2G = [ela2_mean]Kfraction_elaQ3G)
	([ela2_mean]Kfraction_elaQ3G = [ela2_mean]Kfraction_elaQ4G)
	([ela3_mean]Kfraction_elaQ1G = [ela3_mean]Kfraction_elaQ2G)  
	([ela3_mean]Kfraction_elaQ2G = [ela3_mean]Kfraction_elaQ3G)
	([ela3_mean]Kfraction_elaQ3G = [ela3_mean]Kfraction_elaQ4G)
	([ela4_mean]Kfraction_elaQ1G = [ela4_mean]Kfraction_elaQ2G)  
	([ela4_mean]Kfraction_elaQ2G = [ela4_mean]Kfraction_elaQ3G)
	([ela4_mean]Kfraction_elaQ3G = [ela4_mean]Kfraction_elaQ4G)
	, mtest(b);



  *STRONG MONOTONICITY 2;
  test 	([ela1_mean]Kfraction_elaQ1G = [ela1_mean]Kfraction_elaQ2G = [ela1_mean]Kfraction_elaQ3G = [ela1_mean]Kfraction_elaQ4G);
  test	([ela2_mean]Kfraction_elaQ1G = [ela2_mean]Kfraction_elaQ2G = [ela2_mean]Kfraction_elaQ3G = [ela2_mean]Kfraction_elaQ4G);
  test	([ela3_mean]Kfraction_elaQ1G = [ela3_mean]Kfraction_elaQ2G = [ela3_mean]Kfraction_elaQ3G = [ela3_mean]Kfraction_elaQ4G);
  test	([ela4_mean]Kfraction_elaQ1G = [ela4_mean]Kfraction_elaQ2G = [ela4_mean]Kfraction_elaQ3G = [ela4_mean]Kfraction_elaQ4G);


  *INVIDIOUS COMPARISON - HIGHER ACHIEVERS WORSE FOR YOU & LOWER ACHIEVERS BETTER FOR YOU;
  test 	 [ela1_mean]Kfraction_elaQ2G  /* THESE SHOULD BE POSITIVE FOR IC */
	 [ela1_mean]Kfraction_elaQ3G  
	 [ela1_mean]Kfraction_elaQ4G
	 [ela2_mean]Kfraction_elaQ3G
	 [ela2_mean]Kfraction_elaQ4G
	 [ela3_mean]Kfraction_elaQ4G
	 [ela2_mean]Kfraction_elaQ1G	/* THESE SHOULD BE NEGATIVE FOR IC */
	 [ela3_mean]Kfraction_elaQ1G
	 [ela3_mean]Kfraction_elaQ2G
	 [ela4_mean]Kfraction_elaQ1G
	 [ela4_mean]Kfraction_elaQ2G
	 [ela4_mean]Kfraction_elaQ3G
	, mtest(b);

  *ABILITY GROUPING (BOUTIQUE/TRACKING) - YOUR OWN QUARTILE BEATS HIGHER QUARTILES;
  test 	([ela1_mean]Kfraction_elaQ1G = [ela1_mean]Kfraction_elaQ2G) /* THESE SHOULD BE POSITIVE FOR AG */
 	([ela1_mean]Kfraction_elaQ1G = [ela1_mean]Kfraction_elaQ3G)
	([ela1_mean]Kfraction_elaQ1G = [ela1_mean]Kfraction_elaQ4G)
	([ela2_mean]Kfraction_elaQ2G = [ela2_mean]Kfraction_elaQ3G)
	([ela2_mean]Kfraction_elaQ2G = [ela2_mean]Kfraction_elaQ4G)
	([ela3_mean]Kfraction_elaQ3G = [ela3_mean]Kfraction_elaQ4G)
	, mtest(b);

   *DUFLO, ET. AL.  --> PROP 1 - TEST IF BELOW MEDIAN NATIVES HAVE NEGATIVE IMPACTS FROM BEING COMBINED W/ OWN QUARTILE WHILE ABOVE MEDIAN;
   *HAVE POSITIVE IMPACTS FROM BEING COMBINED W/ OWN QUARTILE;
   test [ela1_mean]Kfraction_elaQ1G 
	[ela2_mean]Kfraction_elaQ2G 
	[ela3_mean]Kfraction_elaQ3G
	[ela4_mean]Kfraction_elaQ4G
	, mtest(b);



   *DUFLO, ET. AL. --> PROP 3 - 
	f() INCREASING IN PEER ACHIEVEMENT IF (Q_NATIVE_KAT), Q4G4 > 0, Q14 > 0, & Q4G4 > Q14 AND Q11 < 0, Q4G1 < 0, & Q11 > Q4G1
		NULL IS THAT f() INCREASING
		REJECT NULL IF
			Q4G4 < 0
			Q14 < 0
			Q11 > 0
			Q4G1 > 0
			Q4G4 < Q14 or
			Q11 < Q4G1
	NOTE THAT THIS IS A STRONGER TEST THAN DUFLO ET. AL. MIGHT SUGGEST AS IN THIER CONTEXT REJECT IF Q4G4 <= Q4G1 OR Q11 <= Q14;

   test ([ela4_mean]Kfraction_elaQ4G)	/*  CONSISTENT - POSITIVE */
 	([ela1_mean]Kfraction_elaQ4G)

	([ela4_mean]Kfraction_elaQ1G)	/* CONSISTENT - NEGATIVE */
	([ela1_mean]Kfraction_elaQ1G)

	([ela4_mean]Kfraction_elaQ4G = [ela1_mean]Kfraction_elaQ4G) /* CONSISTENT - POSITIVE*/
	([ela1_mean]Kfraction_elaQ1G = [ela4_mean]Kfraction_elaQ1G)
	, mtest(b);

	*IF f() CONSTANT THEN INCREASE (DECREASE) IN PEER SCORES
		(1) INCREASE (DECREASE) ACHIEVEMENT IN ABOVE MEDIAN
		(2) DECREASE (INCREASE) ACHIEVEMENT JUST BELOW MEDIAN
		(3) NO EFFECT FAR BELOW MEDIAN
		HENCE REJECT IF

			Q4G4 < 0		(1)
			Q34 < 0
			Q4G1 > 0
			Q31 > 0
			
	 		Q24 > 0		(2)
			Q21 < 0

			Q14 > 0		(3)
		OR	Q14 < 0	
	;

  test 	[ela4_mean]Kfraction_elaQ4G	/* CONSISTENT - POSITIVE */
	[ela3_mean]Kfraction_elaQ4G
	[ela2_mean]Kfraction_elaQ1G

	[ela4_mean]Kfraction_elaQ1G	/* CONSISTENT - NEGATIVE */
	[ela3_mean]Kfraction_elaQ1G
	[ela2_mean]Kfraction_elaQ4G

	[ela1_mean]Kfraction_elaQ4G	/* CONSISTENT = 0 */
	, mtest(b);


