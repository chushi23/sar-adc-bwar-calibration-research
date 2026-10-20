function run_round2()
% MATLAB R2025b batch entry for the completed verification-round results.
candidate_regression_r2('all');
cal2_diagnostic_r2();
decoder_eval_r2(100,'debug100_oracleSparse');
end
