// This code isn't ready yet. Do not use it.
program DenseNetFashionMNIST;
(*
 Coded by Joao Paulo Schwarz Schuler.
 https://github.com/joaopauloschuler/neural-api
 This command line tool trains a DenseNet neural network with Fashion MNIST dataset.
*)
{$mode objfpc}{$H+}

uses {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads, {$ENDIF} {$ENDIF}
  Classes,
  SysUtils,
  CustApp,
  neuralnetwork,
  neuralvolume,
  Math,
  neuraldatasets,
  neuralfit;

type
  TTestCNNAlgo = class(TCustomApplication)
  protected
    fLearningRate, fInertia, fTarget: single;
    bSeparable: boolean;
    iInnerConvNum: integer;
    iBottleneck: integer;
    iConvNeuronCount: integer;
    procedure DoRun; override;
    procedure Train();
  public
    constructor Create(TheOwner: TComponent); override;
    procedure WriteHelp; virtual;
  end;

  procedure TTestCNNAlgo.DoRun;
  var
    ParStr: string;
  begin
    // parse parameters
    if HasOption('h', 'help') then
    begin
      WriteHelp;
      Terminate;
      Exit;
    end;

    fLearningRate := 0.001;
    if HasOption('l', 'learningrate') then
    begin
      ParStr := GetOptionValue('l', 'learningrate');
      fLearningRate := StrToFloat(ParStr);
    end;

    fInertia := 0.9;
    if HasOption('i', 'inertia') then
    begin
      ParStr := GetOptionValue('i', 'inertia');
      fInertia := StrToFloat(ParStr);
    end;

    fTarget := 1;
    if HasOption('t', 'target') then
    begin
      ParStr := GetOptionValue('t', 'target');
      fTarget := StrToFloat(ParStr);
    end;

    bSeparable := HasOption('s', 'separable');

    iInnerConvNum := 12;
    if HasOption('c', 'convolutions') then
    begin
      ParStr := GetOptionValue('c', 'convolutions');
      iInnerConvNum := StrToInt(ParStr);
    end;

    iBottleneck := 32;
    if HasOption('b', 'bottleneck') then
    begin
      ParStr := GetOptionValue('b', 'bottleneck');
      iBottleneck := StrToInt(ParStr);
    end;

    iConvNeuronCount := 32;
    if HasOption('n', 'neurons') then
    begin
      ParStr := GetOptionValue('n', 'neurons');
      iConvNeuronCount := StrToInt(ParStr);
    end;

    Train();

    Terminate;
  end;

  procedure TTestCNNAlgo.Train();
  var
    NN: THistoricalNets;
    NeuralFit: TNeuralImageFit;
    ImgTrainingVolumes, ImgValidationVolumes, ImgTestVolumes: TNNetVolumeList;
    NumClasses: integer;
    fileNameBase: string;
    HasMovingNorm: boolean;
  begin
    if Not(CheckMNISTFile('train', {IsFashion=}true)) or
      Not(CheckMNISTFile('t10k', {IsFashion=}true)) then exit;
    WriteLn('Creating Neural Network...');
    NumClasses  := 10;
    NN := THistoricalNets.Create();
    fileNameBase := 'DenseNetFashionMNIST';
    HasMovingNorm := true;
    NN.AddLayer( TNNetInput.Create(28, 28, 1).EnableErrorCollection() );
    // First block shouldn't be separable.
    NN.AddDenseNetBlockCAI(iInnerConvNum div 6, iConvNeuronCount, {supressBias=}0, TNNetConvolutionReLU, {IsSeparable=}false, {HasMovingNorm=}HasMovingNorm, {pBeforeNorm=}nil, {pAfterNorm=}nil, {BottleNeck=}iBottleneck, {Compression=}0, {Dropout=}0, {RandomAdd=}1, {RandomMul=}1);
    NN.AddDenseNetBlockCAI(iInnerConvNum div 6, iConvNeuronCount, {supressBias=}0, TNNetConvolutionReLU, {IsSeparable=}bSeparable, {HasMovingNorm=}HasMovingNorm, {pBeforeNorm=}nil, {pAfterNorm=}nil, {BottleNeck=}iBottleneck, {Compression=}0, {Dropout=}0, {RandomAdd=}1, {RandomMul=}1);
    NN.AddLayer( TNNetMaxPool.Create(2) );
    NN.AddDenseNetBlockCAI(iInnerConvNum div 3, iConvNeuronCount, {supressBias=}0, TNNetConvolutionReLU, {IsSeparable=}bSeparable, {HasMovingNorm=}HasMovingNorm, {pBeforeNorm=}nil, {pAfterNorm=}nil, {BottleNeck=}iBottleneck, {Compression=}0, {Dropout=}0, {RandomAdd=}1, {RandomMul=}1);
    NN.AddLayer( TNNetMaxPool.Create(2) );
    NN.AddDenseNetBlockCAI(iInnerConvNum div 3, iConvNeuronCount, {IsSeparable=}0, TNNetConvolutionReLU, {IsSeparable=}bSeparable, {HasMovingNorm=}HasMovingNorm, {pBeforeNorm=}nil, {pAfterNorm=}nil, {BottleNeck=}iBottleneck, {Compression=}0, {Dropout=}0, {RandomAdd=}1, {RandomMul=}1);
    NN.AddLayer( TNNetDropout.Create(0.10) );
    NN.AddLayer( TNNetMaxChannel.Create() );
    NN.AddLayer( TNNetFullConnectLinear.Create(NumClasses) );
    NN.AddLayer( TNNetSoftMax.Create() );

    WriteLn('Learning rate set to: [',fLearningRate:7:5,']');
    WriteLn('Inertia set to: [',fInertia:7:5,']');
    WriteLn('Target set to: [',fTarget:7:5,']');

    CreateMNISTVolumes(ImgTrainingVolumes, ImgValidationVolumes, ImgTestVolumes,
      'train', 't10k', {Verbose=}true, {IsFashion=}true);

    WriteLn('Neural Network will minimize error with:');
    WriteLn(' Layers: ', NN.CountLayers());
    WriteLn(' Neurons:', NN.CountNeurons());
    WriteLn(' Weights:', NN.CountWeights());
    NN.DebugWeights();
    NN.DebugStructure();

    NeuralFit := TNeuralImageFit.Create;
    NeuralFit.FileNameBase := fileNameBase;
    NeuralFit.InitialLearningRate := fLearningRate;
    NeuralFit.LearningRateDecay := 0.02;
    NeuralFit.CyclicalLearningRateLen := 100;
    NeuralFit.StaircaseEpochs := 15;
    NeuralFit.Inertia := fInertia;
    NeuralFit.TargetAccuracy := fTarget;
    NeuralFit.Fit(NN, ImgTrainingVolumes, ImgValidationVolumes, ImgTestVolumes, NumClasses, {batchsize=}64, {epochs=}300);
    NeuralFit.Free;

    NN.Free;
    ImgTestVolumes.Free;
    ImgValidationVolumes.Free;
    ImgTrainingVolumes.Free;
  end;

  constructor TTestCNNAlgo.Create(TheOwner: TComponent);
  begin
    inherited Create(TheOwner);
    StopOnException := True;
  end;

  procedure TTestCNNAlgo.WriteHelp;
  begin
    WriteLn
    (
      'DenseNet Fashion MNIST Classification Example by Joao Paulo Schwarz Schuler',sLineBreak,
      'Command Line Example: DenseNetFahionMNIST -i 0.8', sLineBreak,
      ' -h : displays this help. ', sLineBreak,
      ' -l : defines learing rate. Default is -l 0.001. ', sLineBreak,
      ' -i : defines inertia. Default is -i 0.9.', sLineBreak,
      ' -s : enables separable convolutions (less weights and faster).', sLineBreak,
      ' -c : defines the number of convolutions. Default is 12.', sLineBreak,
      ' -b : defines the bottleneck. Default is 32.', sLineBreak,
      ' -n : defines convolutional neurons (growth rate). Default is 32.', sLineBreak,
      ' https://github.com/joaopauloschuler/neural-api/tree/master/examples/DenseNetFahionMNIST',sLineBreak,
      ' More info at:',sLineBreak,
      '   https://github.com/joaopauloschuler/neural-api'
    );
  end;

var
  Application: TTestCNNAlgo;
begin
  Application := TTestCNNAlgo.Create(nil);
  Application.Title:='DenseNet Fashion MNIST Classification Example';
  Application.Run;
  Application.Free;
end.
