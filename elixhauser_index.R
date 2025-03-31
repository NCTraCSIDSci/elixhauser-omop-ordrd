# Elixhauser Comorbidity Score

# This calculation of the Elixhauser Comorbidity Index has been designed to work
# on the OMOP CDM v5.3 and developed in the University of North Carolina at 
# Chapel Hill de-identified OMOP Research Data Repository, ORDR(D). Please see 
# the README in the repo with important notes, clarifications, and assumptions.

# Author: Nathan Foster

# Copyright 2025, The University of North Carolina at Chapel Hill. 
# Permission is granted to use in accordance with the MIT license. The code 
# is licensed under the open-source MIT license.

# Set username and password
username = 'user'
pw = 'password'

# Load libraries
library(RPostgreSQL)
library(DBI)
library(tidyverse)
library(jsonlite)


# Helper Functions

#There are some conditions that are listed with different levels of specificity 
#(i.e. I11 and I11.0) in Quan et al. (2005). This function identifies the long 
#version of the conditions in the dataframe (like I11.0), and adds in rows with 
#the shorter condition (like I11). 

# For example, if both I11.0 and I11 are listed as conditions, I11.0 will be
# in the returned query from the database and this function will add in I11.  
duplicate_certain_codes <- function(df) {
  
    duplicate_codes <- list(
        list("replacement" = 'I11', "codes" = list('I110')),
        list("replacement" = 'I13', "codes" = list('I130','I132','I131')),
        list("replacement" = 'I12', "codes" = list('I120')),
        list("replacement" = 'I27', "codes" = list('I278','I279')),
        list("replacement" = 'K70', "codes" = list('K700','K703','K709')),
        list("replacement" = '2965', "codes" = list('29654')),
        list("replacement" = 'G11', "codes" = list('G114')),
        list("replacement" = '334', "codes" = list('3341')),
        list("replacement" = '404', "codes" = list('40401','40402','40403','40411','40412','40413','40491','40492','40493')),
        list("replacement" = '403', "codes" = list('40301','40311','40391')),
        list("replacement" = '402', "codes" = list('40201','40211','40291')),
        list("replacement" = '416', "codes" = list('4168','4169')),
        list("replacement" = '571', "codes" = list('5710','5711','5712','5713'))
    )
    
    get_duplicates <- list()
    
    for(i in 1:length(duplicate_codes)) {
        get_duplicates <- append(get_duplicates, duplicate_codes[[i]]$"codes")
    }
    
    # Get all rows with these condition codes
    duplicate_df <- filter(df, condition_source_value %in% get_duplicates)
    
    for(i in 1:length(duplicate_codes)) {
        for (j in 1:length(duplicate_codes[[i]]$"codes")) {
            duplicate_df['condition_source_value'][duplicate_df['condition_source_value'] == duplicate_codes[[i]]$"codes"[[j]]] <- duplicate_codes[[i]]$replacement
        }
    }
    
    # Add these rows back to the DataFrame, now with the replacement codes
    df <- union(df, duplicate_df)
    
    return(df)
}

# The codes V45.0, V53.3, V42.2, V43.3, V43.4, V42.0, V45.1, V56, V42.7, V11.3, 
# and V65.42 can correspond to different conditions whether they are in ICD9 or
# ICD10. For Elixhauser, they should be ICD9 codes (per Quan 2005). Therefore, 
# remove rows where the condition is one of those and the source vocabulary 
# is ICD10CM. 
remove_certain_icd10_codes <- function(df) {
    to_remove <- filter(df, condition_source_value %in% c('V450','V533','V422','V433','V434','V420',
                                                          'V451','V56','V427','V113','V6542') &
                            condition_source_concept_vocabulary_id == "ICD10CM")
    
    df <- anti_join(df, to_remove, by = join_by(person_id, condition_source_value, condition_source_concept_vocabulary_id))
    
    return(df)
}

# Check for related conditions:
# We don't double count closely related diseases. Table 1 Footnote B of 
# Elixhauser et al. (1998) gives the algorithm: A hierarchy was established 
# between the following pairs of comorbidities: If both uncomplicated 
# complicated diabetes are present, count only complicated diabetes. If both 
# solid tumor without metastatis and metastatic cancer are present, count only 
# metastatic cancer.
remove_related_conditions <- function(df) {
    diabetes_uncomplicated <- filter(df, condition == "diabetes uncomplicated")
    diabetes_complicated <- filter(df, condition == "diabetes complicated")
    diabetes_uncomplicated <- semi_join(diabetes_uncomplicated, diabetes_complicated, by = c("person_id"))
    
    tumor_without_metastatis <- filter(df, condition == "solid tumor without metastasis")
    metastatic_cancer <- filter(df, condition == "metastatic cancer")
    tumor_without_metastatis <- semi_join(tumor_without_metastatis, metastatic_cancer, by = c("person_id"))
    
    df <- anti_join(df, diabetes_uncomplicated, by = join_by(person_id, condition, weight))
    df <- anti_join(df, tumor_without_metastatis, by = join_by(person_id, condition, weight))
    
    return(df)
}
  
# Parse condition dictionary

# Directly parse the condition_dictionary from a list of lists. 
# This dictionary lists the name of the condition, all corresponding ICD codes,
# and the condition's weight from van Walraven et al. (2009).
# Both ICD-9 and ICD-10 codes from Quan et al. (2005) are included. 
# These have been stripped of periods to make matching easier in the database.
condition_dictionary <- list(
    list("condition"="congestive heart failure", "icd"=list('39891','40201','40211','40291','40401','40403','40411','40413','40491','40493','4254','4255',
                                                            '4256','4257','4258','4259','428','I099','I110','I130','I132','I255','I420','I425','I426','I427',
                                                            'I428','I429','P290','I43','I50'), "weight"=as.integer(7)),
    list("condition"="cardiac arrhythmias", "icd"=list('I441','I442','I443','I456','I459','I47','I48','I49','R000','R001','R008','T821','Z450','Z950',
                                                       '4260','42613','4267','4269','42610','42612','4270','4271','4272','4273','4274','4276','4277',
                                                       '4278','4279','7850','99601','99604','V450','V533'), "weight"=as.integer(5)),
    list("condition"="valvular disease", "icd"=list('A520','I05','I06','I07','I08','I091','I098','I34','I35','I36','I37','I38','I39','Q230','Q231','Q232','Q233',
                                                    'Z952','Z953','Z954','0932','394','395','396','397','424','7463','7464','7465','7466','V422','V433'), "weight"=as.integer(-1)),
    list("condition"="pulmonary circulation disorders", "icd"=list('I26','I27','I280','I288','I289','4150','4151','416','4170','4178','4179'), "weight"=as.integer(4)),
    list("condition"="peripheral vascular disorders", "icd"=list('I70','I71','I731','I738','I739','I771','I790','I792','K551','K558','K559','Z958','Z959',
                                                                 '0930','4373','440','441','4431','4432','4433','4434','4435','4436','4437','4438','4439',
                                                                 '4471','5571','5579','V434'), "weight"=as.integer(2)),
    list("condition"="hypertension uncomplicated", "icd"=list('I10','401'), "weight"=as.integer(0)),
    list("condition"="hypertension complicated", "icd"=list('I11','I12','I13','I15','402','403','404','405'), "weight"=as.integer(0)),
    list("condition"="paralysis", "icd"=list('G041','G114','G801','G802','G81','G82','G830','G831','G832','G833','G834','G839',
                                             '3341','342','343','3440','3441','3442','3443','3444','3445','3446','3449'), "weight"=as.integer(7)),
    list("condition"="other neurological disorders", "icd"=list('G10','G11','G12','G13','G20','G21','G22','G254','G255','G312','G318','G319','G32','G35',
                                                                'G36','G37','G40','G41','G931','G934','R470','R56',
                                                                '3319','3320','3321','3334','3335','33392','334','335','3362','340','341','345','3481',
                                                                '3483','7803','7843'), "weight"=as.integer(6)),
    list("condition"="chronic pulmonary disease", "icd"=list('I278','I279','J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62','J63','J64',
                                                             'J65','J66','J67','J684','J701','J703',
                                                             '4168','4169','490','491','492','493','494','495','496','497','498','499','500','501','502',
                                                             '503','504','505','5064','5081','5088'), "weight"=as.integer(3)),
    list("condition"="diabetes uncomplicated", "icd"=list('E100','E101','E109','E110','E111','E119','E120','E121','E129','E130','E131','E139','E140','E141','E149',
                                                          '2500','2501','2502','2503'), "weight"=as.integer(0)),
    list("condition"="diabetes complicated", "icd"=list('E102','E103','E104','E105','E106','E107','E108','E112','E113','E114','E115','E116','E117','E118',
                                                        'E122','E123','E124','E125','E126','E127',
                                                        'E128','E132','E133','E134','E135','E136','E137','E138','E142','E143','E144','E145','E146','E147','E148',
                                                        '2504','2505','2506','2507','2508','2509'), "weight"=as.integer(0)),
    list("condition"="hypothyroidism", "icd"=list('E00','E01','E02','E03','E890',
                                                  '2409','243','244','2461','2468'), "weight"=as.integer(0)),
    list("condition"="renal failure", "icd"=list('I120','I131','N18','N19','N250','Z490','Z491','Z492','Z940','Z992',
                                                 '40301','40311','40391','40402','40403','40412','40413','40492','40493','585','586','5880','V420','V451','V56'), "weight"=as.integer(5)),
    list("condition"="liver disease", "icd"=list('B18','I85','I864','I982','K70','K711','K713','K714','K715','K717','K72','K73','K74','K760','K762','K763',
                                                 'K764','K765','K766','K767','K768','K769','Z944',
                                                 '07022','07023','07032','07033','07044','07054','0706','0709','4560','4561','4562','570','571','5722','5723','5724','5725',
                                                 '5726','5727','5728','5733','5734','5738','5739','V427'), "weight"=as.integer(11)),
    list("condition"="peptic ulcer disease", "icd"=list('K257','K259','K267','K269','K277','K279','K287','K289',
                                                        '5317','5319','5327','5329','5337','5339','5347','5349'), "weight"=as.integer(0)),
    list("condition"="aids", "icd"=list('B20','B21','B22','B24',
                                        '042','043','044'), "weight"=as.integer(0)),
    list("condition"="lymphoma", "icd"=list('C81','C82','C83','C84','C85','C88','C96','C900','C902',
                                            '200','201','202','2030','2386'), "weight"=as.integer(9)),
    list("condition"="metastatic cancer", "icd"=list('C77','C78','C79','C80',
                                                     '196','197','198','199'), "weight"=as.integer(12)),
    list("condition"="solid tumor without metastasis", "icd"=list('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09',
                                                                  'C10','C11','C12','C13','C14','C15','C16','C17','C18','C19',
                                                                  'C20','C21','C22','C23','C24','C25','C26','C30','C31','C32',
                                                                  'C33','C34','C37','C38','C39','C40','C41','C43','C45','C46',
                                                                  'C47','C48','C49','C50','C51','C52','C53','C54','C55','C56',
                                                                  'C57','C58','C60','C61','C62','C63','C64','C65','C66','C67',
                                                                  'C68','C69','C70','C71','C72','C73','C74','C75','C76','C97',
                                                                  '140','141','142','143','144','145','146','147','148','149',
                                                                  '150','151','152','153','154','155','156','157','158','159',
                                                                  '160','161','162','163','164','165','166','167','168','169',
                                                                  '170','171','172','174','175','176','177','178','179','180',
                                                                  '181','182','183','184','185','186','187','188','189','190',
                                                                  '191','192','193','194','195'), "weight"=as.integer(4)),
    list("condition"="rheumatoid arthritis or collagen vascular diseases", "icd"=list('L940','L941','L943','M05','M06','M08','M120','M123','M30','M310',
                                                                                      'M311','M312','M313','M32','M33',
                                                                                      'M34','M35','M45','M461','M468','M469',
                                                                                      '446','7010','7100','7101','7102','7103','7104','7108','7109','7112',
                                                                                      '714','7193','720','725','7285','72889','72930'), "weight"=as.integer(0)),
    list("condition"="coagulopathy", "icd"=list('D65','D66','D67','D68','D691','D693','D694','D695','D696',
                                                '286','2871','2873','2874','2875'), "weight"=as.integer(3)),
    list("condition"="obesity", "icd"=list('E66',
                                           '2780'), "weight"=as.integer(-4)),
    list("condition"="weight loss", "icd"=list('E40','E41','E42','E43','E44','E45','E46','R634','R64',
                                               '260','261','262','263','7832','7994'), "weight"=as.integer(6)),
    list("condition"="fluid and electrolyte disorders", "icd"=list('E222','E86','E87',
                                                                   '2536','276'), "weight"=as.integer(5)),
    list("condition"="blood loss anemia", "icd"=list('D500',
                                                     '2800'), "weight"=as.integer(-2)),
    list("condition"="deficiency anemia", "icd"=list('D508','D509','D51','D52','D53',
                                                     '2801','2802','2803','2804','2805','2806','2807','2808','2809','281'), "weight"=as.integer(-2)),
    list("condition"="alcohol abuse", "icd"=list('F10','E52','G621','I426','K292','K700','K703','K709','T51','Z502','Z714','Z721',
                                                 '2652','2911','2912','2913','2915','2916','2917','2918','2919','3030','3039','3050',
                                                 '3575','4255','5353','5710','5711','5712','5713','980','V113'), "weight"=as.integer(0)),
    list("condition"="drug abuse", "icd"=list('F11','F12','F13','F14','F15','F16','F18','F19','Z715','Z722',
                                              '292','304','3052','3053','3054','3055','3056','3057','3058','3059','V6542'), "weight"=as.integer(-7)),
    list("condition"="psychoses", "icd"=list('F20','F22','F23','F24','F25','F28','F29','F302','F312','F315',
                                             '2938','295','29604','29614','29644','29654','297','298'), "weight"=as.integer(0)),
    list("condition"="depression", "icd"=list('F204','F313','F314','F315','F32','F33','F341','F412','F432',
                                              '2962','2963','2965','3004','309','311'), "weight"=as.integer(-3))
)

# Convert condition_dictionary to a DataFrame
condition_df <- tibble(condition_dictionary) %>%
    unnest_wider(condition_dictionary)

# Flatten condition_df by making each ICD code its own row
condition_df_long <- condition_df %>%
    unnest_longer(icd)

# Define three strings, one each for ICD codes with length 3, 4, and 5.
# These will be formatted as SQL lists, so that they can be added to the SQL
# query string below. 
con_icd_3 = "("
con_icd_4 = "("
con_icd_5 = "("

# For each ICD code in the dictionary, find its length, and add it to the right list. 
for (i in 1:nrow(condition_df_long)) {
  
    icd_code = condition_df_long$"icd"[i]
  
    if (nchar(icd_code) == 3) {
        con_icd_3 = paste(con_icd_3, "'", icd_code, "', ", sep="")
    } else if (nchar(icd_code) == 4) {
        con_icd_4 = paste(con_icd_4, "'", icd_code, "', ", sep="")
    } else if (nchar(icd_code) == 5) {
        con_icd_5 = paste(con_icd_5, "'", icd_code, "', ", sep="")
    } else{
        print("Unknown ICD Code Present")
    }
}

# Modify the end of the ICD code strings to format them as SQL lists. 
con_icd_3 = paste(str_replace(con_icd_3, ".{2}$", ""), ")", sep="")
con_icd_4 = paste(str_replace(con_icd_4, ".{2}$", ""), ")", sep="")
con_icd_5 = paste(str_replace(con_icd_5, ".{2}$", ""), ")", sep="")


# Query OMOP: open server connection, define the correct query string (using
# string manipulations to sub in the ICD codes above), and query the server. 

# Configure connection to OMOP database
conn = dbConnect(PostgreSQL(),
                 dbname= 'ordrd',
                 host = 'od2-primary',
                 port = 5432,
                 user = username,
                 password = pw)

# Format condition query by substituting in the ICD code strings from above

# If you want to limit the date range considered, you can add the following two 
# lines at the end of the condition_start_filter common table expression: 
# and vco.condition_start_date >= '2015-01-03' 
# and vco.condition_start_date < '2016-01-03'
condition_query = ("\
                    with condition_start_filter as (
                    select  vco.*
                    from omop.v_condition_occurrence as vco
                    left join omop.person as p
                    on vco.person_id = p.person_id
                    where condition_type_concept_id = 32840
                    and (vco.condition_start_date - p.birth_datetime::date) >= 0
                    )    
                    Select DISTINCT person_id, 
                    CASE WHEN substring(translate(condition_source_value,'.',''),1,5) in -2- then substring(translate(condition_source_value,'.',''),1,5) 
                    WHEN substring(translate(condition_source_value,'.',''),1,4) in -1- then substring(translate(condition_source_value,'.',''),1,4) 
                    WHEN substring(condition_source_value,1,3) in -0- then substring(condition_source_value,1,3) 
                    ELSE NULL END AS condition_source_value,
                    condition_source_concept_vocabulary_id
                    FROM condition_start_filter
                    WHERE CASE
                    WHEN substring(condition_source_value,1,3) in -0- then 1
                    when substring(translate(condition_source_value,'.',''),1,4) in -1- then 1 
                    when substring(translate(condition_source_value,'.',''),1,5) in -2- then 1 
                    ELSE 0
                    END = 1;
                    ") %>% 
    str_replace_all("-0-", con_icd_3) %>%
    str_replace_all("-1-", con_icd_4) %>%
    str_replace_all("-2-", con_icd_5)

# Query the database 
person_condition_raw_query <- dbGetQuery(conn, condition_query)

# Transform queried data. The left join will add a small # of rows, because some codes correspond to multiple diseases
person_condition_df_joined <- person_condition_raw_query %>%
    duplicate_certain_codes() %>% 
    remove_certain_icd10_codes() %>%  
    left_join(condition_df_long, 
              by = c("condition_source_value" = "icd"), 
              relationship = "many-to-many")

# Group by person_id, condition_name, and weight, to handle multiple
# different codes for the same condition. Then check for/remove closely related
# conditions. 
person_condition_df_grouped <- person_condition_df_joined %>% 
    group_by(person_id, condition, weight) %>%
    slice_head(n = 1) %>%
    select(person_id, condition, weight) %>%
    remove_related_conditions()

# Group by person_id, summing the weight, to produce the final table. 
elixhauser_weights <- person_condition_df_grouped %>% 
    group_by(person_id) %>%
    summarize(comorbidity_score = sum(weight))

# View(elixhauser_weights)
