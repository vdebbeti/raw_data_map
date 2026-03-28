/**********************************************************************
* Program : suppae.sas
* Domain  : SUPPAE — Supplemental AE
* Purpose : Create SUPPAE dataset adding non-standard AE variables
***********************************************************************/

libname raw  "/data/raw/edc";
libname sdtm "/data/sdtm";

/*--- Pull additional AE fields not in standard SDTM AE -------------*/
data work.ae_supp_raw;
  set raw.ae (keep = usubjid aeseq ae_causality_add ae_timetoreso ae_rechallenge);
  where ae_causality_add ne "" or ae_timetoreso ne . or ae_rechallenge ne "";
run;

/*--- Read AE from SDTM to link AESEQ --------------------------------*/
data work.ae_ref;
  set sdtm.ae (keep = usubjid aeseq);
run;

/*--- Build SUPPAE in vertical (QNAM/QVAL) format --------------------*/
data work.suppae;
  set work.ae_supp_raw;
  STUDYID = "STUDY001";
  RDOMAIN = "AE";
  IDVAR   = "AESEQ";
  IDVARVAL= strip(put(aeseq, best.));

  /* Additional causality assessment */
  if ae_causality_add ne "" then do;
    QNAM  = "AECADD";
    QLABEL= "Additional Causality Assessment";
    QVAL  = strip(ae_causality_add);
    output;
  end;

  /* Time to resolution */
  if ae_timetoreso ne . then do;
    QNAM  = "AETIMRES";
    QLABEL= "Time to Resolution (Days)";
    QVAL  = strip(put(ae_timetoreso, best.));
    output;
  end;

  /* Rechallenge result */
  if ae_rechallenge ne "" then do;
    QNAM  = "AERECHLL";
    QLABEL= "Rechallenge Result";
    QVAL  = upcase(strip(ae_rechallenge));
    output;
  end;

  keep STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL;
run;

data sdtm.suppae;
  retain STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL;
  set work.suppae;
run;

%put NOTE: SUPPAE domain complete.;
