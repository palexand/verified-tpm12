(** ----
%%
%% Key Theory
%%
%% Author: Perry Alexander
%% Date: Mon Jan 16 15:26:29 CST 2012
%%
%% Description: Basic model of keys, encryption, decryption, and signing
%% 
%% Dependencies:
%%  data.pvs
%%  pcr.pvs
%%  keyData.pvs
%%  authdata.pvs
%%
%% Todo: (key - => pending, + => done)
%%
%% ----
 *)

Require Export data.v
  IMPORTING data[HV];

  KEYSET: TYPE = [# vals: set[privKVAL]
  	       	  , keys: set[(tpmKey?)]
		 #];

  %% Reserved Key Handles - Should be moved to tpm.pvs
  TPM_KH_SRK : (tpmKey?) = tpmKey(2,storage,keyFlagsF,
				  always,keyParmsDef,
				  pcrInfoLongDefault,
				  storeAsymkeyDefault(2,1))
  TPM_KH_OWNER : (tpmKey?)
  TPM_KH_REVOKE : (tpmKey?)
  TPM_KH_TRANSPORT : (tpmKey?)
  TPM_KH_OPERATOR : (tpmKey?)
  TPM_KH_ADMIN : (tpmKey?)
  %% Not sure if EK is an indentity key or not
  TPM_KH_EK : (tpmKey?) = tpmKey(1,identity,keyFlagsF,
				 always,keyParmsDef,
				 pcrInfoLongDefault,
				 storeAsymkeyDefault(1,1))


  %% Any tpmKey? with key value 0 is invalid.
  invalidKey : (tpmKey?)

  invalidKey?(k:(tpmKey?)):bool = key(k)=0;

  %% Define private and public key accessors for tpmKey?. The public
  %% key is the key value while the private key is -key.
  private(k:(tpmKey?)) : privKVAL = privKey(encData(encDat(k)))
  public(k:(tpmKey?)):KVAL = key(k)
  publicAsymkey(k:(tpmStoreAsymkey?)):KVAL = inverse(privKey(k))

  %% Some theorems about key inverse, private and public.

  %% The inverse key of the inverse key is the original key
  double_inverse: THEOREM FORALL (k:KVAL) : inverse(inverse(k))=k;

  %% the inverse of a private key is the public key for the same
  %% asymmetric key.
  inverse_private: THEOREM FORALL (k:(tpmKey?)) :
    inverse(private(k))=public(k);

  %% visa versa                                                         
  inverse_public: THEOREM FORALL (k:(tpmKey?)) :
    inverse(public(k))=private(k);

  %% If inverse keys are equal, key values are equal
  equal_inverse: THEOREM FORALL (k0,k1:KVAL) :
     inverse(k0) = inverse(k1) <=> k0=k1;

  % TODO: PROVE STUFF ABOUT
  rewrap(k:(tpmKey?),par:KVAL) : (tpmKey?) = 
    CASES k OF 
      tpmKey(v,u,f,d,g,r,e) : 
      	tpmKey(v,u,f,d,g,r,CASES e OF 
			   encrypted(d0,k0) : encrypted(d0,par)
			   ENDCASES)
    ENDCASES;
   
  rewrap : THEOREM FORALL (k:(tpmKey?),p:KVAL) :
    rewrap(k,p)=tpmKey(key(k),
		       keyUsage(k),
		       keyFlags(k),
		       authDataUsage(k),
		       algoParms(k),
		       PCRInfo(k),
		       encrypted(encData(encDat(k)),p))

  %% Basic crypto functions operating on KVAL xStatus functions
  %% operate on status indicators while x functions operate on
  %% tpmData.  Users need only call encrypt, decrypt, sign, checkSig
  %% and friends.

  noCrypto?(d:tpmData) : bool =
    CASES d OF
      tpmMigScheme(m0) : TRUE,
      tpmEKBlobActivate(k0,i0,p0) : TRUE,
      tpmEKBlobAuth(a0) : TRUE,
      tpmDigest(digest0) : TRUE,
      tpmNonce(i0) : TRUE,
      tpmSecret(i0) : TRUE,
      tpmKey(k0,u0,f0,a0,ap0,p0,e0) : TRUE,
      tpmMSAComposite(i0,m0) : TRUE,
      tpmCMKDelegate(s0,s1,b0,l0,m0) : TRUE,
      tpmCMKMigAuth(m0,p0) : TRUE,
      tpmCMKSigTicket(v0,s0) : TRUE,
      tpmCMKMAApproval(m0) : TRUE,
      tpmPCRInfoLong(lc0,lr0,sc0,sr0,dc0,dr0) : TRUE,
      tpmPubkey(a0,k0) : TRUE,
      tpmMigrateAsymkey(u0,d0,p0) : TRUE,
      OAEP(m0,p0,s0) : TRUE,
      concat(f0,s0) : TRUE
      ELSE FALSE
    ENDCASES;


  % Data Encryption

  checkEncrypt?(d:tpmData) : bool =
%    not(encrypted?(d)) 
     TRUE

  encrypt(d:tpmData,k:KVAL) : tpmData = 
    encrypted(d,k)
%     IF checkEncrypt?(d)
%     THEN encrypted(d,k)
%     ELSE badData
%     ENDIF


  % Data decryption

  checkDecrypt?(d:(encrypted?),k:privKVAL,ks:KEYSET) : bool = 
    k=inverse(ekey(d)) AND member(k,vals(ks))
 
  decrypt(d:(encrypted?),k:privKVAL,ks:KEYSET) : tpmData =
    IF checkDecrypt?(d,k,ks)
    THEN CASES encData(d) OF 
	   tpmEncAuth(a0) : tpmSecret(a0)
	   ELSE encData(d)
	 ENDCASES
    ELSE badData %TODO: DECRYPT_ERROR
    ENDIF

  % Lemmas on decryption and encryption

  %% Encrypted data can not be encrypted TODO: Truly?
  no_encrypt_encrypted : THEOREM FORALL (d:tpmData,k:KVAL,ks:KEYSET) : 
    encrypted?(d) => cryptoError?(encrypt(d,k))

  %% assuming: Data that is encrypted can't be encrypted again
  noDoubleEncryption : LEMMA 
    FORALL (d:(encrypted?)) : 
      not(encrypted?(encData(d)));
    
  %% Data can't be double encrypted
  %% lemma noDoubleEncryption
  no_double_encryption : THEOREM FORALL (d:(encrypted?),k0:privKVAL,ks:KEYSET) :
    LET d1=decrypt(d,k0,ks) IN
    not encrypted?(badData) => not encrypted?(d1)

  %% Definition of checkEncrypt?
  check_encrypt : THEOREM FORALL (d:tpmData) : 
    not(cryptoError?(d) OR encrypted?(d)) =>
    	checkEncrypt?(d);

  %% Using checkDecrypt? with encrypted data
  check_decrypt : THEOREM FORALL (d:tpmData,k:privKVAL,ks:KEYSET) : 
    not(encrypted?(d) OR cryptoError?(d)) AND
    member(k,vals(ks)) =>
    	checkDecrypt?(encrypt(d,inverse(k)),k,ks);

  %% Definition of checkDecrypt?
  check_decrypt2 : THEOREM FORALL (d:(encrypted?),k:privKVAL,ks:KEYSET) :
    member(k,vals(ks)) AND k=inverse(ekey(d)) =>
    checkDecrypt?(d,k,ks)

  %% Definition of decrypt with checkDecrypt?
  check_decrypt3 : THEOREM FORALL (d:(encrypted?),k:privKVAL,ks:KEYSET) :
    checkDecrypt?(d,k,ks) => decrypt(d,k,ks)=encData(d) OR
    			    decrypt(d,k,ks)=tpmSecret(authData(encData(d)))
    
  %% Definition of decrypt with checkEncrypt? and encrypt
  decrypt_encrypt : THEOREM FORALL (d:tpmData,k:KVAL,ks:KEYSET) : 
    checkEncrypt?(d) AND member(inverse(k),vals(ks)) =>
    decrypt(encrypt(d,k),inverse(k),ks) = 
    	CASES d OF
%	  encrypted(d0,k0) : encrypted(d0,k0),
	  cryptoError(n) : badData,
	  tpmEncAuth(a) : tpmSecret(a)
	  ELSE d
	ENDCASES;

  %% If two keys are equal, should be able to decrypt(encryption of one) 
  %%  with the other
  decrypt_equal_keys: THEOREM FORALL (b:tpmData,k0,k1:KVAL,ks:KEYSET) :
    checkEncrypt?(b) AND member(inverse(k0),vals(ks)) AND 
    k0=k1 IMPLIES decrypt(encrypt(b,k0),inverse(k1),ks) = 
    		     CASES b OF
		     	encrypted(d,k) : cryptoError(1),
			tpmEncAuth(a) : tpmSecret(a)
			ELSE b
		     ENDCASES;

  %% If two keys are not equal, should not be able to decrypt(encryption of one)
  %%  with the other
  no_decrypt_unequal_keys: THEOREM FORALL (b:tpmData,k0,k1:KVAL,ks:KEYSET) :
    checkEncrypt?(b) AND member(inverse(k0),vals(ks)) AND
    k0/=k1 IMPLIES decrypt(encrypt(b,k0),inverse(k1),ks) = badData

  %% If a key is not installed, can not decrypt using it.
  no_decrypt_uninstalled: THEOREM FORALL (b:tpmData,k0:privKVAL,ks:KEYSET) :
    checkEncrypt?(b) AND 
    not(member(k0,vals(ks))) IMPLIES 
    		decrypt(encrypt(b,inverse(k0)),k0,ks) = badData;


  % Data signing

  sign(d:tpmData,k:privKVAL,ks:KEYSET) : tpmData = 
    IF cryptoError?(d) OR not(member(k,vals(ks)))
    THEN cryptoError(2)
    ELSE signed(d,k)
    ENDIF

  % Data signature checking

  checkSig?(k:KVAL,d:tpmData) : bool = 
    IF signed?(d)
    THEN k = inverse(sigkey(d))
    ELSE FALSE
    ENDIF


  % Lemmas on data signing and signature checking

  check_sig : THEOREM FORALL (d:tpmData,k:KVAL,ks:KEYSET) : 
    not cryptoError?(d) AND member(inverse(k),vals(ks)) =>
    	checkSig?(k,sign(d,inverse(k),ks));

  no_sign_uninstalled: THEOREM FORALL (b:tpmData,k0:privKVAL,ks:KEYSET) :
    not(cryptoError?(b)) AND not(member(k0,vals(ks))) =>
    	sign(b,k0,ks) = cryptoError(2);

  
  %%%% Key sets, installation, and use

  	 
  %% Is a key installed or the SRK?
  installedOrSRK?(k:(tpmKey?),ks:KEYSET):bool =
    member(private(k),vals(ks)) OR key(k)=key(TPM_KH_SRK); 


  %% There is no magic for SRK - use the TPM_KH_SRK handle if the wrapping
  %% key is the SRK.
  addKey(k:(tpmKey?),ks:KEYSET) : KEYSET =  
  	(#vals:=add(private(k),vals(ks))
  	 ,keys:=add(k,keys(ks))#);
    % IF (wrappingKey(k)=TPM_KH OR member(wrappingKey(k),ks)) AND d=PCRInfo(k)
    % THEN add(key(k),ks)
    % ELSE ks
    % ENDIF;

  loadKey(k,p:(tpmKey?),ks:KEYSET,d:PCRVALUES):KEYSET =  %d:list[PCR]
    IF 
%        getPCRs(d,releasePCRSelect(PCRInfo(k)))=digAtRelease(PCRInfo(k)) AND 
%        getPCRs(d,creationPCRSelect(k))=digAtCreation(PCRInfo(k)) AND 
       installedOrSRK?(p,ks) %todo: should this be not?
    THEN addKey(k,ks)
    ELSE ks
    ENDIF

  load_key :THEOREM FORALL(k,p:(tpmKey?),ks:KEYSET,d:PCRVALUES) :
    loadKey(k,p,ks,d)=
    IF member(private(p),vals(ks))
    THEN (#vals:=add(private(k),vals(ks)),keys:=add(k,keys(ks))#)
    ELSIF key(p)=key(TPM_KH_SRK)
    THEN (#vals:=add(private(k),vals(ks)),keys:=add(k,keys(ks))#)
    ELSE ks
    ENDIF

  %% Remove a key - this is not currently
  %% Removes key from loaded key list, but keeps key structure stored.
  revokeKey(k:(tpmKey?),ks:KEYSET):KEYSET = (#vals:=remove(private(k),vals(ks))
  					     ,keys:=keys(ks)#);

  isParent?(p,c:(tpmKey?)) : bool = 
    ekey(encDat(c))=key(p);
  
  % assuming: If p is the parent of k, then p must be installed
  parentInstalled : LEMMA 
    FORALL (k,p:(tpmKey?),ks:KEYSET) : isParent?(p,k) => 
    	   member(private(p),vals(ks));

  %% If isParent is true, then checkDecrypt? should also be true...
  % lemma inverse_private, parentInstalled
  is_parent_decrypt : THEOREM FORALL (k,p:(tpmKey?),ks:KEYSET):
    isParent?(p,k) => checkDecrypt?(encDat(k),private(p),ks);


  child_if_parent:THEOREM FORALL(k,p:(tpmKey?),srk:KVAL,ks:KEYSET,d:PCRVALUES):
   %encrypted(encDat(k),p)
    ekey(encDat(k))=key(p) AND
    (member(private(p),vals(ks)) OR key(p)=key(TPM_KH_SRK))
       => member(private(k),vals(loadKey(k,p,ks,d)))


  no_child_if_no_parent: THEOREM FORALL (k:(tpmKey?),ks:KEYSET) :
    NOT(member(private(k),vals(revokeKey(k,ks))));

  %% Crypto functions using TPM keys.  Public keys from TPM keys are
  %% public knowledge and require nothing for use - encrypt and
  %% checkSig? do not require a key set.  Private keys must be
  %% installed in the key set ks passed to each function - decrypt and
  %% sign require a key set.

  encryptWrapped(k:(tpmKey?),d:tpmData):tpmData = encrypt(d,key(k))

  decryptWrapped(k:(tpmKey?),d:(encrypted?),ks:KEYSET):tpmData =
    IF installedOrSRK?(k,ks) THEN decrypt(d,private(k),ks) ELSE d ENDIF

  signWrapped(k:(tpmKey?),d:tpmData,ks:KEYSET):tpmData =
    IF installedOrSRK?(k,ks) THEN sign(d,private(k),ks) ELSE d ENDIF

  checkSig?Wrapped(k:(tpmKey?),d:tpmData):bool = checkSig?(key(k),d)

END key
