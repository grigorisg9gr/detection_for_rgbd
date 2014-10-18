//greg, 18/3/2014: Updated the features, so as to compute at the same time the features for rgb and depth
#include <math.h>
#include "mex.h"

// small value, used to avoid division by zero
#define eps 0.0001

// unit vectors used to compute gradient orientation
double uu[9] = {1.0000, 
		0.9397, 
		0.7660, 
		0.500, 
		0.1736, 
		-0.1736, 
		-0.5000, 
		-0.7660, 
		-0.9397};
double vv[9] = {0.0000, 
		0.3420, 
		0.6428, 
		0.8660, 
		0.9848, 
		0.9848, 
		0.8660, 
		0.6428, 
		0.3420};

static inline float min(float x, float y) { return (x <= y ? x : y); }
static inline float max(float x, float y) { return (x <= y ? y : x); }

static inline int min(int x, int y) { return (x <= y ? x : y); }
static inline int max(int x, int y) { return (x <= y ? y : x); }

// main function:
// takes a double image and a bin size 
// returns HOG features
mxArray *process(const mxArray *mximage, const mxArray *mxsbin) {
  double *im = (double *)mxGetPr(mximage);
  const int *dims = mxGetDimensions(mximage);
  if (mxGetNumberOfDimensions(mximage) != 3 ||
      dims[2] != 4 ||
      mxGetClassID(mximage) != mxDOUBLE_CLASS)
    mexErrMsgTxt("Invalid input");

  int sbin = (int)mxGetScalar(mxsbin);

  // memory for caching orientation histograms & their norms
  int blocks[2];
  blocks[0] = (int)round((double)dims[0]/(double)sbin);
  blocks[1] = (int)round((double)dims[1]/(double)sbin);
  float *hist = (float *)mxCalloc(blocks[0]*blocks[1]*18, sizeof(float));
  float *norm = (float *)mxCalloc(blocks[0]*blocks[1], sizeof(float));
  float *histd = (float *)mxCalloc(blocks[0]*blocks[1]*18, sizeof(float)); //same as above, but for depth features
  float *normd = (float *)mxCalloc(blocks[0]*blocks[1], sizeof(float));

  // memory for HOG features
  int out[3], num_features=27+4+1;
  out[0] = max(blocks[0]-2, 0);
  out[1] = max(blocks[1]-2, 0);
  out[2] = 2*num_features;
  mxArray *mxfeat = mxCreateNumericArray(3, out, mxSINGLE_CLASS, mxREAL);
  float *feat = (float *)mxGetPr(mxfeat);
  
  int visible[2];
  visible[0] = blocks[0]*sbin;
  visible[1] = blocks[1]*sbin;
  
  for (int x = 1; x < visible[1]-1; x++) {
    for (int y = 1; y < visible[0]-1; y++) {
      // first color channel
      double *s = im + min(x, dims[1]-2)*dims[0] + min(y, dims[0]-2);
      double dy = *(s+1) - *(s-1);
      double dx = *(s+dims[0]) - *(s-dims[0]);
      double v = dx*dx + dy*dy;

      // second color channel
      s += dims[0]*dims[1];
      double dy2 = *(s+1) - *(s-1);
      double dx2 = *(s+dims[0]) - *(s-dims[0]);
      double v2 = dx2*dx2 + dy2*dy2;

      // third color channel
      s += dims[0]*dims[1];
      double dy3 = *(s+1) - *(s-1);
      double dx3 = *(s+dims[0]) - *(s-dims[0]);
      double v3 = dx3*dx3 + dy3*dy3;

      //depth color channel
      s += dims[0]*dims[1];
      double dyd = *(s+1) - *(s-1);
      double dxd = *(s+dims[0]) - *(s-dims[0]);
      double vd = dxd*dxd + dyd*dyd;

      // pick channel with strongest gradient
      if (v2 > v) {
        v = v2;
        dx = dx2;
        dy = dy2;
      } 
      if (v3 > v) {
        v = v3;
        dx = dx3;
        dy = dy3;
      }

      // snap to one of 18 orientations
      double best_dot = 0, best_dotd = 0;
      int best_o = 0, best_od = 0;
      for (int o = 0; o < 9; o++) {
        double dot = uu[o]*dx + vv[o]*dy;
	double dotd= uu[o]*dxd + vv[o]*dyd;
        if (dot > best_dot) {
          best_dot = dot;
          best_o = o;
        } else if (-dot > best_dot) {
          best_dot = -dot;
          best_o = o+9;
        }
	//same for depth
        if (dotd > best_dotd) {
          best_dotd = dotd;
          best_od = o;
        } else if (-dotd > best_dotd) {
          best_dotd = -dotd;
          best_od = o+9;
        }
      }
      
      // add to 4 histograms around pixel using linear interpolation
      double xp = ((double)x+0.5)/(double)sbin - 0.5;
      double yp = ((double)y+0.5)/(double)sbin - 0.5;
      int ixp = (int)floor(xp);
      int iyp = (int)floor(yp);
      double vx0 = xp-ixp;
      double vy0 = yp-iyp;
      double vx1 = 1.0-vx0;
      double vy1 = 1.0-vy0;
      v = sqrt(v); vd = sqrt(vd);

      if (ixp >= 0 && iyp >= 0) {
        *(hist + ixp*blocks[0] + iyp + best_o*blocks[0]*blocks[1]) += 
          vx1*vy1*v;
        *(histd + ixp*blocks[0] + iyp + best_od*blocks[0]*blocks[1]) += 
          vx1*vy1*vd;
      }

      if (ixp+1 < blocks[1] && iyp >= 0) {
        *(hist + (ixp+1)*blocks[0] + iyp + best_o*blocks[0]*blocks[1]) += 
          vx0*vy1*v;
        *(histd + (ixp+1)*blocks[0] + iyp + best_od*blocks[0]*blocks[1]) += 
          vx0*vy1*vd;
      }

      if (ixp >= 0 && iyp+1 < blocks[0]) {
        *(hist + ixp*blocks[0] + (iyp+1) + best_o*blocks[0]*blocks[1]) += 
          vx1*vy0*v;
        *(histd + ixp*blocks[0] + (iyp+1) + best_od*blocks[0]*blocks[1]) += 
          vx1*vy0*vd;
      }

      if (ixp+1 < blocks[1] && iyp+1 < blocks[0]) {
        *(hist + (ixp+1)*blocks[0] + (iyp+1) + best_o*blocks[0]*blocks[1]) += 
          vx0*vy0*v;
        *(histd + (ixp+1)*blocks[0] + (iyp+1) + best_od*blocks[0]*blocks[1]) += 
          vx0*vy0*vd;
      }
    }
  } //end of x

  // compute energy in each block by summing over orientations
  for (int o = 0; o < 9; o++) {
    float *src1 = hist + o*blocks[0]*blocks[1];
    float *src2 = hist + (o+9)*blocks[0]*blocks[1];
    float *src1d = histd + o*blocks[0]*blocks[1];
    float *src2d = histd + (o+9)*blocks[0]*blocks[1];
    float *dst = norm;
    float *dstd = normd;
    float *end = norm + blocks[1]*blocks[0];
    while (dst < end) {
      *(dst++) += (*src1 + *src2) * (*src1 + *src2);
      *(dstd++) += (*src1d + *src2d) * (*src1d + *src2d);
      src1++; src1d++;
      src2++; src2d++;
    }
  }

  //////// compute features for rgb part //////// 
  for (int x = 0; x < out[1]; x++) {
    for (int y = 0; y < out[0]; y++) {
      float *dst = feat + x*out[0] + y;      
      float *src, *p, n1, n2, n3, n4;

      p = norm + (x+1)*blocks[0] + y+1;
      n1 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = norm + (x+1)*blocks[0] + y;
      n2 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = norm + x*blocks[0] + y+1;
      n3 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = norm + x*blocks[0] + y;      
      n4 = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);

      float t1 = 0;
      float t2 = 0;
      float t3 = 0;
      float t4 = 0;

      // contrast-sensitive features
      src = hist + (x+1)*blocks[0] + (y+1);
      for (int o = 0; o < 18; o++) {
        float h1 = min(*src * n1, 0.2);
        float h2 = min(*src * n2, 0.2);
        float h3 = min(*src * n3, 0.2);
        float h4 = min(*src * n4, 0.2);
        *dst = 0.5 * (h1 + h2 + h3 + h4);
        t1 += h1;
        t2 += h2;
        t3 += h3;
        t4 += h4;
        dst += out[0]*out[1];
        src += blocks[0]*blocks[1];
      }

      // contrast-insensitive features
      src = hist + (x+1)*blocks[0] + (y+1);
      for (int o = 0; o < 9; o++) {
        float sum = *src + *(src + 9*blocks[0]*blocks[1]);
        float h1 = min(sum * n1, 0.2);
        float h2 = min(sum * n2, 0.2);
        float h3 = min(sum * n3, 0.2);
        float h4 = min(sum * n4, 0.2);
        *dst = 0.5 * (h1 + h2 + h3 + h4);
        dst += out[0]*out[1];
        src += blocks[0]*blocks[1];
      }

      // texture features
      *dst = 0.2357 * t1;
      dst += out[0]*out[1];
      *dst = 0.2357 * t2;
      dst += out[0]*out[1];
      *dst = 0.2357 * t3;
      dst += out[0]*out[1];
      *dst = 0.2357 * t4;

      // truncation feature
      dst += out[0]*out[1];
      *dst = 0;
    }
  }


  //////// compute features for depth //////// 
  for (int x = 0; x < out[1]; x++) {
    for (int y = 0; y < out[0]; y++) {

      float *dstd = feat + x*out[0] + y+(num_features)*out[0]*out[1];      
      float  *srcd, *p, n1d, n2d, n3d, n4d;


      p = normd + (x+1)*blocks[0] + y+1;
      n1d = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = normd + (x+1)*blocks[0] + y;
      n2d = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = normd + x*blocks[0] + y+1;
      n3d = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);
      p = normd + x*blocks[0] + y;      
      n4d = 1.0 / sqrt(*p + *(p+1) + *(p+blocks[0]) + *(p+blocks[0]+1) + eps);

      float t1d = 0;
      float t2d = 0;
      float t3d = 0;
      float t4d = 0;

      // contrast-sensitive features
      srcd = histd + (x+1)*blocks[0] + (y+1);
      for (int o = 0; o < 18; o++) {
        float h1d = min(*srcd * n1d, 0.2);
        float h2d = min(*srcd * n2d, 0.2);
        float h3d = min(*srcd * n3d, 0.2);
        float h4d = min(*srcd * n4d, 0.2);
        *dstd = 0.5 * (h1d + h2d + h3d + h4d);
        t1d += h1d;
        t2d += h2d;
        t3d += h3d;
        t4d += h4d;
        dstd += out[0]*out[1];
        srcd += blocks[0]*blocks[1];
      }

      // contrast-insensitive features
      srcd = histd + (x+1)*blocks[0] + (y+1);
      for (int o = 0; o < 9; o++) {

        float sumd = *srcd + *(srcd + 9*blocks[0]*blocks[1]);
        float h1d = min(sumd * n1d, 0.2);
        float h2d = min(sumd * n2d, 0.2);
        float h3d = min(sumd * n3d, 0.2);
        float h4d = min(sumd * n4d, 0.2);
        *dstd = 0.5 * (h1d + h2d + h3d + h4d);
        dstd += out[0]*out[1];
        srcd += blocks[0]*blocks[1];
      }

      *dstd = 0.2357 * t1d;
      dstd += out[0]*out[1];
      *dstd = 0.2357 * t2d;
      dstd += out[0]*out[1];
      *dstd = 0.2357 * t3d;
      dstd += out[0]*out[1];
      *dstd = 0.2357 * t4d;

      // truncation feature
      dstd += out[0]*out[1];
      *dstd = 0;
    }
  }

  mxFree(hist);mxFree(histd);
  mxFree(norm);mxFree(normd);
  return mxfeat;
}

// matlab entry point
// F = features_64(image, bin)
// image should be with 4 channels (3 first are the rgb and the 4th is the depth) with depth values
void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[]) { 
  if (nrhs != 2)
    mexErrMsgTxt("Wrong number of inputs"); 
  if (nlhs != 1)
    mexErrMsgTxt("Wrong number of outputs");
  plhs[0] = process(prhs[0], prhs[1]);
}



