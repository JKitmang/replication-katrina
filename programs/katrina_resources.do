*===============================================================================
* FILE:     katrina_resources.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston school-resources mechanism test)
* PRODUCES: App Table 45 (Houston school resources vs. evacuee share);
*           writes resources_pooled.xls and resources_bygrade.xls via outreg2.
*
* PURPOSE:  Tests whether the influx of Katrina evacuees changed Houston (HISD)
*           schools' RESOURCES — class size, per-pupil expenditure, student/teacher
*           ratio, teacher experience/certification — which could be a channel for
*           peer effects. Uses TEA campus-level data, merges in the evacuee
*           fraction computed from individual data, and regresses each resource
*           outcome on the evacuee share with campus FE, demographic and grade-share
*           controls (grade share x year), pooled and by grade level (elem/midsec),
*           also splitting the evacuee share above/below test-score medians.
*
* INPUTS:   C:\D\Research\Charter\Texas School Data\schools.dta   (TEA campus data)
*           C:\katrina\katrina_by_school.dta                       (evacuee counts/shares)
*           teacher_summary.dta                                    (teacher data)
*           C:\katrina\avg_stanford.dta                            (above/below-median quartile data)
* OUTPUTS:  resources_pooled.xls / resources_bygrade.xls           (regression output)
*
* KEY STEPS:
*   - Limit to HISD, 2003-2006; build change_enroll_01_04 (2003->2005 enrollment change).
*   - Merge evacuee share (0 before 2005), teacher data, and median-split quartile data.
*   - Build elem/midsec flags and enrollment-weighted average class sizes.
*   - Interact each grade's enrollment share with year dummies.
*   - Regress class size / expenditure / staffing on evacuee share (pooled & by grade).
*   - Repeat using evacuee share split above/below math & reading medians.
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - Absolute paths: C:\katrina\..., C:\D\Research\Charter\... (see PATH flags below).
*   - `if year == 2005` for the 2003->2005 enrollment-change variable.
*   - `keep if year >= 2003` and `keep if year <= 2006` analysis window.
*   - `replace `var' = 0 if year < 2005` evacuee share = 0 pre-Katrina.
*   - `replace campus = campus - 101912000` HISD district-code offset.
*   - `if year >= 2004` combines instruction & instructional-leadership expenditure.
*   - No Sept-13 instrument in this resources file (reduced-form share only).
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
* ---- Setup ----
clear
set mem 800m
set more off

log using "C:\katrina\katrina_resources.log", replace   // PATH: repoint to your local globals

* ---- Load TEA campus data; limit to HISD and 2003-2006 ----
use "C:\D\Research\Charter\Texas School Data\schools.dta", clear   // PATH: repoint to your local globals

*LIMIT TO HISD & 2003-04 - 2005-06
keep if distname == "HOUSTON ISD"
destring year, replace
xtset campus year
gen change_enroll_01_04 = l1.enroll - l2.enroll if year == 2005   // YEAR HARDCODE: 2003->2005 enrollment change, evaluated in 2005
keep if year >= 2003   // YEAR HARDCODE: first analysis year
replace campus = campus - 101912000   // strip HISD district-code prefix to match individual data
sort campus year
drop teacher_exp

* ---- Merge evacuee share from individual data (0 before Katrina) ----
*MERGE WITH KATRINA FRACTION CALCUATED FROM INDIVIDUAL DATA
merge campus year using "C:\katrina\katrina_by_school.dta", nokeep keep (katrina_count_campus katrina_frac_campus)   // PATH: repoint to your local globals
foreach var of varlist katrina_count_campus katrina_frac_campus {
	replace `var' = 0 if year < 2005   // YEAR HARDCODE: evacuee share = 0 for all pre-Katrina years (<2005)
}

  *NOTE THAT SCHOOL #69 SHOWS UP IN 2005 IN INDIVIDUAL DATA BUT NOT IN SCHOOL LEVEL DATA

* ---- Merge in teacher data ----
*MERGE IN TEACHER DATA
drop _merge
sort campus year
merge campus year using "C:\D\Research\Charter\Houston\HISDdata\DataFiles\Teachers\teacher_summary.dta"   // PATH: repoint to your local globals

* ---- BASELINE ACHIEVEMENT QUARTILES: merge above/below-median evacuee shares ----
*MERGE IN QUARTILE DATA
drop _merge
sort campus year
merge campus year using "C:\katrina\avg_stanford.dta", nokeep _merge(_merge2)   // PATH: repoint to your local globals
tab _merge2


* ---- Flag elementary (grades 1-5) and mid/secondary (grades 6-12) schools ----
*IDENTIFY SCHOOLS WITH ANY GRADE 1-5 TO MATCH UP TO INDIVIDUAL DATA
gen elem = 0
foreach grade in "01" "02" "03" "04" "05" {
  replace elem = 1 if enroll_`grade'_count > 0 & enroll_`grade'_count != .
}

*IDENTIFY SCHOOLS WITH ANY GRADE 6-10 TO MATCH UP TO INDIVIDUAL DATA
gen midsec = 0
foreach grade in "06" "07" "08" "09" "10" "11" "12" {
  replace midsec = 1 if enroll_`grade'_count > 0 & enroll_`grade'_count != .
}

* ---- Build enrollment-weighted average class sizes ----
*GENEARTE AVERAGE CLASS SIZE
gen class_size_kg_weight = class_size_kg*enroll_kn_count if elem == 1
replace class_size_kg_weight = 0 if class_size_kg == . & elem == 1

gen class_size_1_weight = class_size_1*enroll_01_count if elem == 1
replace class_size_1_weight = 0 if class_size_1 == . & elem == 1

gen class_size_2_weight = class_size_2*enroll_02_count if elem == 1
replace class_size_2_weight = 0 if class_size_2 == . & elem == 1

gen class_size_3_weight = class_size_3*enroll_03_count if elem == 1
replace class_size_3_weight = 0 if class_size_3 == . & elem == 1

gen class_size_4_weight = class_size_4*enroll_04_count if elem == 1
replace class_size_4_weight = 0 if class_size_4 == . & elem == 1

gen class_size_5_weight = class_size_5*enroll_05_count if elem == 1
replace class_size_5_weight = 0 if class_size_5 == . & elem == 1

keep if year <= 2006   // YEAR HARDCODE: last analysis year (2005-06)

# delimit ;


gen class_size_elem = (class_size_kg_weight + class_size_1_weight + class_size_2_weight + class_size_3_weight
				 + class_size_4_weight + class_size_5_weight)/
				(enroll_kn_count + enroll_01_count + enroll_02_count + enroll_03_count + enroll_04_count + enroll_05_count)
				if exp_func_pupil_totoper != .;
# delimit cr
gen class_size_midhigh = (class_size_sec_math + class_size_sec_engl)/2

*DROP SCHOOLS THAT ARE ONLY KG & BELOW
drop if elem == 0 & midsec == 0

* ---- Interact each grade's enrollment share with year dummies (controls) ----
*INTERACT % IN EACH GRADE WITH YEAR
# delimit;
xi i.year*enroll_ee_perc i.year*enroll_pk_perc i.year*enroll_kn_perc i.year*enroll_01_perc i.year*enroll_02_perc i.year*enroll_03_perc i.year*enroll_04_perc i.year*enroll_05_perc i.year*enroll_06_perc
	i.year*enroll_07_perc i.year*enroll_08_perc i.year*enroll_09_perc i.year*enroll_10_perc i.year*enroll_11_perc i.year*enroll_12_perc;

*CLEAN OUTCOME VARIABLES;
  foreach outcome of varlist exp* class* stratio {;
    replace `outcome' = . if `outcome' < 0;
  };

cd c:\katrina;   // PATH: repoint to your local globals
capture erase resources_pooled.txt;
capture erase resources_pooled.xml;
capture erase resources_bygrade.txt;
capture erase resources_bygrade.xml;



* ---- Combine instruction & instructional-leadership expenditure (2004+) ----
*COMBINE INSTRUCTION & INSTRUCTIONAL LEADERSHIP AS THESE WERE ONLY SEPARATED IN 2004 AND LATER;
replace exp_func_pupil_instr_instrld = exp_func_pupil_instr + exp_func_pupil_instrlead if year >= 2004;   // YEAR HARDCODE: these categories only split out from 2004 on


* ---- Enrollment change vs. evacuee share (reduced-form check) ----
*LOOK AT CORRELATION B/W CHANGE IN ENROLLMENT AND EVACUEE SHARE;
reg change_enroll katrina_frac_campus enroll_black_perc enroll_hisp_perc enroll_asian_perc enroll_ind_perc enroll_econ_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc;

f;

/*
*KATRINA COUNT;



*REGRESS CERTAIN RESOURCE DATA ON KATRINA FRACTION CONTROLLING FOR SCHOOL FE'S, 
	%WHITE, %BLACK, %HISP, %ASIAN, %NATIVE AMERICAN, %ECON DISADVANTAGED, AND % IN EACH GRADE INTERACTED W/ YEAR;

  *POOLED;
  foreach outcome of varlist class_size* exp_func_pupil_totoper exp_func_pupil_instr_instrld stratio teacher_exp teacher_cert teacher_graduate {;
  	areg `outcome' katrina_count_campus enroll_black_perc enroll_hisp_perc enroll_asian_perc enroll_ind_perc enroll_econ_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc 
		_I*, absorb(campus) cluster(campus);
	outreg2 using resources_pooled, keep(katrina_count_campus) excel bdec(3) nocons;
  };


  *BY GRADE LEVEL;
# delimit;

  foreach gradelevel in "elem" "midsec" {;
    foreach outcome of varlist exp_func_pupil_totoper exp_func_pupil_instr_instrld stratio teacher_exp teacher_cert teacher_graduate {;
  	areg `outcome' katrina_count_campus enroll_black_perc enroll_hisp_perc enroll_asian_perc enroll_ind_perc enroll_econ_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc 
		_I* if `gradelevel' == 1, absorb(campus) cluster(campus);
	outreg2 using resources_bygrade, keep(katrina_count_campus) excel bdec(3) nocons;

    };
  };
*/

* ---- App Table 45 (1/2): resource outcomes on evacuee FRACTION ----
* Each areg writes one column to resources_pooled.xls / resources_bygrade.xls.
*KATRINA FRACTION;

*REGRESS CERTAIN RESOURCE DATA ON KATRINA FRACTION CONTROLLING FOR SCHOOL FE'S,
	%WHITE, %BLACK, %HISP, %ASIAN, %NATIVE AMERICAN, %ECON DISADVANTAGED, AND % IN EACH GRADE INTERACTED W/ YEAR;

  *POOLED;
  foreach outcome of varlist class_size* exp_func_pupil_totoper exp_func_pupil_instr_instrld stratio
		teacher_exp teacher_perc_0yr teacher_perc_1yr 	teacher_perc_6yr teacher_perc_11yr teacher_perc_21yr
		teacher_cert teacher_graduate {;
  	areg `outcome' katrina_frac_campus enroll_black_perc enroll_hisp_perc 
		enroll_asian_perc enroll_ind_perc enroll_econ_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc 
		_I*, absorb(campus) cluster(campus);
	outreg2 using resources_pooled, keep(katrina_frac_campus) excel bdec(2) nocons;
  };


  *BY GRADE LEVEL;
# delimit;

  foreach gradelevel in "elem" "midsec" {;
    foreach outcome of varlist exp_func_pupil_totoper exp_func_pupil_instr_instrld stratio teacher_exp teacher_perc_0yr teacher_perc_1yr 
		teacher_perc_6yr teacher_perc_11yr teacher_perc_21yr teacher_cert teacher_graduate {;
  	areg `outcome' katrina_frac_campus enroll_black_perc enroll_hisp_perc 
		enroll_asian_perc enroll_ind_perc enroll_econ_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc 
		_I* if `gradelevel' == 1, absorb(campus) cluster(campus);
	outreg2 using resources_bygrade, keep(katrina_frac_campus) excel bdec(2) nocons;

    };
  };

* ---- App Table 45 (2/2): resource outcomes on evacuee share split by median ----
*KATRINA FRACTION ABOVE AND BELOW MEDIANS;

*GENERATE AVERAGE OF KATRINA SHARE IN READING ABOVE/BELOW MEDIAN AND MATH ABOVE/BELOW MEDIAN;
egen katrina_frac_median_1 = rmean(katrina_frac_math_median_1 katrina_frac_read_median_1);   // baseline achievement: below-median evacuee share
egen katrina_frac_median_2 = rmean(katrina_frac_math_median_2 katrina_frac_read_median_2);   // baseline achievement: above-median evacuee share


*REGRESS CERTAIN RESOURCE DATA ON KATRINA FRACTION CONTROLLING FOR SCHOOL FE'S, 
	%WHITE, %BLACK, %HISP, %ASIAN, %NATIVE AMERICAN, %ECON DISADVANTAGED, AND % IN EACH GRADE INTERACTED W/ YEAR;

  *POOLED;
  foreach outcome of varlist class_size* exp_func_pupil_totoper exp_func_pupil_instr_instrld stratio 
		teacher_exp teacher_perc_0yr teacher_perc_1yr 	teacher_perc_6yr teacher_perc_11yr teacher_perc_21yr teacher_cert teacher_graduate {;
  	areg `outcome' katrina_frac_median_1 katrina_frac_median_2
		enroll_black_perc enroll_hisp_perc 
		enroll_asian_perc enroll_ind_perc enroll_econ_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc 
		_I*, absorb(campus) cluster(campus);
	outreg2 using resources_pooled, keep(katrina_frac_*) excel bdec(2) nocons;
  };


  *BY GRADE LEVEL;
# delimit;

  foreach gradelevel in "elem" "midsec" {;
    foreach outcome of varlist exp_func_pupil_totoper exp_func_pupil_instr_instrld stratio teacher_exp teacher_perc_0yr teacher_perc_1yr 
		teacher_perc_6yr teacher_perc_11yr teacher_perc_21yr teacher_cert teacher_graduate {;
  	areg `outcome' katrina_frac_median_1 katrina_frac_median_2
		enroll_black_perc enroll_hisp_perc 
		enroll_ee_perc enroll_pk_perc enroll_kn_perc enroll_01_perc enroll_02_perc enroll_03_perc enroll_04_perc enroll_05_perc 
		enroll_06_perc enroll_07_perc enroll_08_perc enroll_09_perc enroll_10_perc enroll_11_perc enroll_12_perc 
		_I* if `gradelevel' == 1, absorb(campus) cluster(campus);
	outreg2 using resources_bygrade, keep(katrina_frac_*) excel bdec(2) nocons;

    };
  };



log close;

