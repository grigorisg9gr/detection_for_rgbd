#include "mex.h"
#include <pthread.h>
#include <math.h>
#include <string.h>

/*
 * This code is used for computing filter responses.  It computes the
 * response of a set of filters with a feature map.  
 *
 * Multithreaded version.
 */

const float PI = 3.14159265358979323846;
struct thread_data {
  float *A;
  float *B;
  double *C;
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
  const mwSize *A_dims = args->A_dims;
  const mwSize *B_dims = args->B_dims;
  const mwSize *C_dims = args->C_dims;
  int num_features = args->A_dims[2];
//mexPrintf("pr: %d %d\n",num_features,args->B_dims[2]);
  for (int f = 0; f < num_features; f++) {
    double *dst = C;
    float *A_src = A + f*A_dims[0]*A_dims[1];      
    float *B_src = B + f*B_dims[0]*B_dims[1];
    for (int x = 0; x < C_dims[1]; x++) {
      for (int y = 0; y < C_dims[0]; y++) {
        double val = 0;
        for (int xp = 0; xp < B_dims[1]; xp++) {
          float *A_off = A_src + (x*B_dims[1]+xp)*A_dims[0] + y*B_dims[0]; //greg, 13/1: Tropopoiisi wste na proxwraei kata B_dims panw ston pinaka A
          float *B_off = B_src + xp*B_dims[0];
          switch(B_dims[0]) {
            case 20: val += A_off[19] * B_off[19];
            case 19: val += A_off[18] * B_off[18];
            case 18: val += A_off[17] * B_off[17];
            case 17: val += A_off[16] * B_off[16];
            case 16: val += A_off[15] * B_off[15];
            case 15: val += A_off[14] * B_off[14];
            case 14: val += A_off[13] * B_off[13];
            case 13: val += A_off[12] * B_off[12];
            case 12: val += A_off[11] * B_off[11];
            case 11: val += A_off[10] * B_off[10];
            case 10: val += A_off[9] * B_off[9];
            case 9: val += A_off[8] * B_off[8];
            case 8: val += A_off[7] * B_off[7];
            case 7: val += A_off[6] * B_off[6];
            case 6: val += A_off[5] * B_off[5];
            case 5: val += A_off[4] * B_off[4];
            case 4: val += A_off[3] * B_off[3];
            case 3: val += A_off[2] * B_off[2];
            case 2: val += A_off[1] * B_off[1];
            case 1: val += A_off[0] * B_off[0];
              break;
            default:	    	      
              for (int yp = 0; yp < B_dims[0]; yp++) {
                val += *(A_off++) * *(B_off++);
              }
          }
        }// end of xp loop
        *(dst++) += val;
      }
    }
  }
  pthread_exit(NULL);
}


float normalDist(float x,float mu,float s){
      if (s==0)
	{mexErrMsgTxt("The variance cannot be 0\n");return 0;}
      float r= 1/(s*sqrt(2*PI))*exp(-(x-mu)*(x-mu)/(2*s*s));
      return r;
}



mxArray *makeFeats(const mxArray *mximage,int *out, const mxArray *mxparams,int nrParams,int *fsz) {
  float *im = (float *)mxGetPr(mximage);
  const int *dims = mxGetDimensions(mximage);
  float *params=(float *)mxGetPr(mxparams);  //function that includes the parameters of gaussian functions

  if (mxGetNumberOfDimensions(mximage) != 2 ||
      mxGetClassID(mximage) != mxSINGLE_CLASS)
    mexErrMsgTxt("Invalid input, here is histogram of displacements");

  mxArray *mxfeat = mxCreateNumericArray(3, out, mxSINGLE_CLASS, mxREAL);
  float *feat = (float *)mxGetPr(mxfeat);  //final feats that will be returned
  float *feattemp=feat;
  for (int i=0;i<out[0]*out[1]*out[2];i++)//initialize array
	*(feattemp+i)=0;
  int middle_fsz[2];
  middle_fsz[0]=(fsz[0]+fsz[0]%2)/2-1;
  middle_fsz[1]=(fsz[1]+fsz[1]%2)/2-1;
  //int tempHist[nrParams]; //temp variable to hold the accumulation of points in the block
  int N=(nrParams-1)/2;
  int i, x, y, fx, fy, aux, hold; //variables that will be used in the loop, just declared here 
  float *middle_block, *current_feat, *first_elem_in_block, avgMiddle, difference; 
  for (y=0; y<dims[0]-fsz[0];y++){
	for (x=0;x<dims[1]-fsz[1];x++){
		middle_block=im+ (x+middle_fsz[1])*dims[0]+(y+middle_fsz[0]); //middle element of the block
			//size_t first_idx = (x+middle_fsz[1])*dims[0]+(y+middle_fsz[0]);
			//if ((first_idx < 0) || (first_idx >= dims[0]*dims[1]))
				//{mexPrintf("Sucker middle [x,y]=[%d,%d]\n",x,y); mexErrMsgTxt("Sucker middle\n");}
			
		avgMiddle=*middle_block;
		current_feat=feat+x*out[0]*fsz[1]+y*fsz[0]; //it's the reference point for our features for this x,y choice

		// loop over blocks of the selected area (filter size area)
		for (fy=0;fy<fsz[0];fy++){  //greg, replaced word blocky -> fy
		  for (fx=0;fx<fsz[1];fx++){
			first_elem_in_block=im + (x + fx)*dims[0]+ fy + y;
			//size_t first_idx = (x + fx)*dims[0]+ fy + y;
			//if ((first_idx < 0) || (first_idx >= dims[0]*dims[1]))
				//mexErrMsgTxt("Sucker 1\n");
			
			difference=*first_elem_in_block-avgMiddle;

			bool neg_flag=0;
			if (difference<0)
				{neg_flag=1; difference=-difference; }
			//difference=min(difference, *(params+N+1)-1);  //trick, because of padding (zero middle maybe), and also accuracy of floats
			//if (difference>=*(params+N+1))
			//	continue; 		// we don't save the value then, coz middle is in padding (zeros)
//if (difference>65536)
//mexPrintf("difference=%f, negflag=%d avgM=%f *first_elem_in_block=%f [%d,%d], [%d,%d]\n", difference, neg_flag, avgMiddle, *first_elem_in_block, y, x, fy,fx );
			//for (int i=0;i<=N;i++){
			i=0; hold=0;
			while ((hold<=0)&&(i<=N)){ // it is for granted that it will belong to an interval, thus no check required
				if ((difference>=*(params+i))&&(difference<*(params+i+1)))
					hold=i+N; //Anikei sto N+1 diastima, apla logw c ksekiname apo to 0
				i++;
			}
			if (neg_flag)
				hold=2*N-hold;
			//tempHist[hold]=1;

			aux=fy+fx*out[0];
			*(current_feat+aux+(hold)*out[0]*out[1])=1;
		 }
		}//*/

	 }
	}

    return mxfeat;
}

// matlab entry point
// C = fconv(A, cell of B, start, end);
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) { 
  if (nrhs != 7)
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

  int nrParams=(int)mxGetScalar(prhs[5]);
  int N=(int)mxGetScalar(prhs[6]);
  int out[3],fsz[2];
  // start threads
  thread_data *td = (thread_data *)mxCalloc(len, sizeof(thread_data));
  pthread_t *ts = (pthread_t *)mxCalloc(len, sizeof(pthread_t));
  const mwSize *A_dims = mxGetDimensions(mxA);
  const mwSize *A_dims_feats;
  //float *A = (float *)mxGetPr(mxA);
  float *A_n;
  for (int i = 0; i < len; i++) {
    const mxArray *mxB = mxGetCell(cellB, i+start);
    td[i].B_dims = mxGetDimensions(mxB);
    td[i].B = (float *)mxGetPr(mxB);
    if (mxGetNumberOfDimensions(mxB) != 3 ||
        mxGetClassID(mxB) != mxSINGLE_CLASS)
      mexErrMsgTxt("Invalid input: B");
    //td[i].A_dims = A_dims;
    //td[i].A = A;

	out[0]=(A_dims[0]-td[i].B_dims[0]+1)*td[i].B_dims[0];
	out[1]=(A_dims[1]-td[i].B_dims[1]+1)*td[i].B_dims[1];
	out[2]=nrParams;
	fsz[0]=td[i].B_dims[0];fsz[1]=td[i].B_dims[1];
	mxArray *mA;//=mxCreateNumericArray(3, out, mxSINGLE_CLASS, mxREAL);
	mA=makeFeats(mxA,out,prhs[4],2*N+1,fsz);
	A_n = (float *)mxGetPr(mA);
	td[i].A = A_n;
	A_dims_feats= mxGetDimensions(mA);       // greg, 17/2: If I try to assign in td[i] <- out a problems appears
	td[i].A_dims = A_dims_feats;
	//plhs[0] =mA; 
	/*for (int ii=0;ii<out[0];ii++)
	{for (int jj=0;jj<out[1];jj++)
		{float *d=A_n+ii+jj*out[0]+2*out[0]*out[1];
			//if ((*d)>0.1)
				mexPrintf("%f\t",*d);}
	   mexPrintf("\n");
	}
	mexPrintf("A=[%d,%d,%d]\n",td[i].A_dims[0],td[i].A_dims[1],td[i].A_dims[2]);*/
    // compute size of output
    int height = td[i].A_dims[0]/td[i].B_dims[0];
    int width = td[i].A_dims[1]/td[i].B_dims[1];
//mexPrintf("[h,w]=[%d,%d]\n",height,width);
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
