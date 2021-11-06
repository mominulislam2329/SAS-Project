TITLE 'STEP 1';

/*	Defiend Library first and then import data set “organics.csv” to SAS.*/

LIBNAME PRJT 'Z:\OneDrive - South Dakota State University - SDSU\INFS 762\Project 1';
RUN;

/*Removing two variables named “DemCluster” and “TargetAmount” */

/* the code below illustrates how to drop a variable */
DATA PRJT.ORGANICS2;
SET PRJT.ORGANICC;
DROP DEMCLUSTER TARGETAMT;
RUN;

/*First Ten Observations*/
PROC PRINT DATA = PRJT.ORGANICS2(OBS = 10);
RUN;

/*Histogram for the continous variables*/

TITLE 'STEP 2: Histogram for the continous variables';

goptions reset=global
         gunit=pct
         hsize= 10.625 in
         vsize= 8.5 in
         htitle=4
         htext=3
         vorigin=0 in
         horigin= 0 in
         cback=white border
         ctext=black 
         colors=(black blue green red yellow)
         ftext=swiss
         lfactor=3;

proc univariate data=PRJT.ORGANICS2 noprint;
   histogram DemAffl; 
   title2 'Histogram for Affluence grade on a scale from 1 to 30';
run;

proc univariate data=PRJT.ORGANICS2 noprint;
   histogram DemAge; 
   title 'Histogram for Age';
run;

proc univariate data=PRJT.ORGANICS2 noprint;
   histogram PromSpend; 
   title 'Histogram for Total amount spent';
run;

proc univariate data=PRJT.ORGANICS2 noprint;
   histogram PromTime; 
   title 'Histogram for Time as a member';
run;

/*Table Featuring Number of Mssing values, Max, Min and Standard Deviation*/
proc means data = PRJT.ORGANICS2 nmiss N min max mean std;
var DemAffl DemAge PromSpend PromTime;
title 'Table Featuring Number of Mssing values, Max, Min and Standard Deviation';
run; 

/*The sas code for checking the extreme and missing values*/

ODS SELECT EXTREMEVALUES; 
ODS select MissingValues;


PROC UNIVARIATE Data=PRJT.ORGANICS2 NEXTRVAL=10; 
VAR DemAffl DemAge PromSpend PromTime; 
title 'Extreme and Missing values for Continuous Variables';
RUN;

/*Categorical Variable Analysis*/

PROC freq Data=PRJT.ORGANICS2; 
table DemClusterGroup DemGender DemReg DemTVReg PromClass; 
title 'Categorical Variable Analysis';
RUN;


TITLE 'STEP 3: CREATING DUMMY VARIABLES';

/* define a macro to create dummy variables */
%macro DummyVars(DSIn,    /* the name of the input data set */
                 VarList, /* the names of the categorical variables */
                 DSOut);  /* the name of the output data set */
   /* 1. add a fake response variable */
   data AddFakeY / view=AddFakeY;
      set &DSIn;
      _Y = 0;      /* add a fake response variable */
   run;
   /* 2. Create the design matrix. Include the original variables, if desired */
   proc glmselect data=AddFakeY NOPRINT outdesign(addinputvars)=&DSOut(drop=_Y);
      class      &VarList;   
      model _Y = &VarList /  noint selection=none;
   run;
%mend;

%DummyVars(PRJT.ORGANICS2, PROMCLASS, PROMCLASSDUMMY);

PROC FREQ DATA=PROMCLASSDUMMY;
TABLES PROMCLASS*PROMCLASS_GOLD*PROMCLASS_PLATINUM*PROMCLASS_SILVER / LIST;
TITLE 'Dummy Variable Creation ';
RUN;

TITLE 'Missing Value Imputation';

/* Count missing values for numeric variables */
proc means data=PRJT.ORGANICS2 nolabels N NMISS;
var DemAffl DemAge PromSpend PromTime;
run;


/* Median imputation: Used PROC STDIZE to replace missing values with median */

proc stdize data= PRJT.ORGANICS2 out= PRJT.IMPUTED method= median reponly;
var DemAffl DemAge PromTime ;
run;

proc print data=PRJT.IMPUTED(obs = 20);  /*First 20 Observations with imputed missing values */
run;

TITLE 'Step 5: Random Training and Validation Data Set';

data PRJT.SORTED;
set PRJT.IMPUTED;
n=ranuni(20041206);

proc sort data=PRJT.SORTED; by n;

data PRJT.TRAINING PRJT.VALIDATION; /*Training and Validation Data*/
set PRJT.SORTED nobs=nobs;
if _n_<=.60*nobs then output PRJT.TRAINING;
else output PRJT.VALIDATION;
run;

TITLE 'Step 6 :Stepwise Logistic Regression';

proc logistic data=PRJT.TRAINING outest=PRJT.TRAINING_REG covout;
class DemClusterGroup DemGender DemReg DemTVReg PromClass;
model targetBuy(event='1')=DemAffl DemAge DemClusterGroup DemGender DemReg DemTVReg PromClass PromSpend PromTime
                / selection=stepwise  /*Stepwise selection process*/
                  slentry=0.3
                  slstay=0.35 details;
run;



/*Exporting SAS training and validation data set*/
proc export data=PRJT.TRAINING
   outfile='Z:\OneDrive - South Dakota State University - SDSU\INFS 762\Project 1\organic_training.csv' 
   dbms=csv replace; 
run;

proc export data=PRJT.VALIDATION
   outfile='Z:\OneDrive - South Dakota State University - SDSU\INFS 762\Project 1\organic_validation.csv' 
   dbms=csv replace; 
run;

TITLE 'Step 8 :Log Transformation of the Data';

data PRJT.ORGANICLOG;
   set PRJT.ORGANICS2;
   logDemAffl = log( DemAffl + 1 );
   logPromSpend = log( PromSpend + 1 );
   logPromTime = log( PromTime + 1 );
run;

goptions reset=global
         gunit=pct
         hsize= 10.625 in
         vsize= 8.5 in
         htitle=4
         htext=3
         vorigin=0 in
         horigin= 0 in
         cback=white border
         ctext=black 
         colors=(black blue green red yellow)
         ftext=swiss
         lfactor=3;

proc univariate data=PRJT.ORGANICLOG noprint;
   histogram logDemAffl; 
   title2 'Histogram for Log Affluence grade on a scale from 1 to 30';
run;

proc univariate data=PRJT.ORGANICLOG noprint;
   histogram logPromSpend; 
   title2 'Histogram for Log of Total amount spent';
run;

proc univariate data=PRJT.ORGANICLOG noprint;
   histogram logPromTime; 
   title2 'Histogram for Log of Time as a member';
run;

TITLE 'Step 9 :Stepwise Logistic Regression After Log Transformation';

/* Median imputation: Used PROC STDIZE to replace missing values with median */

proc stdize data= PRJT.ORGANICLOG out= PRJT.LOGIMPUTED method= median reponly;
var logDemAffl DemAge logPromTime ;
run;

data PRJT.LOGSORTED;
set PRJT.LOGIMPUTED;
n=ranuni(20041206);

proc sort data=PRJT.LOGSORTED; by n;

data PRJT.LOGTRAINING PRJT.LOGVALIDATION; /*Training and Validation Data*/
set PRJT.LOGSORTED nobs=nobs;
if _n_<=.60*nobs then output PRJT.LOGTRAINING;
else output PRJT.LOGVALIDATION;
run;


proc logistic data=PRJT.LOGTRAINING outest=PRJT.LOGTRAINING_REG covout;
class DemClusterGroup DemGender DemReg DemTVReg PromClass;
model targetBuy(event='1')=logDemAffl DemAge DemClusterGroup DemGender DemReg DemTVReg PromClass logPromSpend logPromTime
                / selection=stepwise  /*Stepwise selection process*/
                  slentry=0.3
                  slstay=0.35 details;
				  TITLE 'Step 9 :Stepwise Logistic Regression After Log Transformation';
run;

/*Exporting SAS training and validation data set*/
proc export data=PRJT.LOGTRAINING
   outfile='Z:\OneDrive - South Dakota State University - SDSU\INFS 762\Project 1\organic_logtraining.csv' 
   dbms=csv replace; 
run;

proc export data=PRJT.LOGVALIDATION
   outfile='Z:\OneDrive - South Dakota State University - SDSU\INFS 762\Project 1\organic_logvalidation.csv' 
   dbms=csv replace; 
run;
