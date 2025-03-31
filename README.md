# OMOP/ORDR(D) ELIXHAUSER CALCULATION README  
This repository contains code developed by the TraCS Data Science Lab, which is part of the School of Medicine at the University of North Carolina at Chapel Hill.

## Elixhauser Index Background    
Elixhauser et al. (1998) developed the Elixhauser Index as an attempt to define a comprehensive set of comorbidities using administrative data to explore the effect on hospital resource use and in-hospital deaths. By including 30 categories, this was meant to provide a broader view on comorbidities than Charlson et al. (1987). Quan et al. (2005) updated the ICD codes provided in Elixhauser et al. (1998) to include ICD-10 codes. Elixhauser et al. (1998) did not combine the comorbidities into a summary index. However, van Walraven et al. (2009) modified the Elixhauser Index by developing a scoring system based on hospital deaths. 

Charlson et al. (1987) was originally developed and validated based on its ability to predict 1- and 10-year mortality. In contrast, Elixhauser et al. (1998) was originally developed based on associations with length of hospital stay, hospital charges, and in-hospital mortality. Despite these originally intended uses, both Charlson and Elixhauser indices have been widely used as a general indication of patient health. A number of studies have compared the performance of the Elixhauser and Charlson indices for in-hospital mortality (Cai et al. 2020, Menendez et al. 2014), nursing-sensitive outcomes (Kim and Bae 2023), and cancer survival (Chang et al. 2016), amongst many other outcomes. Some researchers prefer the Charlson Index because of its relative simplicity with fewer conditions to consider and original focus on long-term mortality, while some prefer the Elixhauser Index because of its inclusion of a wider range of comorbid conditions and focus on short-term outcomes. 

## Structure of this Repo
We provide Python, R, and PostgreSQL programs to calculate the Elixhauser Index. All execute the same logic outlined below and have been confirmed to return the same results. 

## Code Source Environment Notes
This code is designed to work on Observational Medical Outcomes Partnerships (OMOP) databases. We utilized the OMOP Common Data Model v5.3 for development in the University of North Carolina at Chapel Hill de-identified OMOP Research Data Repository, ORDR(D).

## Methods Applied in this Calculation
We use the 31 conditions listed with ICD-9 and ICD-10 codes from Quan et al. (2005). This is a slight modification from Elixhauser et al. (1998) to separate Hypertension into uncomplicated and complicated categories. We include both ICD-9 and ICD-10 diagnoses.

To calculate the index, we collect ICD diagnoses listed under *condition_source_value* from the *condition_occurrence table*. We then compare the diagnoses codes to the ICD codes listed in Quan et al. (2005) to assign each diagnosis code to a comorbid condition. Each category can only count once for the final index score. We use the weights described in van Walraven et al. (2009) to calculate a summary score. We note that a number of the conditions included in Elixhauser et al. (1998) are assigned a weight of 0 in van Walraven et al. (2009). In this implementation, we still identify those conditions so that this code can be easily modified if different weights are desired. 

As described in Table 1 of Elixhauser et al. (1998), there are two condition groups that have a hierarchy. If both ‘diabetes, uncomplicated’ and ‘diabetes, complicated’ appear, we only keep the ‘diabetes complicated’ diagnosis. Likewise, if both ‘metastatic cancer’ and ‘solid tumor without metastasis’ appear, we only keep the ‘metastatic cancer’ diagnosis. The final index is the sum of the weights for each condition present for each patient over the analysis time period. The code used in this repo to calculate the Elixhauser Index considers all the problem list diagnoses a patient has had. Other use cases may require a different time period of assessment, which is discussed below.

## Limitations/Calculation Aspects to Consider
The Elixhauser Index was originally developed using administrative data and has never been validated in EHR data, though it has been widely adopted and used. 

In EHR data, there are multiple sources of diagnoses. We chose to source our diagnoses solely from the EHR Problem List. We consider the Problem List to be the most accurate representation of conditions across the entire database. 

We emphasize that, even though the data is in OMOP, we use the *condition_source_value* field to retrieve ICD-9 and ICD-10 codes. We do not use *condition_source_concept_id*, which contains mapped SNOMED-CT codes. The use of SNOMED-CT codes is known to deliver higher values of the Charlson Comorbidity Index compared to the use of ICD codes in EHR data (see Viernes et al. 2020; Fortin 2021; Leese et al. 2023). While we are not aware of a similar analysis for the application of the Elixhauser Index, the similarity in how Charlson and Elixhauser are calculated makes it likely they will show the same effect.

Depending on the intended use case, there are different preferences about what date ranges to include for an Elixhauser Index calculation. For simplicity and the intended general use, we include all diagnoses over a lifespan. We exclude conditions that have start dates before the birth date of that patient. 

If you need to filter the diagnosis date globally, across the whole database, here is some code and guidance to implement that for each language:
- SQL: In the first common table expression, condition_start_date, uncomment and edit the following two lines at the end of the expression
  - AND vco.condition_start_date >= '2015-01-03'
  - AND vco.condition_start_date < '2016-01-03'
- Python: There is a subsection titled Query With Date that provides guidance and code. 
- R: See the comments in the code just before the condition_query is defined. 

More advanced filtering, such as based on individual diagnoses dates, is beyond the scope of what we provide, but we hope this code provides a useful starting point.

We use the following categories and weights: 

| Condition Name                                | Weight |
|-----------------------------------------------|--------|
| Congestive heart failure                      | 7      |
| Cardiac Arrhythmias                           | 5      |
| Valvular disease                              | -1     |
| Pulmonary circulation disorders               | 4      |
| Peripheral vascular disorders                 | 2      |
| Hypertension, uncomplicated                   | 0      |
| Hypertension, complicated                     | 0      |
| Paralysis                                     | 7      |
| Other neurological disorders                  | 6      |
| Chronic pulmonary disease                     | 3      |
| Diabetes, uncomplicated                       | 0      |
| Diabetes, complicated                         | 0      |
| Hypothyroidism                                | 0      |
| Renal failure                                 | 5      |
| Liver disease                                 | 11     |
| Peptic ulcer disease excluding bleeding       | 0      |
| AIDS/HIV                                      | 0      |
| Lymphoma                                      | 9      |
| Metastatic cancer                             | 12     |
| Solid tumor without metastasis                | 4      |
| Rheumatoid arthritis/collagen vascular diseases| 0      |
| Coagulopathy                                  | 3      |
| Obesity                                       | -4     |
| Weight loss                                   | 6      |
| Fluid and electrolyte disorders               | 5      |
| Blood loss anemia                             | -2     |
| Deficiency anemia                             | -2     |
| Alcohol abuse                                 | 0      |
| Drug abuse                                    | -7     |
| Psychoses                                     | 0      |
| Depression                                    | -3     |

Some specific notes on ICD codes: 
- We search the EHR for both ICD-9 and ICD-10 codes. You can find the codes associated with each condition both in the program files and Table 2 of (Quan et al. 2005).
- There are 11 ICD-9 codes (V45.0, V53.3, V42.2, V43.3, V43.4, V42.0, V45.1, V56.x, V42.7, V11.3, V65.42) that also correspond to valid ICD-10 codes that are not a comorbid condition. For these codes, we check that the source is ICD-9. 
- We do not double count the same condition, so if a patient has multiple diagnoses for congestive heart failure, for example, that condition is counted a single time. 
- There are 40 ICD codes that are listed twice in (Quan et al. 2005). These are listed in the table below. Some codes are repeated identically while some are captured by different levels of specificity in the ICD code. If a patient has one of these ICD codes, we give them a score for both diseases, pending the hierarchical relationship described above.  

| ICD-9 or -10 code | More specific version (if applicable) |
|-------------------|---------------------------------------|
| 296.5             | 296.54                                |
| 334               | 334.1                                 |
| 402               | 402.01, 402.11, 402.91                |
| 403               | 403.01, 403.11, 403.91                |
| 404               | 404.01, 404.02, 404.03, 404.11, 404.12, 404.13, 404.91, 404.92, 404.93 |
| 404.03            | -                                     |
| 404.13            | -                                     |
| 404.93            | -                                     |
| 416               | 416.8, 416.9                          |
| 425.5             | -                                     |
| 571               | 571.0, 571.1, 571.2, 571.3            |
| F31.5             | -                                     |
| G11               | G11.4                                 |
| I11               | I11.0                                 |
| I12               | I12.0                                 |
| I13               | I13.0, I13.1, I13.2                   |
| I27               | I27.8, I27.9                          |
| I42.6             | -                                     |
| K70               | K70.0, K70.3, K70.9                   |

## Authors
Josh Fuchs and Nathan Foster developed this code. 

## Support
The project described was supported by the National Center for Advancing Translational Sciences (NCATS), National Institutes of Health, through Grant Award Number UM1TR004406. The content is solely the responsibility of the authors and does not necessarily represent the official views of the NIH.

## References
- Cai, Miao, Echu Liu, Ruihua Zhang, Xiaojun Lin, Steven E. Rigdon, Zhengmin Qian, Rhonda Belue, and Jen-Jen Chang. 2020. “Comparing the Performance of Charlson and Elixhauser Comorbidity Indices to Predict In-Hospital Mortality among a Chinese Population.” Clinical Epidemiology 12 (March): 307–16.
- Chang, Heng-Jui, Po-Chun Chen, Ching-Chieh Yang, Yu-Chieh Su, and Ching-Chih Lee. 2016. “Comparison of Elixhauser and Charlson Methods for Predicting Oral Cancer Survival.” Medicine 95 (7): e2861.
- Charlson, M. E., P. Pompei, K. L. Ales, and C. R. MacKenzie. 1987. “A New Method of Classifying Prognostic Comorbidity in Longitudinal Studies: Development and Validation.” Journal of Chronic Diseases 40 (5): 373–83.
- Elixhauser, A., C. Steiner, D. R. Harris, and R. M. Coffey. 1998. “Comorbidity Measures for Use with Administrative Data.” Medical Care 36 (1): 8–27.
- Fortin, Stephen P. 2021. “Predictive Performance of the Charlson Comorbidity Index: SNOMED CT Disease Hierarchy Versus International Classification of Diseases.” In 2021 OHDSI Global Symposium Showcase. https://www.ohdsi.org/wp-content/uploads/2021/08/38-Predictive-Performance-of-the-Charlson-Comorbidity-Index-SNOMED-CT-Disease-Hierarchy-Versus-International-Classification-of-Diseases_2021symposium.pdf.
- Kim, Chul-Gyu, and Kyun-Seop Bae. 2023. “A Comparison of the Charlson and Elixhauser Methods for Predicting Nursing Indicators in Gastrectomy with Gastric Cancer Patients.” Healthcare (Basel, Switzerland) 11 (13): 1830.
- Menendez, Mariano E., Valentin Neuhaus, C. Niek van Dijk, and David Ring. 2014. “The Elixhauser Comorbidity Method Outperforms the Charlson Index in Predicting Inpatient Death after Orthopaedic Surgery.” Clinical Orthopaedics and Related Research 472 (9): 2878–86.
- Peter J Leese, Robert F Chew, Emily Pfaff. 2023. “Charlson Comorbidity in OMOP: An N3C RECOVER Study.” In AMIA 2023 Annual Symposium.
- Quan, Hude, Vijaya Sundararajan, Patricia Halfon, Andrew Fong, Bernard Burnand, Jean-Christophe Luthi, L. Duncan Saunders, Cynthia A. Beck, Thomas E. Feasby, and William A. Ghali. 2005. “Coding Algorithms for Defining Comorbidities in ICD-9-CM and ICD-10 Administrative Data.” Medical Care 43 (11): 1130–39.
- Viernes, Mph Benjamin, Phd Kristine E. Lynch, Mph Brian Robison, Mph Elise Gatsby, Phd Scott L. DuVall, and M. D. Michael E. Matheny. 2020. “SNOMED CT Disease Hierarchies and the Charlson Comorbidity Index (CCI): An Analysis of OHDSI Methods for Determining CCI.” In 2020 OHDSI Global Symposium Showcase. https://www.ohdsi.org/wp-content/uploads/2020/10/Ben-Viernes-Benjamin-Viernes_CCIBySNOMED_2020Symposium.pdf.
- Walraven, Carl van, Peter C. Austin, Alison Jennings, Hude Quan, and Alan J. Forster. 2009. “A Modification of the Elixhauser Comorbidity Measures into a Point System for Hospital Death Using Administrative Data.” Medical Care 47 (6): 626–33.
