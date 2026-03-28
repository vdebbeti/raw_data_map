/**********************************************************************
* Program : cm.sas
* Domain  : CM — Concomitant Medications
* Purpose : Create SDTM CM domain from raw EDC data
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

/*--- Step 1: Read raw CM dataset ------------------------------------*/
data work.cm_raw;
  set raw.cm;
  where cmtrt ne "";
run;

/*--- Step 2: Read DM for reference start date -----------------------*/
data work.dm_ref;
  set raw.dm (keep = usubjid rfstdtc);
run;

/*--- Step 3: Derive SDTM CM variables  ------------------------------*/
data work.cm_sdtm;
  merge work.cm_raw (in=a) work.dm_ref;
  by usubjid;
  if a;

  STUDYID = "STUDY001";
  DOMAIN  = "CM";
  CMSEQ   = _N_;
  CMTRT   = strip(cmtrt);
  CMDECOD = strip(cmdecod);
  CMCAT   = strip(cmcat);
  CMSCAT  = strip(cmscat);
  CMROUTE = upcase(strip(cmroute));
  CMDOSE  = input(strip(cmdose_c), best.);
  CMDOSU  = strip(cmdosu);
  CMSTDTC = strip(cmstdtc);
  CMENDTC = strip(cmendtc);
  CMENRTPT= upcase(strip(cmenrtpt));

run;

/*--- Step 4: Save to SDTM library -----------------------------------*/
data sdtm.cm;
  retain STUDYID DOMAIN USUBJID CMSEQ CMTRT CMDECOD CMCAT CMSCAT
         CMROUTE CMDOSE CMDOSU CMSTDTC CMENDTC CMENRTPT;
  set work.cm_sdtm;
  keep STUDYID DOMAIN USUBJID CMSEQ CMTRT CMDECOD CMCAT CMSCAT
       CMROUTE CMDOSE CMDOSU CMSTDTC CMENDTC CMENRTPT;
run;

%put NOTE: CM domain complete.;
