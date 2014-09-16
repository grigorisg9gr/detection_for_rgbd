/* 
 * This is a fast implementation of displacement feats, when they are not convolved with a filter. 
 * However, they require a filter size to be computed. 
 *
 * Copyright (C) 2014 Grigorios Chrysos
 * available under the terms of the Apache License, Version 2.0
 */


#include <math.h>
#include "mex.h"

static inline float min(float x, float y) { return (x <= y ? x : y); }

mxArray *makeFeats(const mxArray *mximage, const mxArray *mxparams,int nrParams,int *fsz, int N) {
  float *im = (float *)mxGetPr(mximage);
  const int *dims = mxGetDimensions(mximage);
  float *params=(float *)mxGetPr(mxparams);  

  if (mxGetNumberOfDimensions(mximage) != 2 ||
      mxGetClassID(mximage) != mxSINGLE_CLASS)
    mexErrMsgTxt("Invalid input, here is histogram of displacements");

  int out[3]; 
  out[0]=(dims[0]-fsz[0]+1)*fsz[0]; out[1]=(dims[1]-fsz[1]+1)*fsz[1]; out[2]=nrParams;
  mxArray *mxfeat = mxCreateNumericArray(3, out, mxSINGLE_CLASS, mxREAL);
  float *feat = (float *)mxGetPr(mxfeat);  //final feats that will be returned
  float *feattemp=feat;
  for (int i=0;i<out[0]*out[1]*out[2];i++)//initialize array
	*(feattemp+i)=0;
  int middle_fsz[2];
  middle_fsz[0]=(fsz[0]+fsz[0]%2)/2-1;
  middle_fsz[1]=(fsz[1]+fsz[1]%2)/2-1;
  int i, x, y, fx, fy, aux, hold; //variables that will be used in the loop, just declared here 
  float *middle_block, *current_feat, *first_elem_in_block, avgMiddle, difference; 
  for (y=0; y<dims[0]-fsz[0];y++){
	for (x=0;x<dims[1]-fsz[1];x++){
		middle_block=im+ (x+middle_fsz[1])*dims[0]+(y+middle_fsz[0]); //middle element of the block
			
		avgMiddle=*middle_block;
		current_feat=feat+x*out[0]*fsz[1]+y*fsz[0]; //it's the reference point for our features for this x,y choice

		// loop over blocks of the selected area (filter size area)
		for (fy=0;fy<fsz[0];fy++){  //greg, replaced word blocky -> fy
		  for (fx=0;fx<fsz[1];fx++){
			first_elem_in_block=im + (x + fx)*dims[0]+ fy + y;			
			difference=*first_elem_in_block-avgMiddle;

			bool neg_flag=0;
			if (difference<0)
				{neg_flag=1; difference=-difference; }
			difference=min(difference, *(params+N+1)-1); 

			i=0; hold=0;
			while ((hold<=0)&&(i<=N)){
				if (difference<*(params+i+1))
					hold=i+N; //Belongs to N+1 interval
				i++;
			}
			if (neg_flag)
				hold=2*N-hold;
			aux=fy+fx*out[0];
			*(current_feat+aux+(hold)*out[0]*out[1])=1;
		 }
		}

	 }
	}

    return mxfeat;
}

// matlab entry point
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
  if ((nrhs != 6))
    mexErrMsgTxt("Wrong number of inputs"); 
  if (nlhs != 1)
    mexErrMsgTxt("Wrong number of outputs");

  int fsz[2];
  fsz[0]=(int)mxGetScalar(prhs[2]); fsz[1]=(int)mxGetScalar(prhs[3]);
  int nrParams=(int)mxGetScalar(prhs[4]), N=(int)mxGetScalar(prhs[5]);
  plhs[0] = makeFeats(prhs[0],prhs[1],nrParams,fsz,N);
}
