/* 
 * This implementation takes an image in pixels and a block size and averages the pixels per block
 *
 * Copyright (C) 2014 Grigorios Chrysos
 * available under the terms of the Apache License, Version 2.0
 */


#include <math.h>
#include "mex.h"

static inline float min(float x, float y) { return (x <= y ? x : y); }
static inline float max(float x, float y) { return (x <= y ? y : x); }

static inline int min(int x, int y) { return (x <= y ? x : y); }
static inline int max(int x, int y) { return (x <= y ? y : x); }




// main function:
// takes a depth image and a bin size 
// returns the the image into blocks
// im, scale (block), output/feats dimensions
mxArray *process(const mxArray *mximage, const mxArray *mxsbin,const mxArray *mxout0,const mxArray *mxout1) {

  float *im = (float *)mxGetPr(mximage);
  const int *dims = mxGetDimensions(mximage);


  if (mxGetNumberOfDimensions(mximage) != 2 ||
      mxGetClassID(mximage) != mxSINGLE_CLASS)
    mexErrMsgTxt("Invalid input, here is im2blocks");

  //get input and make them arrays: 
  int out[3]; 
  out[0]= (int)mxGetScalar(mxout0);    out[1]= (int)mxGetScalar(mxout1);    out[2]=1;


  int block = (int)mxGetScalar(mxsbin);
  mxArray *mxfeat = mxCreateNumericArray(3, out, mxSINGLE_CLASS, mxREAL);
  float *feat = (float *)mxGetPr(mxfeat);  //final feats that will be returned
  float *feattemp=feat;
  for (int i=0;i<out[0]*out[1]*out[2];i++)//initialize array
	*(feattemp+i)=0;
  int visible[2]; visible[0]=dims[0]/block; visible[1]=dims[1]/block; 

  float *first_elem_in_block, *cc, avg;
  for (int y=0,yout=0; y<visible[0]*block;y=y+block,yout++){
	for (int x=0,xout=0;x<visible[1]*block;x=x+block,xout++){
			first_elem_in_block=im + x*dims[0]+ y;
			/*size_t first_idx = (x )*dims[0]+ y;      //following two lines can check whether we are out of bounds
			if ((first_idx < 0) || (first_idx >= dims[0]*dims[1]))
				mexErrMsgTxt("Out of bounds in im2blocks 1\n");
			*/
			avg=0;
			//loop over pixels of the block
			for (int y_ind=0;y_ind<block;y_ind++){
			  for (int x_ind=0;x_ind<block;x_ind++){
				cc=(first_elem_in_block+x_ind*dims[0]+y_ind);
				/*size_t second_idx = first_idx + x_ind*dims[0]+y_ind;
				if ((second_idx < 0) || (second_idx >= dims[0]*dims[1]))
					mexErrMsgTxt("Out of bounds in im2blocks 2\n");
				*/
				avg+=*cc;
		 	 }
			} 
			avg=avg/(block*block);
			*(feat+xout*out[0]+yout)=avg; //it's the reference point for our features for this x,y choice
	 }
	}
    return mxfeat;
}





// matlab entry point
// im, scale (block), output/feats,parameters,nrfts (number of features/distributions), fsz
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) {
//mexPrintf("%d\n",nrhs); 
  if ((nrhs < 4)||(nrhs > 5))
    mexErrMsgTxt("Wrong number of inputs"); 
  if (nlhs != 1)
    mexErrMsgTxt("Wrong number of outputs");

//mexPrintf("im2blocks: Welcome\n");
  plhs[0] = process(prhs[0], prhs[1],prhs[2],prhs[3]);
}
