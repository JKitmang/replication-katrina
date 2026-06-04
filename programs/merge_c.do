*===============================================================================
* FILE:     merge_c.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Dataset construction (master Houston merge)
* PRODUCES: The master Houston analysis datasets used by essentially every
*           Houston table/appendix program: hisd_data.dta,
*           katrina_data_with_evacs.dta, katrina_data.dta, maxgrade.dta.
*
* PURPOSE:  Merges all cleaned Houston (HISD) component files - attendance,
*           demographics, Stanford/Aprenda/TAAS/TAKS exams, discipline, and
*           student-teacher links - into one student-year panel; standardizes
*           test scores; builds the regression dataset (evacuee shares at campus,
*           grade, and class level; by-gender, ethnicity, lunch shares; baseline
*           achievement quartiles); merges in school-level Katrina enrollment and
*           the shelter/Reliant/Astrodome/GRB counts; and constructs the
*           Sept-13-2005 instrument (excluding stadium/convention-center evacuees).
*
* INPUTS:   attend_zip_katrina.dta, demog_new.dta, stanford.dta, aprenda.dta,
*           taas.dta, taks.dta, discipline.dta, stlink_elem.dta,
*           katrina_enroll.dta, shelter_evacs_9_13/9_29/10_28.dta
* OUTPUTS:  hisd_data.dta, katrina_data_with_evacs.dta, katrina_data.dta,
*           maxgrade.dta
*
* KEY STEPS:
*   - Merge attendance + demographics + all exam files + discipline + st-links
*   - Standardize Stanford/Aprenda scores within grade x year (non-evacuees only)
*   - Standardize TAKS to STATEWIDE grade x year mean/SD (hardcoded constants)
*   - Impute time-invariant traits and grade; clean status; label
*   - Build regression dataset: evacuee fractions (campus/grade/class, by gender/
*     race/lunch) and baseline achievement quartiles
*   - Merge school-level Katrina enrollment + shelter counts; build the
*     Sept-13-2005 (noRGB) instrument and pre-2005 zeros
*   - Build maxgrade.dta (top grade in each school) and merge back
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - PATHS (repoint all to your local globals):
*       cd /home/s/simberman/work/hisd/katrina
*       /home/s/simberman/work/hisd/katrina/hisd_data.dta
*       /work/i/imberman/imberman/hisd_data.dta (and katrina_data*, maxgrade,
*       katrina_enroll, shelter_evacs_9_13/9_29/10_28)
*   - Stanford/Aprenda standardization loops: numlist 1997/2006 and grade 1/11,3/11 (YEAR HARDCODE)
*   - TAKS statewide mean/SD constants hardcoded for grade 3-11 x year 2002-2008 (score standardization)
*   - taks_sdalt uses year == 2003 only (YEAR HARDCODE: pre-Katrina alt standardization)
*   - dob/grade imputation gated on year >= 1996 (YEAR HARDCODE)
*   - keep if year >= 2002 (YEAR HARDCODE: first analysis year)
*   - enroll_0506 logic: year >= 2005 / == 2005 / == 2006 (YEAR HARDCODE)
*   - replace katrina = 0 if year < 2005 (YEAR HARDCODE: pre-treatment shares = 0)
*   - quartile evacuee shares carried l. from 2005 to 2006 (YEAR HARDCODE)
*   - shelter/instrument vars set to 0 if year < 2005 (YEAR HARDCODE)
*   - Sept-13-2005 IV: *_9_13, *noRGB*, shelter/Reliant/Astrodome/GRB subtraction
*   - maxgrade per-campus corrections hardcoded by year 2003/2004/2005/2006 (YEAR HARDCODE)
*
* NOTE: Documentation comments only — no executable code was modified.
*===============================================================================
*THIS MERGES ALL OF THE HISD DATA INTO ONE FILE
clear
set mem 7g
set more off


*THIS MERGES ALL OF THE HISD DATA INTO ONE FILE
clear
set mem 7g
set more off

cd /home/s/simberman/work/hisd/katrina   // PATH: repoint to your local globals
use attend_zip_katrina.dta
sort id year

*MERGE IN DEMOGRAPHICS
merge id year using demog_new.dta, _merge(merge_demog)
sort id year

*MERGE IN STANFORD EXAMS
merge id year using stanford.dta, _merge(merge_stanford)
sort grade year


* ---- SCORE STANDARDIZATION: Stanford scale scores within grade x year (non-evacuees) ----
  *GENERATE STANDARD DEVIATION UNITS OF STANFORD SCALE SCORES NORMALIZED TO MEAN = 0
  *WITHIN GRADE & YEAR EXCLUDING KATRINA
  foreach var in "stanford_read"  "stanford_math" "stanford_lang" {
	gen `var'_sd =.
	foreach grade of numlist 1/11 {            // YEAR HARDCODE (grade range 1-11)
		foreach year of numlist 1997/2006 {    // YEAR HARDCODE: standardize over 1997-2006
			sum `var'_scale if grade == `grade' & year == `year' & (katrina == 0 | katrina == .)
			replace `var'_sd = (`var'_scale - r(mean))/(r(sd)) if grade == `grade' & year == `year'
		}
	}
  }


  * SCORE STANDARDIZATION: Stanford science/social-studies (grade 3-11) within grade x year
  foreach var in "stanford_science"  "stanford_socialstu" {
	gen `var'_sd =.
	foreach grade of numlist 3/11 {            // YEAR HARDCODE (grade range 3-11)
		foreach year of numlist 1997/2006 {    // YEAR HARDCODE: standardize over 1997-2006
			sum `var'_scale if grade == `grade' & year == `year' & (katrina == 0 | katrina == .)
			replace `var'_sd = (`var'_scale - r(mean))/(r(sd)) if grade == `grade' & year == `year'
		}
	}
  }
*/

sort id year
* ---- Merge in Aprenda exams ----
*MERGE IN APRENDA EXAMS
merge id year using aprenda.dta, _merge(merge_aprenda)
sort id year


* ---- SCORE STANDARDIZATION: combined Stanford+Aprenda within grade x year (non-evacuees) ----
*GENERATE STANDARD DEVIATION OF STANFORD COMBINED WITH APRENDA SCORES NORMALIZED TO MEAN 0, SD1
*IF BOTH STANFORD & APRENDA ARE AVAILABLE THEN USE STANFORD
foreach var in "read" "math" "lang" "science" "socialstu" {
  gen stanford_aprenda_`var'_scale = stanford_`var'_scale
  replace stanford_aprenda_`var'_scale = aprenda_`var'_scale if stanford_`var'_scale == .
}

  foreach var in "stanford_aprenda_read"  "stanford_aprenda_math" "stanford_aprenda_lang" {
	gen `var'_sd =.
	foreach grade of numlist 1/11 {            // YEAR HARDCODE (grade range 1-11)
		foreach year of numlist 1997/2006 {    // YEAR HARDCODE: standardize over 1997-2006
			sum `var'_scale if grade == `grade' & year == `year' & (katrina == 0 | katrina == .)
			replace `var'_sd = (`var'_scale - r(mean))/(r(sd)) if grade == `grade' & year == `year'
		}
	}
  }


  * SCORE STANDARDIZATION: combined science/social-studies (grade 3-11) within grade x year
  foreach var in "stanford_aprenda_science"  "stanford_aprenda_socialstu" {
	gen `var'_sd =.
	foreach grade of numlist 3/11 {            // YEAR HARDCODE (grade range 3-11)
		foreach year of numlist 1997/2006 {    // YEAR HARDCODE: standardize over 1997-2006
			sum `var'_scale if grade == `grade' & year == `year' & (katrina == 0 | katrina == .)
			replace `var'_sd = (`var'_scale - r(mean))/(r(sd)) if grade == `grade' & year == `year'
		}
	}
  }


* ---- Merge in TAAS exams ----
*MERGE IN TAAS EXAMS
merge id year using taas.dta, _merge(merge_taas)
sort id year

* ---- Merge in TAKS exams ----
*MERGE IN TAKS EXAMS
merge id year using taks.dta, _merge(merge_taks)
sort grade year

/*
  * SCORE STANDARDIZATION (DISABLED — commented-out block):
  * sample-based TAKS standardization within grade x year. The active version
  * below uses hardcoded STATEWIDE constants instead.
  *GENERATE STANDARD DEVIATION UNITS OF TAKS SCALE SCORES NORMALIZED TO MEAN = 0
  *WITHIN GRADE & YEAR - NOTE THAT TAKS-SPANISH * TAKS-ENGLISH ARE COMBINED HERE
  foreach var in "avg_read"  "avg_math" "min_read" "min_math"{
	gen taks_sd_`var' =.
	foreach grade of numlist 3/11 {
		foreach year of numlist 2002/2006 {
			sum taks_scale_`var' if grade == `grade' & year == `year' & (katrina == 0 | katrina == .)
			replace taks_sd_`var' = (taks_scale_`var' - r(mean))/(r(sd)) if grade == `grade' & year == `year'
		}
	}
  }
*/

# delimit cr
* ---- SCORE STANDARDIZATION: TAKS via hardcoded STATEWIDE grade x year mean/SD ----
* This is the ACTIVE TAKS standardization used in the paper (Texas statewide
* means/SDs, not the HISD sample). EVERY constant below is hardcoded by grade
* (3-11) and year (2002-2008). For a new-years replication these statewide
* mean/SD constants must be supplied and the year lines extended.
* (taks_sd_min_read / taks_sd_min_math are the standardized achievement outcomes.)
***USE STATEWIDE MEAN & SD BY GRADE - ADDED 3/11****

gen taks_sd_min_read = .
gen taks_sd_min_math = .

* SCORE STANDARDIZATION constants — reading, grade 3-11 x year 2002-2008 (YEAR HARDCODE throughout)
replace taks_sd_min_read = (taks_scale_min_read - 2254.6)/183.45 if grade == 3 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2212.7)/171.46 if grade == 4 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2187.7)/203.11 if grade == 5 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2227.39)/227.96 if grade == 6 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2191.9)/171.45 if grade == 7 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2244.2)/211.58 if grade == 8 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2140.23)/159.22 if grade == 9 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2158.47)/135.75 if grade == 10 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2147.79)/146.06 if grade == 11 & year == 2002
replace taks_sd_min_read = (taks_scale_min_read - 2279.02)/169.31 if grade == 3 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2233.53)/174.91 if grade == 4 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2210.75)/210.01 if grade == 5 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2260.34)/217.09 if grade == 6 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2210.01)/190.58 if grade == 7 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2246.89)/183.24 if grade == 8 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2186.91)/147.27 if grade == 9 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2179.67)/115.73 if grade == 10 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2214.02)/129.41 if grade == 11 & year == 2003
replace taks_sd_min_read = (taks_scale_min_read - 2305.64)/182.59 if grade == 3 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2234.58)/177.22 if grade == 4 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2216.92)/192.33 if grade == 5 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2295.87)/213.78 if grade == 6 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2224.33)/175.84 if grade == 7 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2287.92)/216.69 if grade == 8 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2217.58)/164.88 if grade == 9 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2187.62)/118.72 if grade == 10 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2272.07)/143.36 if grade == 11 & year == 2004
replace taks_sd_min_read = (taks_scale_min_read - 2311.69)/183.52 if grade == 3 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2226.85)/154.14 if grade == 4 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2228.19)/189.19 if grade == 5 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2332.84)/200.63 if grade == 6 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2216.33)/173.32 if grade == 7 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2292.1)/216.83 if grade == 8 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2247.25)/171.28 if grade == 9 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2229.94)/133.25 if grade == 10 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2273.29)/139.58 if grade == 11 & year == 2005
replace taks_sd_min_read = (taks_scale_min_read - 2301.3)/181.92 if grade == 3 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2246.82)/170.34 if grade == 4 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2244.36)/183.69 if grade == 5 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2365.62)/209.06 if grade == 6 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2251.45)/166.52 if grade == 7 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2305.76)/189.19 if grade == 8 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2240.79)/170.34 if grade == 9 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2238.71)/128.88 if grade == 10 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2288.06)/145.17 if grade == 11 & year == 2006
replace taks_sd_min_read = (taks_scale_min_read - 2303.15)/185.48 if grade == 3 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2247.41)/177.7 if grade == 4 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2255.59)/197.63 if grade == 5 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2349.83)/219.64 if grade == 6 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2260.62)/186.6 if grade == 7 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2350.92)/199.8 if grade == 8 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2255.22)/180.08 if grade == 9 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2262.05)/140.69 if grade == 10 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2281.54)/141.98 if grade == 11 & year == 2007
replace taks_sd_min_read = (taks_scale_min_read - 2318.28)/180.2 if grade == 3 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2263.53)/182.54 if grade == 4 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2271.06)/211.28 if grade == 5 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2347.71)/205.02 if grade == 6 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2261.97)/175.01 if grade == 7 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2368.08)/205.05 if grade == 8 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2250.81)/182.43 if grade == 9 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2247.05)/137.55 if grade == 10 & year == 2008
replace taks_sd_min_read = (taks_scale_min_read - 2299.94)/152.59 if grade == 11 & year == 2008



* SCORE STANDARDIZATION constants — math, grade 3-11 x year 2002-2008 (YEAR HARDCODE throughout)
replace taks_sd_min_math = (taks_scale_min_math - 2212.4)/187.23 if grade == 3 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2193.87)/183.78 if grade == 4 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2183.25)/211.8 if grade == 5 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2166.65)/218.85 if grade == 6 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2121.01)/158.39 if grade == 7 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2115.51)/166.86 if grade == 8 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2096.17)/221.77 if grade == 9 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2114.67)/168.06 if grade == 10 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2101.03)/158.91 if grade == 11 & year == 2002
replace taks_sd_min_math = (taks_scale_min_math - 2246.7)/178.59 if grade == 3 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2227.81)/183.09 if grade == 4 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2228.9)/228.13 if grade == 5 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2197.18)/228.34 if grade == 6 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2139.32)/154.09 if grade == 7 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2146.62)/201.79 if grade == 8 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2120.7)/231.04 if grade == 9 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2121.95)/171.11 if grade == 10 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2186.4)/183.72 if grade == 11 & year == 2003
replace taks_sd_min_math = (taks_scale_min_math - 2244.97)/189.87 if grade == 3 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2255.65)/194.13 if grade == 4 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2265.51)/222.99 if grade == 5 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2233.84)/235.47 if grade == 6 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2166.97)/170.27 if grade == 7 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2156.1)/192.57 if grade == 8 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2140.46)/224.48 if grade == 9 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2138.67)/176.78 if grade == 10 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2201.29)/178.49 if grade == 11 & year == 2004
replace taks_sd_min_math = (taks_scale_min_math - 2255.61)/200.97 if grade == 3 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2267.51)/192.1 if grade == 4 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2292.9)/235.09 if grade == 5 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2272.95)/231.73 if grade == 6 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2187.71)/167.43 if grade == 7 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2185.23)/193.12 if grade == 8 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2138.21)/225.24 if grade == 9 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2159.09)/183.1 if grade == 10 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2217.98)/174.04 if grade == 11 & year == 2005
replace taks_sd_min_math = (taks_scale_min_math - 2259.36)/195.37 if grade == 3 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2278.8)/193.01 if grade == 4 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2313)/231.16 if grade == 5 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2291.46)/245.38 if grade == 6 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2216.89)/173.39 if grade == 7 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2197.01)/190.09 if grade == 8 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2162.84)/230.3 if grade == 9 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2164.48)/185.39 if grade == 10 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2229.12)/167.25 if grade == 11 & year == 2006
replace taks_sd_min_math = (taks_scale_min_math - 2266.11)/197.51 if grade == 3 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2270.94)/194.19 if grade == 4 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2311.38)/238 if grade == 5 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2289.39)/251.56 if grade == 6 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2218.88)/183.67 if grade == 7 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2231.26)/203.04 if grade == 8 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2167.67)/249.52 if grade == 9 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2172.67)/193.54 if grade == 10 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2245.89)/195.11 if grade == 11 & year == 2007
replace taks_sd_min_math = (taks_scale_min_math - 2288.71)/209.13 if grade == 3 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2311.62)/211.18 if grade == 4 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2328.31)/245.67 if grade == 5 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2294.61)/245.57 if grade == 6 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2230.89)/174.43 if grade == 7 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2240.68)/198.52 if grade == 8 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2202.81)/243.55 if grade == 9 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2181.93)/193.75 if grade == 10 & year == 2008
replace taks_sd_min_math = (taks_scale_min_math - 2263.53)/196.51 if grade == 11 & year == 2008





* ---- SCORE STANDARDIZATION (alt): standardize TAKS using only pre-Katrina 2003 ----
  *ALTERNATIVE STANDARDIZATION USING ONLY 2003-04 (PRE-KATRINA) YEARS
  foreach var in "avg_read"  "avg_math" "min_read" "min_math"{
	gen taks_sdalt_`var' =.
	foreach grade of numlist 3/11 {                    // YEAR HARDCODE (grade range 3-11)
			sum taks_scale_`var' if grade == `grade' & year == 2003   // YEAR HARDCODE: standardize off 2003 only
			replace taks_sdalt_`var' = (taks_scale_`var' - r(mean))/(r(sd)) if grade == `grade'
	}
  }


sort id year


* ---- Merge in discipline ----
*MERGE IN DISCIPLINE
merge id year using discipline.dta, _merge(merge_disc)
sort id year


* ---- Merge in elementary student-teacher links ----
*MERGE IN ELEM STUDENT-TEACHER LINKS
merge id year using stlink_elem.dta, _merge(merge_stlink_elem)
sort id year


drop if id == .




  *IF DISCIPLINE OB IS MISSING THEN IT IS ZERO
  foreach var of varlist anyinf violate substance crime susp_out susp_in expulsion aep contexp contaep fighting susp_tot {
    replace `var' = 0 if `var' == .
  }


compress


* ---- Clean data further: impute time-invariant traits & grade, fix status ----
*CLEAN DATA FURTHER

  *DROP IF STUDENT HAS DEMOGRAPHIC DATA BUT NO ATTENDENCE RECORD ID
  drop if merge_demog == 2

  *IMPUTE TIME INVARIANT CHARACTERISTICS FOR STUDENTS AND FLAG IF AN OBS IS IMPUTED
  tsset (id) year
  gen flag_female_impute = female == .
  label variable flag_female_impute "gender missing - imputed as last recorded"
  gen flag_ethnicity_impute = ethnicity == .
  label variable flag_ethnicity_impute "ethnicity missing - imputed as last recorded"
  gen flag_dob_impute = dob == . if year >= 1996   // YEAR HARDCODE: dob only available 1996+
  label variable flag_dob_impute "dob missing - imputed as last recorded"
  forvalues t = 1/10 {
   foreach var in "female" "ethnicity" {
    replace `var' = l.`var' if `var' == . & l.`var' != .
    replace `var'_2 = l.`var'_2 if `var'_2 == . & l.`var' != .
    replace `var' = f.`var' if `var' ==. & f.`var' != .
    replace `var'_2 = f.`var' if `var' == . & f.`var' != .
   }
  }
  replace flag_female_impute = . if female == .
  replace flag_ethnicity_impute = . if ethnicity == .

  *DOB ONLY PROVIDED 1996 & LATER, SO LIMIT IMPUTATIONS TO THIS YEAR

  forvalues t = 1/10 {
   foreach var in "dob" {
    replace `var' = l.`var' if `var' == . & l.`var' != . & year >= 1996      // YEAR HARDCODE: dob 1996+
    replace `var'_2 = l.`var'_2 if `var'_2 == . & l.`var' != . & year >= 1996 // YEAR HARDCODE: dob 1996+
    replace `var' = f.`var' if `var' ==. & f.`var' != . & year >= 1996        // YEAR HARDCODE: dob 1996+
    replace `var'_2 = f.`var' if `var' == . & f.`var' != . & year >= 1996     // YEAR HARDCODE: dob 1996+
   }
  }
  replace flag_dob_impute = . if dob == .

*FOR STUDENTS WITH NO GRADE PROVIDED, GENERATE IMPUTED GRADE LEVEL ASSUMING NORMAL GRADE PROGRESSION FROM LAST OBSERVED GRADE
*IF GRADE MISSING IN FIRST YEAR OBSERVED USE FUTURE GRADES TO IMPUTE
*NOTE THAT IF WE'RE DOING TEST SCORES IT MAY BE BETTER TO JUST USE THE GRADE LEVEL IN THE STANFORD TEST FILES
gen grade_impute = grade
label variable grade_impute "if grade missing, imputed using last known assuming normal grade prog"
forvalues t = 1/15 {
  replace grade_impute = l`t'.grade_impute + `t' if grade_impute == .
}
forvalues t = 1/15 {
  replace grade_impute = f`t'.grade_impute - `t' if grade_impute == .
}
gen flag_grade_impute = grade_impute != . & grade == .

  *IF IMPUTED GRADE > 12, REPLACE WITH GRADE = 12
  replace grade_impute = 12 if grade_impute > 12 & grade_impute != .

  *IF IMPUTED GRADE < -2 THEN MAKE MISSING SINCE WOULD FALL OUT OF SAMPLE ANYWAY
  replace grade_impute = . if grade_impute < -2 & grade_impute != .


*FIX STATUS SO THAT ACTIVE STUDENTS ARE "A" AND MISCODED DATA ARE MISSING
replace status = "temp" if status == "A"
replace status = "A" if status == ""
replace status = "" if status != "A" & status != "W" & status != "G" & status != "N" & status != "T"

*DROP VARIABLE THAT SHOULD HAVE BEEN DROPPED IN DEMOGRAPHIC CLEANING PROGRAM
drop baddatid

* ---- Additional variable labels ----
*ADDITIONAL LABELS
label variable campus "campus ID from demographic file - campus attended Oct. 31"
label variable sch1 "school ID's from attendence file"
label variable zip_code "student's zip code of residence"
label variable enter_date "first day of academic year student was enrolled"
label variable leave_date "last day of AY student was enrolled - 0 if student did not leave prior to year's end"
label variable status "end of year stutus: G - grad, T - transfer, W - withdrew, N - noshow, A - active"
label variable perc_attn "attendence rate"
rename anyinf infractions
label variable infractions "number of disciplinary infractions w/ in-school suspension or more severe"
label variable violate "number of non substance abuse or criminal violations of student code"
label variable substance "number of substance abuse infractions"
label variable crime "number of infractions that could lead to arrest"
label variable susp_out "number of out-of-school suspensions"
label variable susp_in "number of in-school suspsensions"
label variable expulsion "expelled possibly w/ referral to juvenile justice or alt disciplinary program"
label variable aep "referred to disciplinary alt education or juvenile justice  w/o expulsion"
label variable fighting "number of infractions for fighting"
label variable susp_tot "number of in or out-of-school suspensions"


aorder
order id year campus sch*
compress
sort id year

* ---- Save master merged Houston panel (hisd_data.dta) ----
save /home/s/simberman/work/hisd/katrina/hisd_data.dta, replace   // PATH: repoint to your local globals
save /work/i/imberman/imberman/hisd_data.dta, replace             // PATH: repoint to your local globals



*===============================================================================
* SECTION: Build the regression dataset (evacuee shares + baseline quartiles)
*===============================================================================
***GENERATE REGRESSION DATASET***
 *LOAD HISD DATA
use /work/i/imberman/imberman/hisd_data, clear   // PATH: repoint to your local globals

*KEEP ONLY THOSE WHO HAVE GRADES LISTED AND THUS WERE ENROLLED IN LATE OCTOBER OF THE YEAR
drop if grade == .

*REMOVE STUDENTS WITH MISSING ATTENDANCE DATA
drop if perc_attn == .

*LIMIT TO POST 2001
keep if year >= 2002   // YEAR HARDCODE: first analysis year; widen for new years

* ---- Restrict to students enrolled in 2005-06 (Katrina status only exists then) ----
*SINCE KATRINA STATUS IS ONLY PROVIDED IN 2005-06, WE LIMIT TO STUDENTS ENROLLED IN THAT YEAR
drop unit
gen unit = 1
xtset id year
gen enroll_0506 = 0 if year >= 2005                       // YEAR HARDCODE: 2005-06 window
replace enroll_0506 = 1 if year == 2005                   // YEAR HARDCODE: first post-Katrina year
replace enroll_0506 = 1 if year == 2006 & l.unit != .     // YEAR HARDCODE: 2006 if also enrolled 2005
drop if enroll_0506 == 0


* ---- Generate evacuee (Katrina) fractions by campus / grade / class ----
*GENERATE FRACTION KATRINA
replace katrina = 0 if year < 2005   // YEAR HARDCODE: pre-treatment years have 0 evacuees

*BY CAMPUS
egen katrina_count_campus = sum(katrina), by(campus year)
egen enroll_campus = sum(unit), by(campus year)
gen katrina_frac_campus = katrina_count_campus/enroll_campus

*BY GRADE
egen katrina_count_grade = sum(katrina), by(campus grade year)
egen enroll_grade = sum(unit), by(campus grade year)
gen katrina_frac_grade = katrina_count_grade/enroll_grade

*BY CLASS - GRADES 1 - 5 ONLY
egen katrina_count_class = sum(katrina) if grade >= 1 & grade <= 5, by(campus grade year teacher_num)
egen enroll_class = sum(unit) if grade >=1 & grade <= 5, by(campus grade year teacher_num)
gen katrina_frac_class = katrina_count_class/enroll_class

  * ---- Evacuee shares by gender / ethnicity / lunch status ----
  *GENERATE BY-GENDER MEASURES - CAMPUS
  gen katrina_girls = katrina*female
  gen katrina_boys = katrina*(1 - female)
  egen katrina_count_girls_campus = sum(katrina_girls), by(campus year)
  egen katrina_count_boys_campus = sum(katrina_boys), by(campus year)
  gen katrina_frac_girls_campus = katrina_count_girls_campus/enroll_campus
  gen katrina_frac_boys_campus = katrina_count_boys_campus/enroll_campus

  *GENERATE BY-GENDER MEASURES - GRADE
  egen katrina_count_girls_grade = sum(katrina_girls), by(campus grade year)
  egen katrina_count_boys_grade = sum(katrina_boys), by(campus grade year)
  gen katrina_frac_girls_grade = katrina_count_girls_grade/enroll_grade
  gen katrina_frac_boys_grade = katrina_count_boys_grade/enroll_grade

  *GENERATE BY-GENDER MEASURES - KATRINA GIRLS AS % OF ALL GIRLS, KATRINA BOYS AS % OF ALL BOYS
  gen male = 1 - female
  egen enroll_boys_grade = sum(male), by(campus grade year)
  egen enroll_girls_grade = sum(female), by(campus grade year)
  gen katrina_girls_fracofgirls_grade = katrina_count_girls_grade/enroll_girls_grade
  gen katrina_boys_fracofboys_grade = katrina_count_boys_grade/enroll_boys_grade

  *GENERATE INDICATOR FOR FRACTION BOYS IN GRADE
  egen enroll_boys_frac_grade = mean(male), by(campus grade year)
  egen enroll_boys_frac_campus = mean(male), by(campus grade year)

  *GENERATE % BLACK, % HISPANIC
  gen black = ethnicity == 3
  gen hisp = ethnicity == 4
  egen black_count = sum(black), by(campus year)
  gen frac_black = black_count/enroll_campus
  egen hisp_count = sum(hisp), by(campus year)
  gen frac_hisp = hisp_count/enroll_campus
  gen katrina_frac_black = katrina_frac_campus*frac_black
  gen katrina_frac_hisp = katrina_frac_campus*frac_hisp


  *GENERATE % FREELUNCH
  egen freelunch_count = sum(freelunch), by(campus year)
  gen frac_freelunch = freelunch_count/enroll_campus
  gen katrina_frac_freelunch = katrina_frac_campus*frac_freelunch


  *GENERATE % REDUCED-PRICE LUNCH
  egen redlunch_count = sum(redlunch), by(campus year)
  gen frac_redlunch = redlunch_count/enroll_campus
  gen katrina_frac_redlunch = katrina_frac_campus*frac_redlunch


  *GENERATE % OTHECON
  egen othecon_count = sum(othecon), by(campus year)
  gen frac_othecon = othecon_count/enroll_campus
  gen katrina_frac_othecon = katrina_frac_campus*frac_othecon

  * ---- BASELINE ACHIEVEMENT QUARTILES: sort students into test-score quartiles ----
  * Quartiles of standardized TAKS within grade x year (p25/p50/p75 cutoffs);
  * quartile_0 flags missing test score. Interacted with evacuee share below.
  *GENERATE TEST SCORE QUARTILES
  foreach depvar of varlist taks_sd_min_math taks_sd_min_read {
    foreach percentile of numlist 25 50 75 {
	  egen `depvar'_percentile_`percentile' = pctile(`depvar'), p(`percentile') by(grade year)
    }
    forvalues quartile = 1/4 {
	gen `depvar'_quartile_`quartile' = 0
    }
    replace `depvar'_quartile_1 = 1 if `depvar' <= `depvar'_percentile_25 & `depvar' != .
    replace `depvar'_quartile_2 = 1 if `depvar' > `depvar'_percentile_25 & `depvar' <= `depvar'_percentile_50 & `depvar' != .
    replace `depvar'_quartile_3 = 1 if `depvar' > `depvar'_percentile_50 & `depvar' <= `depvar'_percentile_75 & `depvar' != .
    replace `depvar'_quartile_4 = 1 if `depvar' > `depvar'_percentile_75 & `depvar' != .

   *GENERATE INDICATOR FOR MISSING TEST SCORE
    gen `depvar'_quartile_0 = 0
    replace `depvar'_quartile_0 = 1 if `depvar' == .
  }
  
  * ---- BASELINE ACHIEVEMENT QUARTILES: evacuee shares within each quartile ----
  *GENEARTE EVACUEE FRACTIONS IN EACH QUARTILE
  foreach quartile of numlist 0/4 {
    gen katrina_quartile_`quartile'_math = katrina*taks_sd_min_math_quartile_`quartile'
    gen katrina_quartile_`quartile'_read = katrina*taks_sd_min_read_quartile_`quartile'

    *REPLACE EVACUEE QUARTILES FOR 2006 W/ 2005 QUARTILES
    replace katrina_quartile_`quartile'_math = l.katrina_quartile_`quartile'_math if year == 2006   // YEAR HARDCODE: carry 2005 quartile shares to 2006
    replace katrina_quartile_`quartile'_read = l.katrina_quartile_`quartile'_read if year == 2006   // YEAR HARDCODE: carry 2005 quartile shares to 2006

   
    egen katrina_count_math_quartile_`quartile' = sum(katrina_quartile_`quartile'_math)
    gen katrina_frac_math_quartile_`quartile' = katrina_count_math_quartile_`quartile'/enroll_campus
    egen katrina_count_read_quartile_`quartile' = sum(katrina_quartile_`quartile'_read)
    gen katrina_frac_read_quartile_`quartile' = katrina_count_read_quartile_`quartile'/enroll_campus
  }
 


*DROP STUDENTS YOUNGER THAN FIRST GRADE
drop if grade == -2 | grade == -1 | grade == 0

* ---- Grade restrictions, grade categories, and FE dummies ----
*REPLACE TEST SCORES = . IF GRADE == 12 SINCE THESE ARE ALL TEST RETAKERS
foreach var of varlist stanford_math_sd stanford_read_sd stanford_lang_sd taks_sd_min_math taks_sd_min_read{
  replace `var' = . if grade == 12
}

*GENERATE GRADE CATEGORIES
gen elem = grade >= 1 & grade <= 5
gen middle = grade >= 6 & grade <= 8
gen high = grade >= 9 & grade <= 12
gen midhigh = grade >= 6 & grade <= 12

*GENERATE GRADE-YEAR, CAMPUS, ETHNICITY, ECONDIS  DUMMIES  
gen gradeyear = grade + year*100 
gen gradecamp = grade + campus*100
tab gradeyear, gen(gradeyear_)


*GENERATE DUMMIES
 tab ethnicity, gen(ethnicit_)
 tab econdis, gen(econdis_)
 compress


* ---- Merge school-level Katrina enrollment + shelter/Reliant/Astrodome/GRB counts ----
*MERGE IN SCHOOL-LEVEL KATRINA ENROLLMENT DATA
sort campus
merge campus using /work/i/imberman/imberman/katrina_enroll.dta, nokeep keep(katrina_enroll* enroll_campus_05)   // PATH: repoint to your local globals
tab _merge

*ADD DATA ON KATRINA ENROLLMENT FROM SHELTERS, RELIANT/ASTRODOME, GRB

  *MERGE IN SHELTER DATA
  * Sept-13-2005 IV inputs: shelter_evacs_9_13 is the instrument-date count
  sort campus
  merge campus using /work/i/imberman/imberman/shelter_evacs_9_13.dta, _merge(_merge_shelter_9_13)   // PATH: repoint; Sept-13-2005 IV shelter count
  sort campus
  merge campus using /work/i/imberman/imberman/shelter_evacs_9_29.dta, _merge(_merge_shelter_9_29)   // PATH: repoint to your local globals
  sort campus
  merge campus using /work/i/imberman/imberman/shelter_evacs_10_28.dta, _merge(_merge_shelter_10_28) // PATH: repoint to your local globals

  *2 SCHOOLS WITH ONLY GRADES LESS THAN 1 TOOK IN EVACS... DROP THESE
  drop if _merge_shelter_9_13 == 2
  drop if _merge_shelter_9_29 == 2
  drop if _merge_shelter_10_28 == 2

  *MAKE ANY MISSING VALUES AND PRE-2005 EQUAL TO 0
  foreach var of varlist shelter* astrodome* reliant* george* {
    replace `var' = 0 if `var' == .
    replace `var' = 0 if year < 2005   // YEAR HARDCODE: no evacuee shelters before 2005
  }

  *GENERATE FRACTION KATRINA IN SHELTERS ON 10/28
  gen katrina_frac_shelter_10_28_05 = shelters_arenas_10_28/enroll_campus_05


* ---- SEPT-13-2005 INSTRUMENT: build the IV (excl. stadium/convention shelters) ----
* The instrument is the Sept-13-2005 evacuee share at the school, EXCLUDING the
* Astrodome / Reliant Center / Reliant Arena / George R. Brown convention-center
* shelter residents (the "noRGB" version), used to instrument the later October
* evacuee share. All *_9_13 / *noRGB* objects here are the Sept-13-2005 IV.
***NOTE THAT ANY SCHOOL NOT LISTED IN THE KATRINA COUNTS SENT BY HISD IS ASSUMED TO HAVE HAD NO KATRINA STUDENTS***

  *SUBTRACT OFF THE STUDENTS IN RELIANT, ASTRODOME, GRB FROM 9/13 COUNT
  *THESE STUDENTS ALMOST ALL SWITCHED TO DIFFERENT SCHOOLS B/W 9/13 & 10/28
  *THUS THE INSTRUMENT IS MORE ACCURATE WITHOUT INCLUDING THEM
  gen katrina_enroll_noRGB_9_13_05 = katrina_enroll_9_13_05 - astrodome_9_13 - reliant_center_9_13 - george_brown_9_13 - reliant_arena_9_13   // SEPT-13-2005 IV: noRGB count


  *GENERATE FRACTION OF SCHOOL KATRINA IN 2005
  *UNFORTUNATELY WE DO NOT HAVE TOTAL ENROLLMENT FOR 9/13/05 SO MUST USE ENROLLMENT AS OF LATE OCTOBER
  *SINCE SOME KATRINA STUDENTS LEAVE BEFORE THEN, GENERATE NON-KATRINA ENROLLMENT AND THEN ADD TO KATRINA_9_13 TO GET ESTIMATED ENROLLMENT FOR 9_13
  gen enroll_9_13_05 = enroll_campus_05 - katrina_enroll_10_31_05 + katrina_enroll_9_13_05   // SEPT-13-2005 IV: estimated 9/13 enrollment denominator
  gen katrina_frac_9_13_05 = katrina_enroll_9_13_05/enroll_9_13_05                           // SEPT-13-2005 IV: raw 9/13 evacuee share
  gen enroll_native = enroll_campus_05 - katrina_enroll_10_31_05

  *GENERATE FRACTION OF SCHOOL NON-R/GB KATRINA ON 9/13/05
  gen katrina_frac_noRGB_9_13_05 = katrina_enroll_noRGB_9_13_05/enroll_9_13_05               // SEPT-13-2005 IV: the instrument used in 2SLS


  *REPLACE WITH 0 IF STUDENT ATTENDS SCHOOL THAT DID NOT OPERATE IN 2005
  replace katrina_frac_shelter_10_28_05 = 0 if katrina_frac_shelter_10_28_05 == .
  replace katrina_frac_9_13_05 = 0 if katrina_frac_9_13_05 == .
  replace katrina_frac_noRGB_9_13_05 = 0 if katrina_frac_noRGB_9_13_05 == .
 

*REPLACE PRE-2005 INSTRUMENTS WITH ZEROS
replace  katrina_frac_9_13_05 = 0 if year < 2005        // YEAR HARDCODE: SEPT-13-2005 IV = 0 pre-treatment
replace katrina_frac_noRGB_9_13_05 = 0 if year < 2005  // YEAR HARDCODE: SEPT-13-2005 IV = 0 pre-treatment


xtset campus
drop gradeyear_* grade_*
compress
sort campus grade year

* ---- Save analysis file WITH evacuees (katrina_data_with_evacs.dta) ----
*SAVE FILE WITH EVACUEES
save /work/i/imberman/imberman/katrina_data_with_evacs.dta, replace   // PATH: repoint to your local globals


* ---- Drop evacuees and save native-only analysis file (katrina_data.dta) ----
*DROP KATRINA
drop if katrina == 1

*SAVE FILE W/O EVACUEES
save /work/i/imberman/imberman/katrina_data.dta, replace   // PATH: repoint to your local globals

  
* ---- Build maxgrade.dta: highest grade served by each school (with hand corrections) ----
  *IDENTIFY MAXIMUM GRADE IN SCHOOL
	egen maxgrade = max(grade), by(campus year)

	***  SOME SCHOOLS HAVE A HANDFUL OF STUDENTS IN HIGHER GRADES IN SPECIAL PROGRAMS OR POSSIBLY CODING ERRORS
	***  SOME ELEMENTARY SCHOOLS HAVE 6TH GRADE FOR A PORTION OF THEIR STUDENTS
	***  CORRECT THESE SCHOOLS BASED ON VISUAL INSPECTION OF STUDENT COUNTS BY GRADE TO ASCERTAIN
	***  THE GRADE WHEN MOST STUDENTS LEAVE THE SCHOOL
	***  RULE IS THAT IF ENROLLMENT IN GRADE Y IS <= 1/2 Y-1 IN PREVIOUS YEAR
	***  ENROLLMENT IN GRADE Y+1 THEN GRADE Y IS CONSIDERED HIGHEST GRADE FOR STUDENTS WITH GRADE y <= Y
 
	***  FOR SCHOOLS THAT CLEARLY ENROLL HIGH SCHOOL, THE MAXIMUM GRADE IS ASSUMED TO BE 12 FOR ALL GRADES > 8 IN ALL CASES 
	***  WHERE THERE IS POSITIVE ENROLLMENT IN HIGHER GRADES.  THIS IS BECAUSE MANY HIGH SCHOOLS EXPERIENCE
	***  SUBSTANTIAL DROPOUTS AND A GLUT OF STUDENTS CLASSIFIED AS BEING GRADE 9 DUE TO STRICTER PROMOTION
	***  STANDARDS IN HS VS. MS
	
	gen maxgrade2 = maxgrade

	***MIDDLE W/ PARTIAL HIGH
	foreach campus of numlist 39 56 67 { 
	  replace maxgrade2 = 8 if campus == `campus' & grade <= 8
	  replace maxgrade2 = 12 if campus == `campus' & grade > 8
	}

	*** ELEM W/ PARTIAL 6TH GRADES *** (YEAR HARDCODE: per-year campus lists below)
       	foreach campus of numlist 104 106 117 138 141 146 153 155 157 176 185 202 204 232 234 262 270 276 279 {
  	  replace maxgrade2 = 5 if campus == `campus' & grade <= 5 & year == 2003   // YEAR HARDCODE: 2003 corrections
	  replace maxgrade2 = 6 if campus == `campus' & grade == 6 & year == 2003   // YEAR HARDCODE: 2003 corrections
       	}

       	foreach campus of numlist 138 140 141 153 155 157 179 185 202 204 222 234 259 276 {
  	  replace maxgrade2 = 5 if campus == `campus' & grade <= 5 & year == 2004   // YEAR HARDCODE: 2004 corrections
	  replace maxgrade2 = 6 if campus == `campus' & grade == 6 & year == 2004   // YEAR HARDCODE: 2004 corrections
       	}

       	foreach campus of numlist 153 157 179 185 202 234 259 270 276 {
  	  replace maxgrade2 = 5 if campus == `campus' & grade <= 5 & year == 2005   // YEAR HARDCODE: 2005 corrections
	  replace maxgrade2 = 6 if campus == `campus' & grade == 6 & year == 2005   // YEAR HARDCODE: 2005 corrections
       	}

       	foreach campus of numlist 153 157 179 185 202 218 259 {
  	  replace maxgrade2 = 5 if campus == `campus' & grade <= 5 & year == 2006   // YEAR HARDCODE: 2006 corrections
	  replace maxgrade2 = 6 if campus == `campus' & grade == 6 & year == 2006   // YEAR HARDCODE: 2006 corrections
       	}

	***SPECIAL CASES***      

	  * # 371
  	  replace maxgrade2 = 5 if campus == 371 & grade <= 5 & year == 2005   // YEAR HARDCODE
	  replace maxgrade2 = 6 if campus == 371 & grade == 6 & year == 2005   // YEAR HARDCODE

	  replace maxgrade2 = 6 if campus == 371 & grade <= 6 & year == 2006   // YEAR HARDCODE
	  replace maxgrade2 = 7 if campus == 371 & grade == 7 & year == 2006   // YEAR HARDCODE

	  *  # 375
	  replace maxgrade2 = 2 if campus == 375 & grade <= 2 & year == 2003   // YEAR HARDCODE
	  replace maxgrade2 = 3 if campus == 375 & grade == 3 & year == 2003   // YEAR HARDCODE

** COLLAPSE BY SCHOOL YEAR **
collapse (mean) maxgrade maxgrade2, by(campus grade year)
drop if year == 2006   // YEAR HARDCODE: cannot form t+1 maxgrade for last year
drop if grade == 12
gen campusgrade = campus*100 + grade
xtset campusgrade year
gen maxgrade_tplus1 = f.maxgrade
gen maxgrade2_tplus1 = f.maxgrade2
gen grade_tplus1 = grade + 1
drop campusgrade
sort campus grade year
save /work/i/imberman/imberman/maxgrade.dta, replace   // PATH: repoint to your local globals

* ---- Reload native-only data, merge in maxgrade, and re-save ----
*RELOAD KATRINA DATA
use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals

*MERGE IN MAXGRADE
sort campus grade year
merge campus grade year using /work/i/imberman/imberman/maxgrade.dta, _merge(_mergemaxgrade)   // PATH: repoint to your local globals
save, replace


