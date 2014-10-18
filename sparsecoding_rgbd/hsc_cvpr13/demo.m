
addpath ../PASCAL
addpath dictionaries
load ../PASCAL/models/chair_model_1.mat

im=imread('118.png');
boxes = detect([], im, model, -1);


