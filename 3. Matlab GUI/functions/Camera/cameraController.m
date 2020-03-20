% Camera Controller
imaqreset
% Initiate driver
[vid,vidInfo]=InitCamera();

% Customized parameters
src = getselectedsource(vid);
AllParameters=get(vid);
set(vid,'FramesPerTrigger',1);
set(vid,'TriggerRepeat',Inf);
vidRes=get(vid,'VideoResolution');

flushdata(vid);
start(vid);

% Create Fig
fHandle=figure('Name','Camera Control');
axFigure = axes(fHandle,'Position',[0.15 0.15 0.8 0.8],'Box','on');
im = image(zeros(vidRes(2),vidRes(1)), 'Parent', axFigure);
ButtonHandle = uicontrol(fHandle,'Style', 'PushButton', ...
                         'String', 'Stop recording', ...
                         'Callback', 'delete(gcbf)');
previewFLIR(vid, im); 
%flushdata(vid,'triggers');
% while(1)  
%   %
%    fANum=get(vid,'FramesAvailable');
%    if(fANum>=1)
%      %data = getdata(vid);
%      disp(['Frames available: ' num2str(fANum)]);
%      flushdata(vid);
%    end
%   if ~ishandle(ButtonHandle)
%     disp('Loop stopped by user');
%     break;
%   end
%   pause(0.01); %
% end
% 
% % %% Remove the video input object from memory.
%  closepreview(vid)
%  delete(vid)
%  clear
%  close(gcf)