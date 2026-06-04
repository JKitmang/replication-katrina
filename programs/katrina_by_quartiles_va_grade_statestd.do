*===============================================================================
* FILE:     katrina_by_quartiles_va_grade_statestd.do
* PROJECT:  Katrina's Children (Imberman, Kugler & Sacerdote, AER)
* ROLE:     Analysis (Houston value-added quartile peer-effects regressions)
* PRODUCES: Table 3 and Table 10 (main-text Houston grade-level achievement VA
*           quartile results, OLS columns). The published achievement quartile
*           estimates standardize TAKS scores using STATEWIDE (not HISD-internal)
*           grade x year means and SDs.
*
* PURPOSE:  Same Hoxby-Weingarth quartile design as the other VA files, but the
*           dependent variable is re-standardized against STATEWIDE grade x year
*           means/SDs (taks_sdstate_min_*) instead of the within-HISD
*           standardization. Estimates the effect of the grade-level evacuee
*           share (katrina_frac_grade) on incumbent math/read scores, attendance
*           and infractions, pooled and within each pre-Katrina achievement
*           quartile, for elem and midhigh.
*
* INPUTS:   /work/i/imberman/imberman/katrina_data.dta  (must contain raw
*           taks_scale_min_math/read scale scores)
*           /work/i/imberman/imberman/pre_katrina_quartiles.dta (incumbent quartiles)
* OUTPUTS:  Regression output to the log (areg coefficients on katrina_frac_grade);
*           feeds Table 3 / Table 10 columns.
*
* KEY STEPS:
*   - Loop over grade level (elem, midhigh); open katrina_data.dta.
*   - SCORE STANDARDIZATION: convert raw scale scores to z-scores using the long
*     block of hardcoded statewide grade x year means/SDs (2002-2008).
*   - Build pre-Katrina test-score lags (lags from years <= 2004).
*   - Merge incumbent pre-Katrina achievement quartiles.
*   - Grade x year interactions + school FE via areg.
*   - Pooled VA model and quartile-specific VA models for math/read (+attendance,
*     infractions).
*
* HARDCODED YEARS / PATHS TO UPDATE FOR A NEW-YEARS REPLICATION:
*   - cd /work/i/imberman/imberman/ and use/merge absolute paths -> PATH.
*   - SCORE STANDARDIZATION CONSTANTS: ~150 `replace ... if grade==G & year==Y`
*     lines (read then math) hardcode statewide means/SDs for grades 3-11 and
*     years 2002-2008. EVERY one is a YEAR (and grade) HARDCODE: supply new
*     statewide moments for any added year.
*   - l`lag'.year <= 2004 (twice) -> YEAR HARDCODE: pre-Katrina lags only.
*   - Quartile membership (taks_sd_min_*_quartile) uses the within-HISD score;
*     baseline achievement quartiles still defined on the HISD standardization.
*
* NOTE: Documentation comments only -- no executable code was modified.
*===============================================================================
**THIS ANALYSIS IS SIMILAR TO THAT DONE IN HOXBY AND WEINGARTH (2005) IN THAT IT INTERACTS THE FRACTION EVACUEE IN EACH QUARTILE BASED ON  2005 SCORE
*WITH THE QUARTILE OF THE NATIVE STUDENT IN 2004 - THIS WILL ALLOW US TO TEST FOR THE EXISTENCE OF BOUTIQUE/BAD-APPLE/SHINING-LIGHT MODELS

*UNRESTRICTED VALUE-ADDED REGRESSIONS

***ALTERNATIVE STANDARDIZATION****

clear
set mem 3g
set matsize 2000
set more off

***OPTIONS****


* ---- Working directory + clear stale outreg files ----
  cd /work/i/imberman/imberman/   // PATH: repoint to your local globals
  capture rm outreg_quartile_grade.txt
  capture rm outreg_quartile_grade.xls
  capture rm outreg_quartile_grade.xml


*LOOP OVER GRADE LEVEL
foreach grade in "elem" "midhigh"{

  *INCREASE COUNTER FOR GRADELEVEL (1 = ELEM, 2 = MIDHIGH)
  local gradenum = `gradenum' + 1

  *OPEN KATRINA DATA
  use /work/i/imberman/imberman/katrina_data.dta, clear   // PATH: repoint to your local globals
  xtset id year

  * ---- SCORE STANDARDIZATION (statewide moments) ----
  * Converts raw TAKS scale scores to z-scores using HARDCODED statewide
  * grade x year means and SDs. Every `replace ... if grade==G & year==Y` line
  * below is a YEAR (and grade) HARDCODE for 2002-2008; reading block first,
  * then the math block. Supply new statewide mean/SD constants for new years.
  *ALTERNATIVE STANDARDIZATION USING STATEWIDE SD & MEAN

gen taks_sdstate_min_read = .
gen taks_sdstate_min_math = .

replace taks_sdstate_min_read = (taks_scale_min_read - 2254.6)/183.45 if grade == 3 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2212.7)/171.46 if grade == 4 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2187.7)/203.11 if grade == 5 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2227.39)/227.96 if grade == 6 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2191.9)/171.45 if grade == 7 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2244.2)/211.58 if grade == 8 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2140.23)/159.22 if grade == 9 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2158.47)/135.75 if grade == 10 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2147.79)/146.06 if grade == 11 & year == 2002
replace taks_sdstate_min_read = (taks_scale_min_read - 2279.02)/169.31 if grade == 3 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2233.53)/174.91 if grade == 4 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2210.75)/210.01 if grade == 5 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2260.34)/217.09 if grade == 6 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2210.01)/190.58 if grade == 7 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2246.89)/183.24 if grade == 8 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2186.91)/147.27 if grade == 9 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2179.67)/115.73 if grade == 10 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2214.02)/129.41 if grade == 11 & year == 2003
replace taks_sdstate_min_read = (taks_scale_min_read - 2305.64)/182.59 if grade == 3 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2234.58)/177.22 if grade == 4 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2216.92)/192.33 if grade == 5 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2295.87)/213.78 if grade == 6 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2224.33)/175.84 if grade == 7 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2287.92)/216.69 if grade == 8 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2217.58)/164.88 if grade == 9 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2187.62)/118.72 if grade == 10 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2272.07)/143.36 if grade == 11 & year == 2004
replace taks_sdstate_min_read = (taks_scale_min_read - 2311.69)/183.52 if grade == 3 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2226.85)/154.14 if grade == 4 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2228.19)/189.19 if grade == 5 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2332.84)/200.63 if grade == 6 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2216.33)/173.32 if grade == 7 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2292.1)/216.83 if grade == 8 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2247.25)/171.28 if grade == 9 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2229.94)/133.25 if grade == 10 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2273.29)/139.58 if grade == 11 & year == 2005
replace taks_sdstate_min_read = (taks_scale_min_read - 2301.3)/181.92 if grade == 3 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2246.82)/170.34 if grade == 4 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2244.36)/183.69 if grade == 5 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2365.62)/209.06 if grade == 6 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2251.45)/166.52 if grade == 7 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2305.76)/189.19 if grade == 8 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2240.79)/170.34 if grade == 9 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2238.71)/128.88 if grade == 10 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2288.06)/145.17 if grade == 11 & year == 2006
replace taks_sdstate_min_read = (taks_scale_min_read - 2303.15)/185.48 if grade == 3 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2247.41)/177.7 if grade == 4 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2255.59)/197.63 if grade == 5 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2349.83)/219.64 if grade == 6 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2260.62)/186.6 if grade == 7 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2350.92)/199.8 if grade == 8 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2255.22)/180.08 if grade == 9 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2262.05)/140.69 if grade == 10 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2281.54)/141.98 if grade == 11 & year == 2007
replace taks_sdstate_min_read = (taks_scale_min_read - 2318.28)/180.2 if grade == 3 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2263.53)/182.54 if grade == 4 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2271.06)/211.28 if grade == 5 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2347.71)/205.02 if grade == 6 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2261.97)/175.01 if grade == 7 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2368.08)/205.05 if grade == 8 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2250.81)/182.43 if grade == 9 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2247.05)/137.55 if grade == 10 & year == 2008
replace taks_sdstate_min_read = (taks_scale_min_read - 2299.94)/152.59 if grade == 11 & year == 2008



* ---- SCORE STANDARDIZATION continued: MATH statewide grade x year moments (YEAR HARDCODE 2002-2008) ----
replace taks_sdstate_min_math = (taks_scale_min_math - 2212.4)/187.23 if grade == 3 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2193.87)/183.78 if grade == 4 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2183.25)/211.8 if grade == 5 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2166.65)/218.85 if grade == 6 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2121.01)/158.39 if grade == 7 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2115.51)/166.86 if grade == 8 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2096.17)/221.77 if grade == 9 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2114.67)/168.06 if grade == 10 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2101.03)/158.91 if grade == 11 & year == 2002
replace taks_sdstate_min_math = (taks_scale_min_math - 2246.7)/178.59 if grade == 3 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2227.81)/183.09 if grade == 4 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2228.9)/228.13 if grade == 5 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2197.18)/228.34 if grade == 6 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2139.32)/154.09 if grade == 7 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2146.62)/201.79 if grade == 8 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2120.7)/231.04 if grade == 9 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2121.95)/171.11 if grade == 10 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2186.4)/183.72 if grade == 11 & year == 2003
replace taks_sdstate_min_math = (taks_scale_min_math - 2244.97)/189.87 if grade == 3 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2255.65)/194.13 if grade == 4 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2265.51)/222.99 if grade == 5 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2233.84)/235.47 if grade == 6 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2166.97)/170.27 if grade == 7 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2156.1)/192.57 if grade == 8 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2140.46)/224.48 if grade == 9 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2138.67)/176.78 if grade == 10 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2201.29)/178.49 if grade == 11 & year == 2004
replace taks_sdstate_min_math = (taks_scale_min_math - 2255.61)/200.97 if grade == 3 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2267.51)/192.1 if grade == 4 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2292.9)/235.09 if grade == 5 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2272.95)/231.73 if grade == 6 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2187.71)/167.43 if grade == 7 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2185.23)/193.12 if grade == 8 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2138.21)/225.24 if grade == 9 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2159.09)/183.1 if grade == 10 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2217.98)/174.04 if grade == 11 & year == 2005
replace taks_sdstate_min_math = (taks_scale_min_math - 2259.36)/195.37 if grade == 3 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2278.8)/193.01 if grade == 4 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2313)/231.16 if grade == 5 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2291.46)/245.38 if grade == 6 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2216.89)/173.39 if grade == 7 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2197.01)/190.09 if grade == 8 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2162.84)/230.3 if grade == 9 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2164.48)/185.39 if grade == 10 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2229.12)/167.25 if grade == 11 & year == 2006
replace taks_sdstate_min_math = (taks_scale_min_math - 2266.11)/197.51 if grade == 3 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2270.94)/194.19 if grade == 4 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2311.38)/238 if grade == 5 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2289.39)/251.56 if grade == 6 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2218.88)/183.67 if grade == 7 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2231.26)/203.04 if grade == 8 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2167.67)/249.52 if grade == 9 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2172.67)/193.54 if grade == 10 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2245.89)/195.11 if grade == 11 & year == 2007
replace taks_sdstate_min_math = (taks_scale_min_math - 2288.71)/209.13 if grade == 3 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2311.62)/211.18 if grade == 4 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2328.31)/245.67 if grade == 5 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2294.61)/245.57 if grade == 6 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2230.89)/174.43 if grade == 7 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2240.68)/198.52 if grade == 8 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2202.81)/243.55 if grade == 9 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2181.93)/193.75 if grade == 10 & year == 2008
replace taks_sdstate_min_math = (taks_scale_min_math - 2263.53)/196.51 if grade == 11 & year == 2008



  * ---- Build pre-Katrina test-score lags (value-added controls, on statewide-std scores) ----
  *GENEARATE TEST SCORE LAGS FROM PRE-KATRINA YEARS
  foreach var of varlist taks_sdstate_min_math taks_sdstate_min_read perc_attn infractions {
  gen l`var' = .
  gen lagyears_`var' = .
  foreach lag of numlist 1/5 {
    replace lagyears_`var' = `lag' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: pre-Katrina lags only (<=2004)
    replace l`var' = l`lag'.`var' if l`var' == . & l`lag'.`var' != . & l`lag'.year <= 2004   // YEAR HARDCODE: pre-Katrina lag (<=2004)
  }
  tab lagyears_`var', gen(lagyears_`var'_)
  forvalues gap = 1/4 {
    gen l`var'_`gap' = lagyears_`var'_`gap'*l`var'
  }
  }

  *KEEP ONLY GRADE LEVEL BEING ANALYSED IN SAMPLE
  keep if `grade' == 1
  
  
  *MERGE IN KATRINA MEDIAN DATA & QUARTILE DATA
  capture drop katrina*median*
  /*
  sort campus year
  merge campus year using /work/i/imberman/imberman/katrina_medians.dta, _merge(_mergekatmedian) nokeep
  foreach var of varlist katrina_frac_* katrina_count_* {
    replace `var' = 0 if `var' == .
  }
  */
  * ---- Merge incumbent pre-Katrina achievement quartiles (BASELINE ACHIEVEMENT QUARTILES) ----
  sort id year
  merge id year using /work/i/imberman/imberman/pre_katrina_quartiles.dta, _merge(_mergequartile) nokeep   // PATH: repoint to your local globals


  *GENERATE GRADE X YEAR INTERACTIONS AND SCHOOL DUMMIES
  xi i.grade*i.year

  *DISPLAY GRADE LEVEL IN LOG FILE
  di " "
  di "`grade'"
  di " "

  *COUNTER FOR DEPENDENT VARIABLE
  local depvarid 0



*RUN LINEAR MODEL


  di ""
  di "POOLED LINEAR MODEL"
  di ""
  * ---- Pooled VA model on statewide-std scores, school FE (Table 3 / Table 10 pooled row) ----
  # delimit ;

	areg taks_sdstate_min_math  katrina_frac_grade  ltaks_sdstate_min_math_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if taks_sd_min_math_quartile != ., cluster(campus) absorb(campus);

	areg taks_sdstate_min_read  katrina_frac_grade  ltaks_sdstate_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* if taks_sd_min_read_quartile != ., cluster(campus) absorb(campus);

  foreach var of varlist  perc_attn infractions {;
	areg `var'  katrina_frac_grade  l`var'_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* , cluster(campus) absorb(campus);
  };
  # delimit cr


 * ---- Re-estimate within each baseline achievement quartile (Table 3 / Table 10 quartile rows) ----
 *LOOP OVER QUARTILES
 foreach quartile of numlist 1/4 {

  di ""
  di "QUARTILE `quartile'"
  di ""

  # delimit ;
  *LOOP OVER DEPENDENT VARIABLES;

     ***ALL KATRINA****;
    	

		areg taks_sdstate_min_math katrina_frac_grade  ltaks_sdstate_min_math_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if taks_sd_min_math_quartile == `quartile', cluster(campus) absorb(campus);

		areg taks_sdstate_min_read katrina_frac_grade  ltaks_sdstate_min_read_* female ethnicit_1-ethnicit_4 econdis_2-econdis_4 _I* 
			if taks_sd_min_read_quartile == `quartile', cluster(campus) absorb(campus);





*CLOSE QUARTILE LOOP;
};



*CLOSE GRADELEVEL LOOP;
};



