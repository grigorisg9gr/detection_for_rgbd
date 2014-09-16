
/*
 * This code is used for computing filter responses.  It computes the
 * displacement feats and then performs the convolution with a set of filters.
 * The displacements are computed and convolved in the same loop, 
 * providing the maximum speed to the multithreaded convolution.  
 *
 * Multithreaded version.
 *
 *
 * Copyright (C) 2014 Grigorios Chrysos
 * available under the terms of the Apache License, Version 2.0
 */

#include "mex.h"
#include <pthread.h>
#include <math.h>
#include <string.h>


struct thread_data {
  float *A;
  float *B;
  double *C;
  float *params;
  int *pnrParams;
  mxArray *mxC;
  const mwSize *A_dims;
  const mwSize *B_dims;
  mwSize C_dims[2];
};

static inline float min(float x, float y) { return (x <= y ? x : y); }

// convolve A and B
void *process(void *thread_arg) {
  thread_data *args = (thread_data *)thread_arg;
  float *A = args->A;
  float *B = args->B;
  double *C = args->C;
  float *params=args->params;
  int *pnrP=args->pnrParams; 
  int nrParams=*pnrP,i;
  const mwSize *A_dims = args->A_dims;
  const mwSize *B_dims = args->B_dims;
  const mwSize *C_dims = args->C_dims;
  double *feattemp=C;
  for (i=0;i<C_dims[0]*C_dims[1];i++)//initialize array
        *(feattemp+i)=0;
  int middle_fsz[2], hold,N=nrParams, x,y,xf,yf,B_numel=B_dims[0]*B_dims[1];

  middle_fsz[0]=(B_dims[0]+B_dims[0]%2)/2-1;
  middle_fsz[1]=(B_dims[1]+B_dims[1]%2)/2-1;
 float *middle_block, *first_elem_in_block, difference,*A_1,*B_1;
 double val, *dst = C;
 for (x = 0; x < C_dims[1]; x++) {
   for (y = 0; y < C_dims[0]; y++) {
        val = 0;
 	middle_block=A+ (x+middle_fsz[1])*A_dims[0]+(y+middle_fsz[0]);
        for (xf = 0; xf < B_dims[1]; xf++) {
	   A_1 = A+ (x+xf)*A_dims[0] + y;
	   B_1 = B+ xf*B_dims[0];
              for (yf = 0; yf < B_dims[0]; yf++) {
                	first_elem_in_block=A_1+ yf;
			difference=*first_elem_in_block-(*middle_block);
 			bool neg_flag=0;
                        if (difference<0)
                                {neg_flag=1; difference=-difference; }
			difference=min(difference, *(params+N+1)-1); 
			i=0; hold=-1;
                        while ((hold<=0)&&(i<=N)){ 
                                if (difference<*(params+i+1)) //((difference>=*(params+i))&&(difference<*(params+i+1)))
                                        hold=i+N; //Belongs to N+1 interval
                                i++;
                        }
                        if (neg_flag)
                                hold=2*N-hold;
			val+=(double)*(B_1+yf+hold*B_numel); // A is just 1 there
          }
        }// end of xp loop
        *(dst++) = val;
   }
 }
  pthread_exit(NULL);
}




// matlab entry point
// C = fconv(A, cell of B, start, end);
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) { 
  if (nrhs != 6)
    mexErrMsgTxt("Wrong number of inputs"); 
  if (nlhs != 1)		
    mexErrMsgTxt("Wrong number of outputs");
  // get A
  const mxArray *mxA = prhs[0];
  if (mxGetNumberOfDimensions(mxA) != 2 || 
      mxGetClassID(mxA) != mxSINGLE_CLASS)
    mexErrMsgTxt("Invalid input: A");

  // get B and start/end
  const mxArray *cellB = prhs[1];
  mwSize num_bs = mxGetNumberOfElements(cellB);  
  int start = (int)mxGetScalar(prhs[2]) - 1;
  int end = (int)mxGetScalar(prhs[3]) - 1;
  if (start < 0 || end >= num_bs || start > end)
    mexErrMsgTxt("Invalid input: start/end");
  int len = end-start+1;

  // start threads
  thread_data *td = (thread_data *)mxCalloc(len, sizeof(thread_data));
  pthread_t *ts = (pthread_t *)mxCalloc(len, sizeof(pthread_t));
  const mwSize *A_dims = mxGetDimensions(mxA);
  float *A = (float *)mxGetPr(mxA);
  const mxArray *mxparams=prhs[4];
  float *params=(float *)mxGetPr(mxparams);
  int nrParams=(int)mxGetScalar(prhs[5]);
  int *pnrP=&nrParams;
  for (int i = 0; i < len; i++) {
    const mxArray *mxB = mxGetCell(cellB, i+start);
    td[i].A_dims = A_dims;
    td[i].A = A;
    td[i].params=params;
    td[i].pnrParams=pnrP;
    td[i].B_dims = mxGetDimensions(mxB);
    td[i].B = (float *)mxGetPr(mxB);
    if (mxGetNumberOfDimensions(mxB) != 3 ||
        mxGetClassID(mxB) != mxSINGLE_CLASS)
      mexErrMsgTxt("Invalid input: B");

    // compute size of output
    int height = td[i].A_dims[0] - td[i].B_dims[0] + 1;
    int width = td[i].A_dims[1] - td[i].B_dims[1] + 1;
    if (height < 1 || width < 1)
      mexErrMsgTxt("Invalid input: B should be smaller than A");
    td[i].C_dims[0] = height;
    td[i].C_dims[1] = width;
    td[i].mxC = mxCreateNumericArray(2, td[i].C_dims, mxDOUBLE_CLASS, mxREAL);
    td[i].C = (double *)mxGetPr(td[i].mxC);
    if (pthread_create(&ts[i], NULL, process, (void *)&td[i]))
      mexErrMsgTxt("Error creating thread");
  }

  // wait for the treads to finish and set return values
  void *status;
  plhs[0] = mxCreateCellMatrix(1, len);
  for (int i = 0; i < len; i++) {
    pthread_join(ts[i], &status);
    mxSetCell(plhs[0], i, td[i].mxC);
}
  mxFree(td);
  mxFree(ts);
}
   
