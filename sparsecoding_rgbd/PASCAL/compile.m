mex -O resize.cc
mex -O reduce.cc
mex -O shiftdt.cc
mex -O features.cc
mex -O -largeArrayDims qp_one_sparse.cc
mex -O -largeArrayDims score.cc
mex -O -largeArrayDims lincomb.cc

mex -O new_code_greg/features_only_depth.cc % greg, 15/1
mex -O greg_code_from_voc_5/features_64.cc % greg, 29/4

% use one of the following depending on your setup
% 1 is fastest, 3 is slowest 

% 1) multithreaded convolution using blas
mex -O fconvblas.cc -lmwblas -o fconv_double % greg, 29/4: requires both filters and features to be double
mex -O greg_code_from_voc_5/fconvsse.cc -lmwblas -o fconv
mex -O new_code_greg/fconvsse_sparse.cc -lmwblas -o fconv_sparse  % greg, 29/4: VERY sensitive to any changes in sparse feature size, the code should be adapted!!
% 2) mulththreaded convolution without blas
% mex -O fconvMT.cc -o fconv
% 3) basic convolution, very compatible
% mex -O fconv.cc -o fconv
