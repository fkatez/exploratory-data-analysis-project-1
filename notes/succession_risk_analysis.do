/*==============================================================================
WA OPHTHALMOLOGY WORKFORCE SURVEY - COMPLETE ANALYSIS
Pro-rata normalization of subspecialty percentages + demand analysis
Created: October 2025
==============================================================================*/

clear all
set more off
version 17
set scheme s2color

* Set paths
global inpath "C:\Users\274368d\OneDrive - Curtin\Research\New Projects\2024\Health workforce\Data\Data"
global outpath "C:\Users\274368d\OneDrive - Curtin\Research\New Projects\2024\Health workforce\Outputs\October_25"
global graphs "C:\Users\274368d\OneDrive - Curtin\Research\New Projects\2024\Health workforce\Outputs\Graphs"
cd "$inpath"

* Start log
cap log close
log using "$outpath/02_complete_analysis_log.txt", replace text

use "$outpath/master_ranzco_cleaned.dta", clear

/*==============================================================================
PART 17: WORKFORCE SUCCESSION RISK BY SUBSPECIALTY
==============================================================================*/

preserve
keep if analysis_sample

display _n "=== SUCCESSION RISK ANALYSIS ==="

* Create age groups
gen age_group = ""
replace age_group = "Early-career" if age_clean < 45
replace age_group = "Mid-career" if age_clean >= 45 & age_clean < 55
replace age_group = "Near-retirement" if age_clean >= 55 & !missing(age_clean)

label var age_group "Career stage"

* Calculate FTE by age group for each subspecialty
local subspecs "cataract med_retina surg_retina glaucoma paeds neuro orbit plastics general"

* Initialize results matrix
matrix succession_risk = J(9, 4, .)
local row = 1

foreach sub in `subspecs' {
    * FTE for near-retirement (55+)
    quietly summarize fte_`sub' if age_group == "Near-retirement"
    local fte_senior = r(sum)

    * FTE for early-career (<45)
    quietly summarize fte_`sub' if age_group == "Early-career"
    local fte_junior = r(sum)

    * Calculate succession risk index
    if `fte_junior' > 0 {
        local risk_index = `fte_senior' / `fte_junior'
    }
    else {
        local risk_index = 999  // Flag: no early-career FTE
    }

    * Store in matrix
    matrix succession_risk[`row',1] = `fte_senior'
    matrix succession_risk[`row',2] = `fte_junior'
    matrix succession_risk[`row',3] = `risk_index'

    * Classify risk level (old thresholds - will be replaced)
    local risk_level = 1
    if `risk_index' >= 2 & `risk_index' < 3 {
        local risk_level = 2
    }
    if `risk_index' >= 3 & `risk_index' < 5 {
        local risk_level = 3
    }
    if `risk_index' >= 5 | `risk_index' >= 999 {
        local risk_level = 4
    }

    matrix succession_risk[`row',4] = `risk_level'

    local row = `row' + 1
}

matrix colnames succession_risk = "FTE_55plus" "FTE_under45" "Risk_Index" "Risk_Level"
matrix rownames succession_risk = `subspecs'

display _n "Succession Risk Matrix:"
matlist succession_risk, format(%8.2f)

/*------------------------------------------------------------------------------
Convert to dataset and create visualizations
------------------------------------------------------------------------------*/

clear
svmat succession_risk, names(col)

gen subspecialty = ""
local row = 1
foreach sub in `subspecs' {
    replace subspecialty = "`sub'" in `row'
    local row = `row' + 1
}

* Clean subspecialty labels
gen subspec_label = ""
replace subspec_label = "Cataract"             if subspecialty == "cataract"
replace subspec_label = "Medical Retina"       if subspecialty == "med_retina"
replace subspec_label = "Surgical Retina"      if subspecialty == "surg_retina"
replace subspec_label = "Glaucoma"             if subspecialty == "glaucoma"
replace subspec_label = "Paediatrics"          if subspecialty == "paeds"
replace subspec_label = "Neuro-ophthalmology"  if subspecialty == "neuro"
replace subspec_label = "Orbit"                if subspecialty == "orbit"
replace subspec_label = "Oculoplastics"        if subspecialty == "plastics"
replace subspec_label = "General"              if subspecialty == "general"

* Handle missing/infinite values
replace Risk_Index = . if Risk_Index >= 999

* Drop the old Risk_Level from matrix (used different thresholds)
drop Risk_Level

* Create risk categories with policy-appropriate thresholds
gen risk_category = ""
replace risk_category = "Moderate" if Risk_Index >= 1.5 & Risk_Index < 2.0
replace risk_category = "High"     if Risk_Index >= 2.0 & Risk_Index < 3.0
replace risk_category = "Critical" if Risk_Index >= 3.0 & !missing(Risk_Index)
replace risk_category = "Low"      if missing(risk_category) & !missing(Risk_Index)

* Create NEW numeric level for graphing
gen Risk_Level = .
replace Risk_Level = 0 if risk_category == "Low"
replace Risk_Level = 1 if risk_category == "Moderate"
replace Risk_Level = 2 if risk_category == "High"
replace Risk_Level = 3 if risk_category == "Critical"

* Sort by risk index
gsort -Risk_Index

/*------------------------------------------------------------------------------
Figure 7: Risk-coded dot plot
------------------------------------------------------------------------------*/

gen subspec_order = _n
local num_cats = _N
local y_upper = `num_cats' + 0.5

capture label drop subspec_order_label

quietly {
    forvalues i = 1/`num_cats' {
        local lbl = subspec_label[`i']
        if `i' == 1 {
            label define subspec_order_label `i' "`lbl'"
        }
        else {
            label define subspec_order_label `i' "`lbl'", add
        }
    }
}

label values subspec_order subspec_order_label

quietly summarize Risk_Index
local x_max = ceil(r(max))
if missing(`x_max') {
    local x_max = 3
}
if `x_max' < 3 {
    local x_max = 3
}

local dot_title  `"Succession Risk Index"'
local dot_note1  `"Risk index = FTE 55+ / FTE <45"'
local dot_note2  `"Colour scale: Critical (cranberry), High (orange), Moderate (teal), Low (forest green)"'
local dot_note3  `"Vertical reference lines mark thresholds at 1.0, 2.0, and 3.0"'

twoway ///
    (scatter subspec_order Risk_Index if risk_category == "Critical", ///
        msymbol(O) mcolor(cranberry) msize(large)) ///
    (scatter subspec_order Risk_Index if risk_category == "High", ///
        msymbol(O) mcolor(orange) msize(large)) ///
    (scatter subspec_order Risk_Index if risk_category == "Moderate", ///
        msymbol(O) mcolor(teal) msize(large)) ///
    (scatter subspec_order Risk_Index if risk_category == "Low", ///
        msymbol(O) mcolor(forest_green) msize(large)) ///
    , ///
    title(`dot_title', size(3.5)) ///
    legend(order(1 "Critical (>=3.0)" 2 "High (2.0-2.9)" 3 "Moderate (1.5-1.9)" 4 "Low (<1.5)") ///
        size(2.5) position(6) row(1) region(color(white))) ///
    xline(1, lcolor(gs10) lpattern(dash) lwidth(medium)) ///
    xline(2, lcolor(orange) lpattern(dash) lwidth(medium)) ///
    xline(3, lcolor(cranberry) lpattern(solid) lwidth(thick)) ///
    xlabel(0(1)`x_max', labsize(3)) ///
    ylabel(1(1)`num_cats', valuelabel labsize(3) angle(0)) ///
    yscale(reverse range(0.5 `y_upper')) ///
    ytitle("") ///
    xtitle("Succession Risk Index", size(3.5)) ///
    note(`dot_note1' `dot_note2' `dot_note3', size(2.5) position(6)) ///
    graphregion(color(white) margin(medium)) ///
    plotregion(margin(medium)) ///
    bgcolor(white) ///
    ysize(6) xsize(10)

graph export "$graphs/Figure7_Succession_Risk_Dot.png", replace width(5000) height(3500)
graph export "$graphs/Figure7_Succession_Risk_Dot.pdf", replace

display _n "Figure 7 exported: Succession risk dot plot"

label values subspec_order ""
capture label drop subspec_order_label

restore

log close
