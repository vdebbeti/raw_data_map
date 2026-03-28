/**********************************************************************
* Program : dm.sas
* Domain  : DM — Demographics
* Purpose : Create SDTM DM domain from raw EDC data
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

/*--- Step 1: Read raw demographics and screening data ---------------*/
data work.dm_raw;
  set raw.dm;
run;

data work.sc_raw;
  set raw.sc (keep = usubjid scorres sctestcd);
  where sctestcd in ("ETHNIC","RACE");
run;

/*--- Step 2: Transpose SC for race/ethnicity ------------------------*/
proc transpose data=work.sc_raw out=work.sc_wide prefix=SC_;
  by usubjid;
  id sctestcd;
  var scorres;
run;

/*--- Step 3: Derive DM SDTM variables -------------------------------*/
data work.dm_sdtm;
  merge work.dm_raw (in=a) work.sc_wide (rename=(SC_ETHNIC=ETHNIC SC_RACE=RACE));
  by usubjid;
  if a;

  STUDYID  = "STUDY001";
  DOMAIN   = "DM";
  SUBJID   = strip(subjid);
  RFSTDTC  = strip(rfstdtc);
  RFENDTC  = strip(rfendtc);
  RFICDTC  = strip(rficdtc);
  SITEID   = strip(siteid);
  AGE      = input(strip(age_c), best.);
  AGEU     = "YEARS";
  SEX      = upcase(strip(sex));
  RACE     = strip(RACE);
  ETHNIC   = strip(ETHNIC);
  ARMCD    = strip(armcd);
  ARM      = strip(arm);
  ACTARMCD = strip(actarmcd);
  ACTARM   = strip(actarm);

run;

/*--- Step 4: Output -------------------------------------------------*/
data sdtm.dm;
  set work.dm_sdtm;
  keep STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFICDTC
       SITEID AGE AGEU SEX RACE ETHNIC ARMCD ARM ACTARMCD ACTARM;
run;

%put NOTE: DM domain complete.;
