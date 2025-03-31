-- Elixhauser Comorbidity Index - SQL

-- This calculation of the Elixhauser Comorbidity Index has been 
-- designed to work on the OMOP CDM v5.3 and developed in the University 
-- of North Carolina at Chapel Hill de-identified OMOP Research Data 
-- Repository, ORDR(D). Please see the README in the repo with important
-- notes, clarifications, and assumptions.

-- Author: Josh Fuchs

-- Copyright 2025, The University of North Carolina at Chapel Hill. 
-- Permission is granted to use in accordance with the MIT license. The code is licensed under the open-source MIT license.


--DROP TABLE IF EXISTS elixhauser;

--CREATE TABLE elixhauser AS

-- First, join bith dates for each person to condition_occurrence table,
-- then only keep conditions that are (1) from the problem list and
-- (2) when condition start date is on or after the birth date

WITH condition_start_filter AS (
	SELECT vco.*
	FROM omop.v_condition_occurrence as vco
	LEFT JOIN omop.person AS p
	ON vco.person_id = p.person_id
	WHERE condition_type_concept_id = 32840 --EHR problem list
	-- only keep conditions with start date on or after birth date
		AND (vco.condition_start_date - p.birth_datetime::date) >= 0 
	-- use the following two lines if you want to restrict dates
	-- for the computation of Elixhauser
	--and vco.condition_start_date >= '2015-01-03' 
	--AND vco.condition_start_date < '2016-01-03'
),

-- Now, select use ICD-9 and 10 codes to group conditions into
-- the categories set by Quan et al (2005). We assign these categories
-- as 1 to 31 and any diagnoses not in a category as 0. 

conditions AS (
	SELECT DISTINCT
	person_id,
	condition_start_date,
	condition_end_date,
	condition_source_value,
	condition_source_concept_vocabulary_id,
--Congestive heart failure--
	CASE WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I43','I50','428') THEN 1
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I099','I110','I130','I132','I255','I420',
																			'I425','I426','I427','I428','I429','P290',
																		 	'4254','4255','4256','4257','4258','4259') THEN 1
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('39891','40201','40211','40291','40401','40403',
																			'40411','40413','40491','40493') THEN 1

--Cardiac arrhythmias--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I47','I48','I49')  THEN 2 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I441','I442','I443','I456','I459','R000','R001',
																		 'R008','T821','Z450','Z950','4260','4267','4269',
																		 '4270','4271','4272','4273','4274','4276','4277',
																		 '4278','4279','7850','V450','V533')  THEN 2
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('42613','42610','42612','99601','99604') THEN 2

--valvular disease--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I05','I06','I07','I08','I34','I35','I36','I37','I38',
																		 'I39','0932','394','395','396','397','424')  THEN 3 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('A520','I091','I098','Q230','Q231','Q232','Q233','Z952',
																		  'Z953','Z954','7463','7464','7465','7466','V422','V433')  THEN 3

--pulmonary circulation disorders--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I26','I27','416')  THEN 4 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I280','I288','I289','4150','4151','4170','4178','4179')  THEN 4

--peripheral vascular disorders--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I70','I71','440','441')  THEN 5 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I731','I738','I739','I771','I790','I792','K551','K558',
																		 'K559','Z958','Z959','0930','4373','4431','4432','4433',
																		 '4434','4435','4436','4437','4438','4439','4471','5571',
																		 '5579','V434')  THEN 5
--hypertension uncomplicated--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I10','401')  THEN 6 

--hypertension complicated--
-- we skip condition 404, but search for it in the next CTE
-- because it is duplicated mutliple times in different specifities
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I11','I12','I13','I15','402','403','405')  THEN 7 

--paralysis--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('G81','G82','342','343')  THEN 8 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('G041','G114','G801','G802','G830','G831','G832',
																		 'G833','G834','G839','3341','3440','3441','3442',
																		 '3443','3444','3445','3446','3449')  THEN 8

--other neurological disorders--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('G10','G11','','G12','G13','G20','G21','G22','G32',
																		  'G35','G36','G37','G40','G41','R56','334','335',
																		 '340','341','345')  THEN 9 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('G254','G255','G312','G318','G319','G931','G934',
																		 'R470','3319','3320','3321','3334','3335','3362',
																		 '3481','3483','7803','7843')  THEN 9
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('33392') THEN 9

--chronic pulmonary disease--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('J40','J41','J42','J43','J44','J45','J46',
																		 'J47','J60','J61','J62','J63','J64','J65',
																		  'J66','J67','490','491','492','493','494',
																		 '495','496','497','498','499','500','501',
																		 '502','503','504','505')  THEN 10 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I278','I279','J684','J701','J703','4168',
																		  '4169','5064','5081','5088')  THEN 10

--diabetes uncomplicated--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('E100','E101','E109','E110','E111','E119','E120',
																		 'E121','E129','E130','E131','E139','E140','E141',
																		 'E149','2500','2501','2502','2503')  THEN 11

--diabetes complicated--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('E102','E103','E104','E105','E106','E107',
																		 'E108','E112','E113','E114','E115','E116',
																		 'E117','E118','E122','E123','E124','E125',
																		 'E126','E127','E128','E132','E133','E134',
																		 'E135','E136','E137','E138','E142','E143',
																		 'E144','E145','E146','E147','E148','2504',
																		 '2505','2506','2507','2508','2509')  THEN 12

--hypothyroidism--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('E00','E01','E02','E03','243','244')  THEN 13 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('E890','2409','2461','2468')  THEN 13

--renal failure--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('N18','N19','585','586','V56')  THEN 14 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I120','I131','N250','Z490','Z491','Z492',
																		 'Z940','Z992','5880','V420','V451')  THEN 14
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('40301','40311','40391','40402','40403','40412',
																		 '40413','40492','40493') THEN 14

--liver disease--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('B18','I85','K70','K72','K73','K74','570',
																		 '571')  THEN 15 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I864','I982','K711','K713','K714','K715',
																		 'K717','K760','K762','K763','K764','K765',
																		 'K766','K767','K768','K769','Z944','0706',
																		 '0709','4560','4561','4562','5722','5723',
																		 '5724','5725','5726','5727','5728','5733',
																		 '5734','5738','5739','V427')  THEN 15
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('07022','07023','07032','07033','07044',
																		 '07054','') THEN 15

--peptic ulcer disease--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('K257','K259','K267','K269','K277',
																		 'K279','K287','K289','5317','5319',
																		  '5327','5329','5337','5339','5347',
																		  '5349')  THEN 16

--AIDS/HIV--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('B20','B21','B22','B24',
																		  '042','043','044')  THEN 17 

--lymphoma--			 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('C81','C82','C83','C84','C85',
																		 'C88','C96','200','201','202')  THEN 18 
		 WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('C900','C902','2030','2386')  THEN 18

--metastatic cancer--	
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('196','197','198','199',
																		 'C77','C78','C79','C80') THEN 19 

--solid tumor without metastasis--	 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('140','141','142','143','144','145','146',
																		 '147','148','149','150','151','152','153',
																			'154','155','156','157','158','159','160',
																		 	'161','162','163','164','165','166','167',
																		 	'168','169','170','171','172','174','175',
																		 	'176','177','178','179','180','181','182',
																		 	'183','184','185','186','187','188','189',
																		 	'190','191','192','193','194','195',
																			'C00','C01','C02','C03','C04','C05','C06',
																		 	'C07','C08','C09','C10','C11','C12','C13',
																		 	'C14','C15','C16','C17','C18','C19','C20',
																		 	'C21','C22','C23','C24','C25','C26','C30',
																		 	'C31','C32','C33','C34','C37','C38','C39',
																		 	'C40','C41','C43','C45','C46','C47','C48',
																		 	'C49','C50','C51','C52','C53','C54','C55',
																		 	'C56','C57','C58','C60','C61','C62','C63',
																		 	'C64','C65','C66','C67','C68','C69','C70',
																		 	'C71','C72','C73','C74','C75','C76','C97') THEN 20
																			 

--rheumatoid arthritis/collagen vascular diseases--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('M05','M06','M08','M30','M32','M33','M34','M35',
																		 'M45','446','714','720','725')  THEN 21 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('L940','L941','L943','M120','M123','M310','M311',
																		 'M312','M313','M461','M468','M469','7010','7100',
																		 '7101','7102','7103','7104','7108','7109','7112',
																		 '7193','7285')  THEN 21
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('72889','72930') THEN 21

--coagulopathy--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('D65','D66','D67','D68','286')  THEN 22 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('D691','D693','D694','D695','D696','2871',
																		 '2873','2874','2875')  THEN 22

--obesity--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('E66')  THEN 23 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('2780')  THEN 23

--weight loss--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('E40','E41','E42','E43','E44','E45',
																		 'E46','R64','260','261','262','263')  THEN 24 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('R634','7832','7994')  THEN 24

--fluid and electrolyte disorders--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('E86','E87','276')  THEN 25 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('E222','2536')  THEN 25

--blood loss anemia--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('D500','2800')  THEN 26

--deficiency anemia--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('D51','D52','D53','281')  THEN 27 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('D508','D509','2801','2802','2803',
																	  	'2804','2805','2806','2807','2808',
																		'2809')  then 27

--alcohol abuse--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('F10','E52','T51','980')  THEN 28 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('G621','I426','K292','K700','K703',
																		 'K709','Z502','Z714','Z721','2652',
																		 '2911','2912','2913','2915','2916',
																		 '2917','2918','2919','3030','3039',
																		 '3050','3575','4255','5353','5710',
																		 '5711','5712','5713','V113')  THEN 28

--drug abuse--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('F11','F12','F13','F14','F15','F16','F18',
																		  'F19','292','304')  THEN 29 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('Z715','Z722','3052','3053','3054','3055',
																		 '3056','3057','3058','3059')  THEN 29
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('V6542') THEN 29
	
--psychoses-- 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('F20','F22','F23','F24','F25','F28','F29',
																		 '295','297','298')  THEN 30 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('F302','F312','F315','2938')  THEN 30
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('29604','29614','29644','29654') THEN 30

--depression--			 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('F32','F33','309','311')  THEN 31 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('F204','F313','F314','F315','F341','F412',
																		 'F432','2962','2963','2965','3004')  THEN 31
		ELSE 0 END AS comorbidity_group
	FROM condition_start_filter 
),

-- now add in rows for cases when the conditons need to be double counted across
-- multiple conditions. 
-- the condition listed in the conditions table will be the lower number in the condition
-- list (i.e. 1-31), so here we add the higher number. See README for full list of conditions. 

conditions_expanded AS (
	SELECT *
	FROM conditions
	UNION ALL
	SELECT person_id,
	condition_start_date,
	condition_end_date,
	condition_source_value,
	condition_source_concept_vocabulary_id,
	-- look for these conditions in the conditions table, then replace the condition number
	CASE 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('40301','40311','40391') THEN 14
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I131','I120') THEN 14 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I11','402','404','I13') THEN 7
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('G11','334') THEN 9
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I426','4255','5710','5711','5712','5713') THEN 28
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('F315') THEN 31
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('2965') THEN 31
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('40201','40211','40291') THEN 7
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('K700','K703','K709') THEN 28
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('I278','I279','4168','4169') THEN 10
		ELSE 0 END AS comorbidity_group
	FROM condition_start_filter
	WHERE CASE
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,3) IN ('I11','G11','334','402','404',
																		'I13') THEN 1
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,4) IN ('2965','I426','4255','F315',
																		'I131','K700','K703','K709',
																		'I278','I279','4168','4169',
																		'5710','5711','5712','5713',
																		'I120') THEN 1
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('40301','40311','40391',
																		'40201','40211','40291') THEN 1
		ELSE 0 END=1
	UNION ALL
	SELECT person_id,
	condition_start_date,
	condition_end_date,
	condition_source_value,
	condition_source_concept_vocabulary_id,
	-- Look for these conditions in the conditions table, then replace the condition number
	-- We need another UNION specifically for these 404.x codes
	CASE 
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('40403','40413','40493') THEN 14
		ELSE 0 END AS comorbidity_group
	FROM condition_start_filter
	WHERE CASE
		WHEN SUBSTRING(TRANSLATE(condition_source_value,'.',''),1,5) IN ('40403','40413','40493') THEN 1
		ELSE 0 END=1
),


-- now remove rows where the following condition corresponds
-- to ICD10 codes: V45.0, V53.3, V42.2, V43.3, V43.4, V42.0, V45.1, V56.x, V42.7, V11.3, V65.42
-- in Quan 2005 these are ICD-9 codes
conditions_expanded_filtered AS (
	SELECT *
	FROM conditions_expanded
	WHERE NOT ((TRANSLATE(condition_source_value,'.','') LIKE 'V450%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V533%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V422%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V433%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V434%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V420%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V451%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V56%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V427%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V113%' OR
			  TRANSLATE(condition_source_value,'.','') LIKE 'V6542%')
		  AND condition_source_concept_vocabulary_id = 'ICD10CM')
),

-- now we need to remove duplicate comorbidity_group so we don't
-- double count conditions
-- AND those comorbidity_group that are 0 (not a commorbid condition)
no_duplicate_conditions AS (
	SELECT DISTINCT person_id, comorbidity_group 
	FROM conditions_expanded_filtered
	WHERE comorbidity_group > 0
),

-- now check for conditional hierarchy. if a patient has
-- both uncomplicated (11) and complicated diabetes (12), 
-- keep only complicated (12)
hierarchy1 AS (
	SELECT *
	FROM no_duplicate_conditions
	WHERE NOT (comorbidity_group = 11
	AND person_id IN (
	SELECT person_id
	FROM no_duplicate_conditions
	WHERE comorbidity_group = 12))
),

-- same for cancers
-- if person has both metastatic (19) and non-metastatic cancer (20),
-- keep only metastatic (19)
hierarchy2 AS (
	SELECT *
	FROM hierarchy1
	WHERE NOT (comorbidity_group = 20
	AND person_id IN (
	SELECT person_id
	FROM hierarchy1
	WHERE comorbidity_group = 19))
),

-- now add in the weights for each comorbidity_group
-- using the weights from van Walraven et al. (2009)
weights AS (
	SELECT person_id,
	comorbidity_group,
--Congestive heart failure--
	CASE WHEN comorbidity_group = 1 THEN 7

--Cardiac arrhythmias--			 
		WHEN comorbidity_group = 2 THEN 5

--valvular disease--			 
		WHEN comorbidity_group = 3 THEN -1

--pulmonary circulation disorders--			 
		WHEN comorbidity_group = 4 THEN 4

--peripheral vascular disorders--			 
		WHEN comorbidity_group = 5 THEN 2
	
--hypertension uncomplicated--			 
		WHEN comorbidity_group = 6 THEN 0

--hypertension complicated--
		WHEN comorbidity_group = 7 THEN 0

--paralysis--			 
		WHEN comorbidity_group = 8 THEN 7

--other neurological disorders--			 
		WHEN comorbidity_group = 9 THEN 6

--chronic pulmonary disease--			 
		WHEN comorbidity_group = 10 THEN 3

--diabetes uncomplicated--			 
		WHEN comorbidity_group = 11 THEN 0

--diabetes complicated--			 
		WHEN comorbidity_group = 12 THEN 0

--hypothyroidism--			 
		WHEN comorbidity_group = 13 THEN 0

--renal failure--			 
		WHEN comorbidity_group = 14 THEN 5

--liver disease--			 
		WHEN comorbidity_group = 15 THEN 11

--peptic ulcer disease--			 
		WHEN comorbidity_group = 16 THEN 0

--AIDS/HIV--			 
		WHEN comorbidity_group = 17 THEN 0

--lymphoma--			 
		WHEN comorbidity_group = 18 THEN 9

--metastatic cancer--	
		WHEN comorbidity_group = 19 THEN 12

--solid tumor without metastasis--	 
		WHEN comorbidity_group = 20 THEN 4

--rheumatoid arthritis/collagen vascular diseases--			 
		WHEN comorbidity_group = 21 THEN 0

--coagulopathy--			 
		WHEN comorbidity_group = 22 THEN 3

--obesity--			 
		WHEN comorbidity_group = 23 THEN -4

--weight loss--			 
		WHEN comorbidity_group = 24 THEN 6

--fluid and electrolyte disorders--			 
		WHEN comorbidity_group = 25 THEN 5

--blood loss anemia--			 
		WHEN comorbidity_group = 26 THEN -2

--deficiency anemia--			 
		WHEN comorbidity_group = 27 THEN -2

--alcohol abuse--			 
		WHEN comorbidity_group = 28 THEN 0

--drug abuse--			 
		WHEN comorbidity_group = 29 THEN -7
	
--psychoses-- 
		WHEN comorbidity_group = 30 THEN 0

--depression--			 
		WHEN comorbidity_group = 31 THEN -3

		ELSE 0 END AS condition_weights

	FROM hierarchy2
)

-- finally, sum the number of conditions for each individual
-- to get their index value
SELECT person_id, SUM(condition_weights) AS elixhauser_score
FROM weights
GROUP BY person_id
;