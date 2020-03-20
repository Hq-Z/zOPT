function outputhandle = previewFLIR(obj, targetImage,channel)
%PREVIEW Display preview of live video data.
% 
%    PREVIEW(OBJ) creates a Video Preview window that displays live video
%    data for video input object OBJ. The window also displays the timestamp
%    and video resolution of each frame, and the current status of OBJ. The
%    Video Preview window displays the video data at 100% magnification (one 
%    screen pixel represents one image pixel). The size of the preview image
%    is determined by the value of the video input object ROIPosition 
%    property.
%
%    The Video Preview window remains active until it is either stopped using
%    STOPPREVIEW or closed using CLOSEPREVIEW. If you delete the object, 
%    DELETE(OBJ), the Video Preview window stops previewing and closes
%    automatically.
%    
%    PREVIEW(OBJ, HIMAGE) displays live video data for video input object
%    OBJ in the image object specified by the handle HIMAGE. PREVIEW scales
%    the image data to fill the entire area of the image object but does not
%    modify the values of any image object properties. Use this syntax to  
%    preview video data in a custom GUI of your own design (see Examples).
%
%    HIMAGE = PREVIEW(...) returns HIMAGE, a handle to the image object 
%    containing the previewed data. To obtain a handle to the figure window
%    containing the image object, use ANCESTOR. For more information about 
%    using image objects, see IMAGE. See the Custom Update Function section
%    for more information about the image object returned.
%
%    Notes
%    -----
%     
%    The behavior of the Video Preview window depends on the object's current
%    state and trigger configuration.
%    
%       State           Video Preview Window Behavior
%    ----------------------------------------------------------------------
%     Running=off    Displays a live view of the image being acquired from
%                    the device, for all trigger types. The image is updated 
%                    to reflect changes made to configurations of video 
%                    input object properties. (The FrameGrabInterval 
%                    property is ignored until a trigger occurs.)
%
%     Running=on     If TriggerType is set to immediate or manual, the Video
%                    Preview window continues to update the image displayed.
%                    If TriggerType is set to hardware, the Video Preview 
%                    window stops updating the image until a trigger
%                    occurs.
%     
%     Logging=on     The Video Preview window might drop some data frames,
%                    but this will not affect the frames logged to memory 
%                    or disk.
%
%    Custom Update Function
%    ----------------------
%    If you specify the image object where you want PREVIEW to display  
%    video data, you can also specify a function that PREVIEW calls for
%    every update. PREVIEW assigns application-defined data, specified by
%    the name 'UpdatePreviewWindowFcn', to the image object, HIMAGE. Use
%    the SETAPPDATA function, to set the value of 'UpdatePreviewWindowFcn'
%    to a function handle that PREVIEW will invoke for each update. You can
%    use this function to perform custom processing of the previewed image
%    data. If 'UpdatePreviewWindowFcn' is configured to [] (the default),
%    PREVIEW ignores it. If it is configured to any value other than a
%    function handle or [], PREVIEW errors.
%
%    The 'UpdatePreviewWindowFcn' will not necessarily be called for every
%    frame that is acquired.  If a new frame is acquired and the
%    'UpdatePreviewWindowFcn' for the previous frame has not yet finished
%    executing, no update will be generated for the new frame.  If you need
%    to execute a function for every acquired frame, use the
%    FramesAcquiredFcn instead.
%
%    NOTE: When you specify an ‘UpdatePreviewWindowFcn’ function, your 
%    function is responsible for displaying video data in the image object.
%    Your function can process the data before displaying it, after
%    displaying it, or both. Use this code to display the data:
%
%        set(HIMAGE, 'CData', event.Data)
%
%    When PREVIEW invokes the update function you specify, it passes three 
%    arguments:
%
%        OBJ         The video input object being previewed
%        EVENT       An event structure with image frame information
%        HIMAGE      The handle to the image object being updated
%
%    The event structure contains all of the following fields:
%
%        Data        Current image frame specified as an H-by-W-by-B array,
%                    where H and W are the image height and width, as 
%                    specified in the ROIPosition property, and B is the 
%                    number of color bands, as specified in the NumberOfBands
%                    property.
%        Resolution  String specifying current image width and height, as 
%                    defined by the ROIPosition property.
%        Status      String describing the acquisition status.
%        Timestamp   String specifying the timestamp associated with the 
%                    current image frame.
%
%    Examples
%       % Create a customized GUI.
%       figure('Name', 'My Custom Preview Window');
%       uicontrol('String', 'Close', 'Callback', 'close(gcf)');
%
%       % Create an image object for previewing.
%       vidRes = get(obj, 'VideoResolution');
%       nBands = get(obj, 'NumberOfBands');
%       hImage = image( zeros(vidRes(2), vidRes(1), nBands) );
%       preview(obj, hImage);
%    
%    See also ANCESTOR, FUNCTION_HANDLE, IMAGE, IMAQHELP,  
%    IMAQDEVICE/CLOSEPREVIEW, IMAQDEVICE/STOPPREVIEW, IMAQDEVICE/START,
%    IMAQDEVICE/TRIGGER, IMAQDEVICE/DELETE, <a href="matlab:imaqhelp('FramesAcquiredFcn')">FramesAcquiredFcn</a>.

%    CP 9-01-01
%    Copyright 2001-2016 The MathWorks, Inc.

% Error checking.
if ~isa(obj, 'imaqdevice')
    error(message('imaq:preview:invalidType'));
elseif ~all(isvalid(obj))
    error(message('imaq:preview:invalidOBJ'));
end

if nargin==2
    % Verify HIMAGE passed in is valid.
    if ~isvector(targetImage) || ~all( ishandle(targetImage) ) || ...
            length(targetImage) ~= length(obj) || ...
            ~all( strcmpi( get(targetImage, 'Type'), 'image' ) )
        error(message('imaq:preview:invalidHIMAGE'));
    end
end

% Access the internal UDD object.
uddobj = imaqgate('privateGetField', obj, 'uddobject');

% Use the obsolete window if need be.
if imaqmex('feature', '-useObsoletePreview')
    preview(uddobj);
    
    % Only assign the output LHS if one was specified. This
    % avoids having ANS appear every time PREVIEW is called.
    if nargout>0
        outputhandle = [];
    end
    return;
end

% Do not preallocate this array since the number of image objects 
% we return may be less than the number of objects, i.e. if some 
% objects error out upon calling preview on them.
hImageArray = [];

% For each object, try to activate a preview window.
alreadyWarned = false;
isSingleton = (length(uddobj)==1);
for index=1:length(uddobj)
    try
        if nargin==3
            % First check the target image is not already 
            % associated with another object.
            trgtClients = localFindTargetClients( uddobj(index), targetImage(index) );
            if ~isempty(trgtClients);
                % Target image is being used by another object.
                error(message('imaq:preview:noTargetReuse'));
            end
            
            currentImage = localPreview( uddobj(index), targetImage(index) );
            if(channel==1)
                currentImage=currentImage(:,:,1);
            elseif(channel==2)
                currentImage=currentImage(:,:,2);
            elseif(channel==3)
                currentImage=currentImage(:,:,3);
            end
        else
            currentImage = localPreview( uddobj(index), [] );
            if(channel==1)
                currentImage=currentImage(:,:,1);
            elseif(channel==2)
                currentImage=currentImage(:,:,2);
            elseif(channel==3)
                currentImage=currentImage(:,:,3);
            end
        end
        hImageArray = [hImageArray; currentImage]; %#ok<AGROW>
    catch previewError
        % Error if we're dealing with a 1x1 object, otherwise warn.
        if isSingleton
            throw(previewError);
        elseif ~alreadyWarned
            warnState = warning('off', 'backtrace');
            oc = onCleanup(@()warning(warnState));
            warning(message('imaq:preview:openFailed', previewError.message));
            clear('oc');
            alreadyWarned = true;
        end
    end
end

% Only assign the output LHS if one was specified. This 
% avoids having ANS appear every time PREVIEW is called.
if nargout>0
    outputhandle = hImageArray;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function outputhandle = localPreview(uddobj, targetImage)

% Access the handle settings.
handles = localGetHandles(uddobj, targetImage);
if strcmpi( get(uddobj, 'Previewing') , 'on')
    % Give the active window focus.
    figure(handles.Figure);
    outputhandle = handles.Image;
    return;
end

% Verify object is in a previewable state before creating a new window.
% The device might be in use by another preview window.
if ishardwareactive(uddobj)
    error(message('imaq:preview:deviceInUse'));
end

% If no window has already been created before calling
% PREVIEW, the object needs a default one created.
if isempty(handles.Figure)
    % Create the default preview window.
    handles = localCreateDefaultWindow(uddobj, handles);
end

% Configure the figure's colormap.
localConfigureColormap(uddobj, handles);

% Setup HG components for optimal performance.
localSetupHGComponents(uddobj, handles);

% Configure the image object's app data.
localSetImageAppData(uddobj, handles);

% Configure our object with the callbacks and handles.
set(uddobj, 'ZZZUpdatePreviewFcn', @localUpdateWindow);
set(uddobj, 'ZZZUpdatePreviewStatusFcn', @localUpdateStatus);
set(uddobj, 'ZZZPreviewWindowHandles', handles);

% Pop the figure forward.
figure(handles.Figure);

% Initiate the data stream.
preview(uddobj);

% Assign output.
outputhandle = handles.Image;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CALLBACK FUNCTIONS FOR DEFAULT & CUSTOM WINDOWS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localUpdateStatus(uddobj, event)

% Update the preview window status.
handles = get(uddobj, 'ZZZPreviewWindowHandles');

if isempty(handles)
    return;
end

if handles.isDefaultWindow
    % Update the status message only. Timestamp and
    % resolution is only handled when there is actual
    % data available.
    set(handles.StatusFields.Status, 'String', event.Data.Status);
else
    % We're either dealing with an intermediate custom
    % window, or an advanced custom window.
    try
        % Invoke the user's function, i.e. handle the
        % advanced custom window case first.
        event.Data.Data = [];
        flushdata(uddobj);
        localInvokeAppData(uddobj, event.Data, handles.Image, getappdata(handles.Image, 'UpdatePreviewStatusFcn'));
    catch updateMessageError
        throw(updateMessageError);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localUpdateWindow(uddobj, event)

% Extract our handles.
handles = get(uddobj, 'ZZZPreviewWindowHandles');

if handles.isDefaultWindow
    % We're dealing with the default preview window.
    try
        % Update the image data.
        handles = localUpdateDefaultImage(handles, uddobj, event.Data.Data);
        set(uddobj, 'ZZZPreviewWindowHandles', handles);

        % Update the status bar.
        set(handles.StatusFields.Time, 'String', event.Data.Timestamp);
        set(handles.StatusFields.Resolution, 'String', event.Data.Resolution);
        set(handles.StatusFields.Status, 'String', event.Data.Status);
        set(handles.StatusFields.FramesPerSecond, 'String', event.Data.FrameRate);
    catch customPreviewError
        % Now that we can control the preview window from Java, it is
        % possible to delete the underlying object in the middle of an
        % update.  If we do that, don't error since it is an expected
        % action.
        if (ishandle(uddobj))
            error(message('imaq:preview:updateImageFailed', customPreviewError.message));
        end
    end
else
    % We're either dealing with an intermediate custom 
    % window, or an advanced custom window.
    try
        % Invoke the user's function, i.e. handle the
        % advanced custom window case first.
        fcnSpecified = localInvokeAppData(uddobj, event.Data, handles.Image, getappdata(handles.Image, 'UpdatePreviewWindowFcn'));
        if ~fcnSpecified
            % No function was specified, so just update the 
            % image data, i.e. handle the intermediate custom
            % window case.
            set(handles.Image, 'CData', event.Data.Data);
        end
    catch customPreviewError
        throw(customPreviewError);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function fcnSpecified = localInvokeAppData(uddobj, eventData, hImage, usersFcn)

if isempty(usersFcn)
    % Nothing to execute.
    fcnSpecified = false;
    return;    
elseif strcmp(class(usersFcn), 'function_handle')
    % Notify the user the image was updated.
    try
        usersFcn( videoinput(uddobj), eventData, hImage );
        fcnSpecified = true;
    catch appDataError
        error(message('imaq:preview:updateFunctionFailed', appDataError.message));
    end    
else
    % Invalid value specified.
    error(message('imaq:preview:invalidUpdateFunction'));
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localImageDeleteFcn(hImage, hgevent, uddobj) %#ok<INUSL,INUSL>

% Make sure the UDD object is still valid. User might be 
% closing the window after having deleted the UDD object.
if ishandle(uddobj)
    % Disconnect image handle/callback from object.
    set(uddobj, 'ZZZUpdatePreviewFcn', '');
    set(uddobj, 'ZZZUpdatePreviewStatusFcn', '');
    set(uddobj, 'ZZZPreviewWindowHandles', []);
    
    % Stop previewing data.
    stoppreview(uddobj);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localResizeDefaultFcn(hFig, hgevent, handles, statusCharHeight) %#ok<INUSL,INUSL>

% Determine how many character ticks we have to 
% play with in the figure.
set(handles.Figure, 'Units', 'characters');
figCharPos = get(handles.Figure, 'Position');
set(handles.Figure, 'Units', 'normalized');

% Determine how much height we have for the image panel.
availImPanelHeight = figCharPos(4) - statusCharHeight;
if availImPanelHeight <= 0
    % Not enough room to resize.
    return;
end

% Resize the image panel.
set(handles.ImagePanel, 'Units', 'characters');
set(handles.ImagePanel, ...
    'Position', [0 statusCharHeight figCharPos(3) availImPanelHeight]);
set(handles.ImagePanel, 'Units', 'normalized');

% Resize the status bar container.
set(handles.StatusContainer, 'Units', 'characters');
set(handles.StatusContainer, ...
    'Position', [0 0 figCharPos(3) statusCharHeight]);
set(handles.StatusContainer, 'Units', 'normalized');

% Determine how much width we have for the status info section.
statusPanelPos = get(handles.StatusPanels.Status, 'Position');
availStatusWidth = figCharPos(3) - statusPanelPos(1);
if availStatusWidth <= 0
    % Not enough room to resize.
    return;
end

% Stretch the status info panel to the figure's width.
set(handles.StatusPanels.Status, ...
    'Position', [statusPanelPos(1:2) availStatusWidth statusPanelPos(4)]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% UTILITY FUNCTIONS FOR DEFAULT & CUSTOM WINDOWS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = localGetHandles(uddobj, targetImage)

% Get a hold of our handles.
handles = get(uddobj, 'ZZZPreviewWindowHandles');
if isempty(handles)
    % Handles is empty, i.e. handles = [].
    % Initialize them with the correct fields.
    if isempty(targetImage)
        handles = localInitHandleStructure;
    else
        handles = localInitHandleStructure(targetImage);
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = localInitHandleStructure(targetImage)

% Initialize the handles structure to [].
handles.Axis = [];
handles.Image = [];
handles.Figure = [];
handles.ScrollPanelParent = [];
handles.isDefaultWindow = true;
handles.ImagePanel = [];
handles.ScrollPanel = [];
handles.StatusPanels = [];
handles.StatusFields = [];
handles.StatusContainer = [];

% Check for target image.
if nargin==1
    % Initialize the handles structure based 
    % on the target image supplied.
    handles.Axis = ancestor(targetImage, 'axes');
    handles.Image = targetImage;
    handles.Figure = ancestor(targetImage, 'figure');
    
    % Scroll panel requires a uipanel or figure as the
    % scroll panel parent. For robustness, make sure this
    % is true in case the user's GUI is atypical.
    axParent = get(handles.Axis, 'Parent');
    axParentType = get(axParent, 'Type');
    if any( strcmpi( axParentType, {'figure', 'uipanel'} ) )
        handles.ScrollPanelParent = axParent;
    else
        % User's axis parent can't be used as a 
        % parent for the scroll panel. Just use the figure.
        handles.ScrollPanelParent = handles.Figure;
    end

    % Flag this as a custom window.
    handles.isDefaultWindow = false;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function objs = localFindTargetClients(uddobj, targetImage)

% Initialize.
objs = [];
allObjs = imaqfind;

% Check if no objects have a target image associated with them.  In that
% case, just return.
objsWithNoTarget = imaqfind('ZZZPreviewWindowHandles', []);

if (length(allObjs) == length(objsWithNoTarget))
    return;
end

% Determine the objects that have a target image association with them.
objsWithTargetIndices = [];

for curIndex = 1:length(allObjs)
    curObj = subsref(allObjs, substruct('()', curIndex));
    if ~isempty(get(curObj, 'ZZZPreviewWindowHandles'))
        objsWithTargetIndices(end+1) = curIndex; %#ok<AGROW>
    end
end

objsWithTarget = subsref(allObjs, substruct('()', objsWithTargetIndices));

% For each object that has a target image associated with it,
% check for any possible conflicts of 2 different objects trying
% to use the same target image.
uddobjsWithTarget = imaqgate('privateGetField', objsWithTarget, 'uddobject');
for index=1:length(uddobjsWithTarget)
    handles = get(uddobjsWithTarget(index), 'ZZZPreviewWindowHandles');
    
    % Exclude the object about to be previewed, in order to 
    % allow the following scenario to succeed:
    %    x = preview(vid);
    %    preview(vid, x);
    if ~isequal(uddobj, uddobjsWithTarget(index)) && handles.Image==targetImage
        objs = [objs uddobjsWithTarget(index)]; %#ok<AGROW>
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localSetImageAppData(uddobj, handles) %#ok<INUSL>

% Cache the handles as part of our image object.
setappdata(handles.Image, 'PreviewWindowHandles', handles);

% Initialize the user configurable update callback if
% it doesn't already exist. Otherwise, just leave it 
% with whatever it is currently set to.
if ~isappdata(handles.Image, 'UpdatePreviewWindowFcn')
    setappdata(handles.Image, 'UpdatePreviewWindowFcn', []);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localSetupHGComponents(uddobj, handles)

% Configure the image object. 
%
% The image object must be set up with the appropriate CData size,
% otherwise a portion of the image will be shown. Secondly, the image
% object, MUST be set up first so that the axes scale correctly. Otherwise,
% the image won't scale correctly with axes limit modes turned to manual.

% Determine the number of bands for the CData
if strcmp(get(uddobj, 'ReturnedColorSpace'), 'grayscale')
    numBands = 1;
else
    numBands = 3;
end

roi = get(uddobj, 'ROIPosition');
data = localGetDefaultImageData(roi);
set(handles.Image, {'CData', 'DeleteFcn'}, ...
    {data, {@localImageDeleteFcn, uddobj} });

% Configure the axis and image for optimal refresh. This 
% should be done regardless whose HG components we're using.
set(handles.Axis, 'Visible', 'off', 'CLimMode', 'manual', 'CLim', [0 255],...
    'ALimMode', 'manual', 'XLimMode', 'manual', 'YLimMode', 'manual', ...
    'ZLimMode', 'manual', 'XTickMode', 'manual', 'YTickMode', 'manual');
    %'ZTickMode', 'manual'  g1493533: Removing ZTickMode for now to get preview working with AppDesigner.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function data = localGetDefaultImageData(roi)

% Create a RGB matrix for red cross.
red = ones(roi(4),roi(3));

% Find the larger dimension
if ( roi(4) >= roi(3))
    maxIndex = 4;
    minIndex = 3;
else
    maxIndex = 3;
    minIndex = 4;
end
% Create a matrix with a cross for the smaller dimension.
blue = ~ (eye(roi(minIndex)) + fliplr(eye(roi(minIndex))));
% Now add the remaining padding at both sides.
pad_left = ceil((roi(maxIndex)-roi(minIndex))/2);
pad_right = floor((roi(maxIndex)-roi(minIndex))/2);
if ( roi(4) >= roi(3) )
    blue = [ones( pad_left,roi(minIndex));blue;ones( pad_right,roi(minIndex))];
else
    blue = [ones(roi(minIndex),pad_left), blue, ones(roi(minIndex),pad_right)];
end
green = blue;

% Create the RGB 3D matrix.
data(:,:,1) = red;
data(:,:,2) = blue;
data(:,:,3) = green;



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localConfigureColormap(uddobj, handles) %#ok<INUSL>

set(handles.Figure, 'Colormap', gray(256));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEFAULT WINDOW SPECIFIC FUNCTIONS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = localCreateDefaultWindow(uddobj, handles)

% Access preview settings.
propValues = get(uddobj, {'ROIPosition', 'ObjectConstructorArguments'});
roi = propValues{1};
args = propValues{2};
uddclass = class(uddobj);

% Height of status bar in character units.
statusCharHeight = 1.25;

% Create a new figure.
objWinName = sprintf('Video Preview - %s:%i', args{1}, args{2});
handles.Figure = figure('Tag', uddclass, 'MenuBar', 'none', ...
    'Visible', 'off', 'ToolBar', 'none', 'NumberTitle', 'off', ...
    'Name', objWinName);

% Determine correct color map. Also leave double buffer
% on so image doesn't flash when scrolling.
set(handles.Figure, 'HandleVisibility', 'off', 'Units', 'pixels');

% Setup the status bar.
handles = localSetupDefaultStatusArea(uddobj, handles, statusCharHeight);

% Setup a new axis, image, and scroll panel.
handles = localSetupDefaultImageArea(handles, roi, statusCharHeight);

% Squeeze the figure size to the image size.
localSqueezeDefaultFig(handles, roi, statusCharHeight);

% TODO Don't pass in all the handles??
set(handles.Figure, 'Visible', 'on', ...
    'ResizeFcn', {@localResizeDefaultFcn, handles, statusCharHeight});

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = localSetupDefaultImageArea(handles, roi, statusCharHeight)

% Get the figure position in character units.
set(handles.Figure, 'Units', 'characters');
figPos = get(handles.Figure, 'Position');

% Create a panel for the image components.
handles.ImagePanel = uipanel('Parent', handles.Figure, ...
    'Units', 'characters', 'BorderType', 'none', ...
    'Position', [0 statusCharHeight figPos(3) figPos(4)-statusCharHeight]);
set(handles.ImagePanel, 'Units', 'normalized');

% Define the parent for the scroll panel.
handles.ScrollPanelParent = handles.ImagePanel;

% Create a new axis and image using temporary data 
% of the correct size and dimensions.
data = localGetDefaultImageData(roi);
handles.Axis = axes('Parent', handles.ImagePanel);
handles.Image = image(data, 'Parent', handles.Axis);

% Add scrollbars.
handles.ScrollPanel = imscrollpanel(handles.ScrollPanelParent, handles.Image);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = localSetupDefaultStatusArea(uddobj, handles, statusCharHeight) %#ok<INUSL>

% Get the figure position in character units.
set(handles.Figure, 'Units', 'characters');
figPos = get(handles.Figure, 'Position');

% Define default width, in character units, 
% for each section in the status bar.
timeSecWidth = 20;
resSecWidth = 20;
framesPerSecondSecWidth = 20;
statusXOffset = timeSecWidth + resSecWidth + framesPerSecondSecWidth;
statusSecWidth = figPos(3) - statusXOffset;

% Define position vector, in normalized units,
% for uicontrol text fields.
normTextPos = [0 0 1 1];

% Create a UI panel to contain all status components.
hStatusContainer = uipanel('Parent', handles.Figure, ... 
    'Units', 'characters', 'BorderType', 'none', ...
    'Position', [0 0 figPos(3) statusCharHeight]);
set(hStatusContainer, 'Units', 'normalized');

% Timestamp info section.
timeSecPos = [0 0 timeSecWidth statusCharHeight];
hTimePanel = uipanel('Parent', hStatusContainer, ...
    'Units', 'characters', 'Position', timeSecPos);
hTimeField = uicontrol(hTimePanel, 'Style', 'text', ...
    'String', 'Time Stamp', 'Units', 'normalized', ...
    'Position', normTextPos);

% Resolution info section.
resSecPos = [timeSecWidth 0 resSecWidth statusCharHeight];
hResPanel = uipanel('Parent', hStatusContainer, ...
    'Units', 'characters', 'Position', resSecPos);
hResField = uicontrol(hResPanel, 'Style', 'text', ...
    'String', 'Resolution', 'Units', 'normalized', ...
    'Position', normTextPos);

% Frames per second info section.
framesPerSecondSecPos = [resSecWidth+timeSecWidth 0 framesPerSecondSecWidth statusCharHeight];
hFramesPerSecondPanel = uipanel('Parent', hStatusContainer, ...
    'Units', 'characters', 'Position', framesPerSecondSecPos);
hFramesPerSecondField = uicontrol(hFramesPerSecondPanel, 'Style', 'text', ...
    'String', 'Frames Per Second', 'Units', 'normalized', ...
    'Position', normTextPos);

% Acquisition status info section.
statusSecPos = [statusXOffset 0 statusSecWidth statusCharHeight];
hStatusPanel = uipanel('Parent', hStatusContainer, ...
    'Units', 'characters', 'Position', statusSecPos);
hStatusField = uicontrol(hStatusPanel, 'Style', 'text', ...
    'String', 'Status', 'Units', 'normalized', ...
    'Position', normTextPos, 'HorizontalAlignment', 'left');

% Add the new handles to our structure.
handles.StatusContainer = hStatusContainer;

handles.StatusPanels.Time = hTimePanel;
handles.StatusPanels.Resolution = hResPanel;
handles.StatusPanels.Status = hStatusPanel;
handles.StatusPanels.FramesPerSecond = hFramesPerSecondPanel;

handles.StatusFields.Time = hTimeField;
handles.StatusFields.Resolution = hResField;
handles.StatusFields.Status = hStatusField;
handles.StatusFields.FramesPerSecond = hFramesPerSecondField;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function localSqueezeDefaultFig(handles, roi, statusCharHeight)

% Resize our figure to the image width and height. Don't 
% resize if the window's docked (causes a warning). The 
% window should never be docked at this point, but do it
% just in case since it's an inexpensive check.
winStyle = get(handles.Figure, 'WindowStyle');
if ~strcmpi(winStyle, 'docked')
    % Determine the size of the panel containing the status bar.
    set(handles.StatusContainer, 'Units', 'pixels');
    statusPos = get(handles.StatusContainer, 'Position');
    set(handles.StatusContainer, 'Units', 'normalized');

    % Resize the figure based on the ROI and status bar.
    % Make sure to resize the figure with respect to the top
    % left corner.
    set(handles.Figure, 'Units', 'pixels');
    figWidth = roi(3);
    figHeight = roi(4) + statusPos(4);
    screenSize = get( 0, 'ScreenSize');
    screenSize = [screenSize(1), screenSize(2), screenSize(3) + screenSize(1) - 1, screenSize(4) + screenSize(2) - 1];
    figureOffset = 50;
    if (figWidth <= screenSize(3) - figureOffset) ...
            && (figHeight <= screenSize(4) - figureOffset)
        figPos = get(handles.Figure, 'Position');
        bottomLeft = figPos(2) + (figPos(4) - figHeight);
        set(handles.Figure, ...
            'Position', [figPos(1) bottomLeft figWidth figHeight]);
    else
        safetyFactorForWindowDecoration = 0.9;
        scaleX = safetyFactorForWindowDecoration * (screenSize(3) - figureOffset) / figWidth;
        scaleY = safetyFactorForWindowDecoration * (screenSize(4) - figureOffset) / figHeight;
        set(handles.Figure, ...
            'Position', [figureOffset - screenSize(1), figureOffset - screenSize(2), ...
            figWidth * scaleX, figHeight * scaleY]);
    end
    
    % Explicitly call drawnow as we switch back/forth between Units setting
    % when the figure is invisible.
    drawnow;
    
    % Since the resize callback is not fired when the figure
    % is resized programmatically, fire it ourselves in case the 
    % figure width changed a bit.
    localResizeDefaultFcn(handles.Figure, [], handles, statusCharHeight)
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function handles = localUpdateDefaultImage(handles, uddobj, data)

% Determine if the axis width and height match the ROI
% width and height.
axUnits = get(handles.Axis, 'Units');
set(handles.Axis, 'Units', 'Pixels');
axPos = get(handles.Axis, 'Position');
set(handles.Axis, 'Units', axUnits);

roi = get(uddobj, 'ROIPosition');
if all(axPos(3:4)==roi(3:4))
    % Target image and ROI are in sync.
    set(handles.Image, 'CData', data);
else
    % Turn the scroll panel off and force it
    % to retarget with the new image.
    api = iptgetapi(handles.ScrollPanel);
    api.replaceImage(data);
end


