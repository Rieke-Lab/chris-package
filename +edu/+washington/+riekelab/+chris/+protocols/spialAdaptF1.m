clearvars; close all;
import stage.core.*
obj.apertureDiameter=400;
obj.barWidth=100;
obj.flashDuration=50;  % ms
obj.fixFlashTime=100;
obj.variableFlashTime=[50 100 200 400];
obj.spatialContrast=0.5;
obj.temporalContrast=0.5;
obj.backgroundIntensity=0.05;
obj.stepIntensity=0.2;
obj.preTime=1000;
obj.stimTime=2000;
obj.tailTime=1000;
obj.downSample=1;
obj.imgName='img029';

flashIndex=3;
pattern='patch';

obj.imgDir='D:\research\rieke_lab\resources\subjectTrajectory\';
obj.currentFlashDelay=obj.variableFlashTime(flashIndex);
obj.flashTimes=[obj.fixFlashTime obj.preTime+obj.currentFlashDelay obj.preTime+obj.stimTime-obj.fixFlashTime ...,
    obj.preTime+obj.stimTime+obj.currentFlashDelay  obj.preTime+obj.stimTime+obj.tailTime-obj.fixFlashTime];

window=Window([800 600],false);

canvas=Canvas(window);
canvasSize=[800 600];
p=Presentation((obj.preTime+obj.stimTime+obj.tailTime)*1e-3);
p.setBackgroundColor(obj.backgroundIntensity);

% create natural image patch for adapting
imgData=load(fullfile(obj.imgDir, obj.imgName));
picture=imgData.information.picture;
patchLocs=floor(imgData.information.patchToAdapt.fixLocs);
obj.apertureDiamter=2*floor(obj.apertureDiameter/2);
obj.patchAdapt=picture(patchLocs(1)-obj.apertureDiameter/2:obj.downSample:patchLocs(1)+obj.apertureDiameter/2-1, ...,
    patchLocs(2)-obj.apertureDiameter/2:obj.downSample:patchLocs(2)+obj.apertureDiameter/2-1);
obj.patchAdapt=obj.patchAdapt';
% create matrix for adapting and flashing
switch pattern
    case 'spot'
        obj.adaptMatrix.base=createGrateMat(obj.backgroundIntensity,0,obj.apertureDiameter,obj.barWidth,0,'seesaw',obj.downSample);
        obj.adaptMatrix.step=createGrateMat(obj.stepIntensity,0,obj.apertureDiameter,obj.barWidth,0,'seesaw',obj.downSample);
    case 'grating'
        obj.adaptMatrix.base=createGrateMat(obj.backgroundIntensity,obj.spatialContrast,obj.apertureDiameter,obj.barWidth,0,'seesaw',obj.downSample);
        obj.adaptMatrix.step=createGrateMat(obj.stepIntensity,obj.spatialContrast,obj.apertureDiameter,obj.barWidth,0,'seesaw',obj.downSample);
    case 'patch'
        obj.adaptMatrix.base=normImg(obj.patchAdapt,obj.backgroundIntensity);
        obj.adaptMatrix.step=normImg(obj.patchAdapt,obj.stepIntensity);
        
end
obj.testMatrix.base=createGrateMat(obj.backgroundIntensity*obj.temporalContrast,0, obj.apertureDiameter, obj.barWidth,0,'seesaw',obj.downSample);  % this create the test grating
obj.testMatrix.step=createGrateMat(obj.stepIntensity*obj.temporalContrast,0, obj.apertureDiameter, obj.barWidth,0,'seesaw',obj.downSample);  % this create the test grating


obj.startMatrix=uint8(obj.adaptMatrix.base);
scene=stage.builtin.stimuli.Image(obj.startMatrix);
scene.size = [obj.apertureDiameter obj.apertureDiameter]; %scale up to canvas size
scene.position =[400 300];
% Use linear interpolation when scaling the image.
scene.setMinFunction(GL.LINEAR);
scene.setMagFunction(GL.LINEAR);
p.addStimulus(scene);

sceneController = stage.builtin.controllers.PropertyController(scene, 'imageMatrix',...
    @(state)getImgMatrixProbeWithSpot(obj, state.time));
p.addController(sceneController);

% add aperture
if obj.apertureDiameter>0
    aperture=stage.builtin.stimuli.Rectangle();
    aperture.position=canvasSize/2;
    aperture.size=[obj.apertureDiameter obj.apertureDiameter];
    mask=Mask.createCircularAperture(1,1024);
    aperture.setMask(mask);
    p.addStimulus(aperture);
    aperture.color=obj.backgroundIntensity;
end
p.play(canvas);