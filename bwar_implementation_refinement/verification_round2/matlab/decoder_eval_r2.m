function out = decoder_eval_r2(nrun, tag)
% Decoder A/B/C evaluation for both locked candidates.
% A: existing estimated-weight accumulator.
% B: oracle diagnostic: maps using true physical interval centres.
% C: implementable sparse override table generated only from W_hat and the
%    known raw-vector order; no interval boundary is used to build it.
if nargin < 1, nrun = 100; end
if nargin < 2, tag = sprintf('%d',nrun); end
cfg = config_round2(); rows = struct([]); raw = struct();
decoderNames = {'A_weighted_accumulator','B_oracle_upper_bound','C_sparse_raw_vector'};
for ci = 1:numel(cfg.candidates)
    c = cfg.candidates(ci); a = bwar_build(rmfield(c,'name'),cfg);
    D = zeros(nrun, 8*3+6);
    for chip=1:nrun
        z = one_chip(a,cfg,chip);
        D(chip,:) = [z.A z.B z.C z.nCorrB z.nCorrC z.maxCorrDeltaB z.oraclePhysical z.cNoMissing z.nPredictedUnreachable];
    end
    raw.(sprintf('c%d',ci)) = D;
    for di = 1:3
        r = summarize_decoder(c,a,D,di,decoderNames{di});
        if isempty(rows), rows=r; else, rows(end+1)=r; end %#ok<AGROW>
    end
end
T = struct2table(rows);
writetable(T,fullfile(cfg.implRoot,'csv',sprintf('decoder_ABC_%s.csv',tag)));
save(fullfile(cfg.implRoot,'raw',sprintf('decoder_ABC_%s.mat',tag)),'cfg','T','raw','-v7.3');
out=T;
end

function z = one_chip(a,cfg,chip)
real=realize_variant(a,cfg,chip); t=transfer_tree_gen(a,real,cfg);
raw=t.raw(:); bits=unpack_bits(raw,a.decisions);
st=RandStream('mt19937ar','Seed',cfg.calSeed+chip);
wHat=real.decW(:)+mean(cfg.cal2SigmaLSB*a.lsb*randn(st,a.decisions,cfg.cal2Navg),2);
codeA=clip_code(cfg.M*(bits*wHat));

% B is deliberately oracle-only: true physical decision order supplies the
% transition ordering used by its cumulative monotonic correction.
[~,ixActual]=sort(double(raw)); orderedActual=codeA(ixActual); orderedB=cummax(orderedActual);
codeB=zeros(size(codeA)); codeB(ixActual)=orderedB;

% C predicts reachable vectors from W_hat through the known SAR tree.  It
% uses no actual Vin interval or true weight and runs only during foreground
% calibration, producing a sparse raw-vector override LUT.
realHat=struct('decW',wHat,'nomW',wHat);
tPred=transfer_tree_gen(a,realHat,cfg);
[rawPred,~]=sort(double(tPred.raw(:)));
bitsPred=unpack_bits(uint32(rawPred),a.decisions);
orderedA=clip_code(cfg.M*(bitsPred*wHat)); orderedC=cummax(orderedA);
lut=nan(2^a.decisions,1); lut(rawPred+1)=orderedC;
mapped=lut(double(raw)+1); codeC=codeA; known=isfinite(mapped); codeC(known)=mapped(known);
z.A=adc_metrics(t,codeA,a,cfg); z.B=adc_metrics(t,codeB,a,cfg); z.C=adc_metrics(t,codeC,a,cfg);
z.nCorrB=sum(orderedB~=orderedActual); z.nCorrC=sum(orderedC~=orderedA); z.maxCorrDeltaB=max(abs(orderedB-orderedActual));
z.oraclePhysical=1; z.cNoMissing=(z.C(3)==0); z.nPredictedUnreachable=sum(~known);
end

function r=summarize_decoder(c,a,D,di,name)
base=(di-1)*8; m=D(:,base+(1:8)); valid=isfinite(m(:,1)) & isfinite(m(:,2));
qd=[NaN NaN NaN]; qi=qd;
if any(valid), qd=quantile_linear(m(valid,1),[.5 .95 .99]); qi=quantile_linear(m(valid,2),[.5 .95 .99]); end
r.candidate=string(c.name); r.decoder=string(name); r.MC_runs=size(D,1); r.total_cap_pF=a.totalCap_pF;
r.DNL_P50_cond=qd(1); r.DNL_P95_cond=qd(2); r.DNL_P99_cond=qd(3);
r.INL_P50_cond=qi(1); r.INL_P95_cond=qi(2); r.INL_P99_cond=qi(3);
r.DNL_P99_strict=quantile_linear(m(:,1),.99); r.INL_P99_strict=quantile_linear(m(:,2),.99);
r.missing_yield=mean(m(:,3)==0); r.monotonic_yield=mean(m(:,4)); r.pass_yield=mean(m(:,5));
r.mean_down=mean(m(:,8));
if di==1
    r.mean_correction_entries=NaN; r.correction_entries_P95=NaN; r.correction_entries_P99=NaN; r.max_correction_delta=NaN;
else
    if di==2, eCol=25; else, eCol=26; end
    r.mean_correction_entries=mean(D(:,eCol)); r.correction_entries_P95=quantile_linear(D(:,eCol),.95); r.correction_entries_P99=quantile_linear(D(:,eCol),.99); r.max_correction_delta=max(D(:,27));
end
r.oracle_physical=mean(D(:,28)); r.c_no_missing=mean(D(:,29));
r.mean_predicted_unreachable_vectors=mean(D(:,30));
end

function code=clip_code(value)
code=min(65535,max(0,floor(value+.5)));
end

function b=unpack_bits(raw,K)
b=false(numel(raw),K);
for k=1:K, b(:,k)=bitand(raw,uint32(2^(K-k)))~=0; end
end
