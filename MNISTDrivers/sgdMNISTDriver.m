addpath(genpath('/home/samywu/ADMMSoftmax_Matlab'))

clear all; 
% clc;

% clc;

% load('Alexnet/featureExt50000.mat');
N = 50000; Nval = 0.2*N;
[Dtrain,Ctrain,Yval,Cval] = setupMNIST(N, Nval);

Dtrain = reshape(Dtrain, 28*28, N);
Yval = reshape(Yval, 28*28, Nval); 

fprintf('maxY = %1.2e, minY = %1.2e', max(Dtrain(:)), min(Dtrain(:)));

channelsIn = 1; 
channelsOut = 9;
nImg = [28 28];

fprintf(' number of training examples: %d \n\n', N);


%% extreme learning
% kernel size
sK = [3, 3, channelsIn, channelsOut]; %3x3 convolution window
Ker = convFFT(nImg, sK);
th   = randn(nTheta(Ker),1);
% load('K.mat')
K  = getOp(Ker,th);
Dtrain = tanh(K*Dtrain); Yval = tanh(K*Yval);

Dtrain = reshape(Dtrain, [], N); Yval = reshape(Yval, [], Nval);

nf = size(Dtrain,1); nc = size(Ctrain,1);

%% start optimization
addBias=true;

%% regularization
% smoothness reg. operator
fprintf('using smoothness! reg. operator...\n')
Ltemp = getLaplacian(nImg, 1./nImg);

L = genBlkDiag(Ltemp,channelsOut-1);

%  add bias to laplace operator 
if addBias==true
    L = sparse([L zeros(size(L,1),1); zeros(1,size(L,2)) 1]);
end

Lout = sparse(genBlkDiag(L, nc-1));

% account for mesh size: 
Lout = Lout/(nf);
L    = L/(nf);

fprintf('size of Lout = %d...\n', size(Lout,1))
fprintf('length of W = %d...\n', nf*nc)
    
alpha = 1e-1; miniBatch=40; lr0 = 1e-2;

fprintf('\n\n lr0 = %1.2e, ALPHA = %1.2e, minibatch = %d \n', lr0, alpha, miniBatch);

%% set up optimization
pRegW   = tikhonovReg(Lout,alpha);
pLoss   = softmaxLoss();
f       = classObjFctn(pLoss,pRegW,Dtrain,Ctrain);
fTest   = classObjFctn(pLoss,pRegW,Yval,Cval);

f.pLoss.addBias=addBias; fTest.pLoss.addBias=addBias;

vec     = @(x) x(:);

if addBias==false
    W0      = vec(randn(nf,nc));
else
    W0      = vec(randn(nf+1,nc));
end

    %% sgd setup
    opt           = sgd('out',1);
    opt.nesterov=false;
    opt.rtol      = 1e-3;
    opt.atol      = 1e-3;
    opt.miniBatch = miniBatch;
    opt.maxEpochs = 100;
    opt.learningRate = @(epoch) lr0/sqrt(epoch);
    opt.stoppingTime = 500; %seconds


    %% solve
    tSolve = tic
    [Wopt, hisOpt] = solve(opt,f,W0, fTest);
    tSolve = toc(tSolve)

    fprintf('\n\n ALPHA = %1.2e, fTrain = %1.2e, fTest = %1.2e, trainAcc = %1.2f, testAcc=%1.2f\n\n', ...
        alpha, hisOpt.his(end,9), hisOpt.his(end,13), hisOpt.his(end,10), hisOpt.his(end,13)); %14 for newton

atol = opt.atol; rtol = opt.rtol; miniBatch = opt.miniBatch;
save('sgdResultsMNIST.mat', 'hisOpt', 'Wopt', 'alpha', 'atol', 'miniBatch', 'rtol')