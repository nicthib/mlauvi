function varargout = mlauvi(varargin)
gui_Singleton = 1;
gui_State = struct('gui_Name', mfilename, ...
    'gui_Singleton',  gui_Singleton, ...
    'gui_OpeningFcn', @mlauvi_OpeningFcn, ...
    'gui_OutputFcn',  @mlauvi_OutputFcn, ...
    'gui_LayoutFcn',  [] , ...
    'gui_Callback',   []);
if nargin && ischar(varargin{1}); gui_State.gui_Callback = str2func(varargin{1}); end
if nargout; [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:}); else; gui_mainfcn(gui_State, varargin{:}); end

function mlauvi_OpeningFcn(hO, ~, h, varargin)
warning('off','all')
% cd to active script location
tmp = matlab.desktop.editor.getActive;
h.mlauvipath = fileparts(tmp.Filename);
cd(h.mlauvipath);
% Addpath GUI folder
addpath(genpath(h.mlauvipath));

% set ffmpeg path (for combining V/A)
try
    setenv('PATH', cell2mat(importdata('ffmpegpath.txt')))
    h.St.String = 'ffmpeg path set. Ready to load a dataset';
catch
    h.St.String = 'No ffmpeg path found in ffmpegpath.txt. Please update this file to add audio and video seamlessly.';
end
slidx = h.uipanel2.OuterPosition(1)+.0085;
slidy = h.uipanel2.OuterPosition(2)+.051;
% Set up load pct multi slider
h.output = hO; h.framenum = 1; set(gcf, 'units','normalized','outerposition',[.2 .2 .85 .75]);
h.slider = superSlider(hO, 'numSlides', 2,'controlColor',[.94 .94 .94],... 
'position',[slidx slidy .1 .03],'stepSize',.3,'callback',@slider_Callback);
h.slider.UserData = [0 1;0 1];
h.slider.Children(2).Position(1) = .8125;
guidata(hO, h);

function varargout = mlauvi_OutputFcn(hO, ~, h)
varargout{1} = h.output;

%%%%%%%%%%%%%%%%%%%%%%%%%% MAIN CALLBACKS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function LoadData_Callback(hO, ~, h)
[File,Path] = uigetfile('.mat','Please choose a data file');
matObj = matfile(fullfile(Path, File));
matvars = whos(matObj);

for i = 1:numel({matvars.name})
    varstr{i} = ['Name = ' matvars(i).name ', size = ' mat2str(matvars(i).size)];
end
varH = listdlg('ListString',varstr,'Name','Choose Temporal Variable','ListSize',[300 100]);
varW = listdlg('ListString',varstr,'Name','Choose Spatial Variable','ListSize',[300 100]);

h.H = matObj.(matvars(varH).name);
h.W = matObj.(matvars(varW).name);

h.cmap = jet(size(h.H,1));
h.m.Wshow = 1:size(h.H,1);
h.m.W_sf = ones(1,size(h.W,3));
h.m.ss = size(h.W);
h.W = reshape(h.W,[prod(h.m.ss(1:2)) h.m.ss(3)]);
h.W_sf.Checked = 'off';
h.frameslider.Enable = 'on';
h.m.vstart = 0;
h.m.vend = 1;
h.m.framerate = str2num(h.framerate.String);
h.m.thresh = str2num(h.thresh.String);
h.filename.String = File(1:end-4);
h.filenametext.String = File(1:end-4);
UpdatePlots(h)
guidata(hO, h);

function Loadcfg_Callback(hO,~,h)
[File,Path] = uigetfile('.mat','Please choose a cfg file');
close all
load(fullfile(Path,File))
guidata(hO, h);

function Wshow_Callback(hO, ~, h)
if strcmp(h.Wshow.String,'all')
    h.m.Wshow = 1:size(h.H,1);
else
    h.m.Wshow = str2num(h.Wshow.String);
end
h.UpdateH.BackgroundColor = [1 0 0];
UpdatePlots(h)
guidata(hO, h);

function framerate_Callback(hO, ~, h)
h.m.framerate = str2num(h.framerate.String);
guidata(hO, h);

function clim_Callback(hO, ~, h)
UpdatePlots(h)
guidata(hO, h);

function thresh_Callback(hO, ~, h)
h.m.thresh = str2num(h.thresh.String);
h.UpdateH.BackgroundColor = [1 0 0];
guidata(hO, h);

function frameslider_Callback(hO, ~, h)
h.framenum = round(h.frameslider.Value*size(h.H,2));
if h.framenum == 0
    h.framenum = 1;
end
h.frametxt.String = [mat2str(round(h.framenum*100/h.m.framerate)/100) ' sec'];
UpdatePlots(h)
%UpdateH_Callback(hO, [], h)
guidata(hO, h);

function PlayVid_Callback(hO, ~, h)
while h.PlayVid.Value
    axes(h.axesWH);
    h.frameslider.Enable = 'off';
    sc = 256/(str2num(h.clim.String));
    im = reshape(h.W(:,h.m.Wshow)*diag(h.H(h.m.Wshow,h.framenum).*h.m.W_sf(h.m.Wshow)')*h.cmap(h.m.Wshow,:),[h.m.ss(1:2) 3]);
    imagesc(uint8(sc*im))
    caxis([0 str2num(h.clim.String)])
    axis equal
    axis off
    pause(.01)
    h.frametxt.String = [mat2str(round(h.framenum*100/h.m.framerate)/100) ' sec'];
    h.framenum = h.framenum + 1;
    h.frameslider.Value = h.framenum/size(h.H,2);
    axes(h.axesWH);

    if ~get(h.PlayVid, 'Value')
        break;
    end
    if h.framenum == size(h.H,2)
        h.PlayVid.Value = 0;
        h.frameslider.Value = 0;
    end
end
h.frameslider.Enable = 'on';
guidata(hO, h);

function UpdateH_Callback(hO, ~, h)
outinds = round(h.m.vstart*size(h.H,2))+1:round(h.m.vend*size(h.H,2));
tmp = zeros(1,size(h.H,1)); tmp(h.m.Wshow) = 1;

h.St.String = 'Updating H''...'; drawnow
h.m.keys = makekeys(h.scale.Value,h.scaletype.Value,numel(find(h.m.W_sf & tmp)),str2num(h.addoct.String));
%[h.m.keys,h.keyrangegood] = makekeys(h.scale.Value,h.scaletype.Value,numel(find(h.m.W_sf & tmp)),str2num(h.addoct.String));
% if ~h.keyrangegood
%     h.St.String = 'ERROR: The number of components and note arrangement you have chosen is too broad. Please try using less components or a tighter note arrangement (e.g. scale)';
%     return
% end

[h.Mfinal,h.nd] = H_to_nd(h.H(find(h.m.W_sf & tmp),outinds),h.m.framerate,h.m.thresh,h.m.keys);
h.M.notestart = h.Mfinal(:,5);
h.M.noteend = h.Mfinal(:,6);
h.M.notemag = h.Mfinal(:,4);
h.M.notekey = h.Mfinal(:,3);

UpdatePlots(h)
h.UpdateH.BackgroundColor = [1 1 1];
h.St.String = 'H'' updated.';
guidata(hO, h);

function W_sf_Callback(hO, ~, h)
if strcmp(h.W_sf.Checked,'off')
    h.m.W_sf = imbinarize(sum(h.W,1)/max(sum(h.W,1)),.1);
    h.W_sf.Checked = 'on';
elseif strcmp(h.W_sf.Checked,'on')
    h.m.W_sf = ones(1,size(h.W,2));
    h.W_sf.Checked = 'off';
end
UpdatePlots(h)
h.UpdateH.BackgroundColor = [1 0 0];
guidata(hO, h);

function editcmap_Callback(hO, ~, h)
editcmap(hO,h); 
guidata(hO,h);

function slider_Callback(hO, ~)
h = guidata(hO);
h.m.vstart = round(1000*h.slider.Children(1).Position(1)/.625)/1000;
h.m.vend = round(1000*(h.slider.Children(2).Position(1)-.1875)/.625)/1000;
h.vs_str.String = mat2str(h.m.vstart*100);
h.ve_str.String = mat2str(h.m.vend*100);
drawnow
h.UpdateH.BackgroundColor = [1 0 0];
guidata(hO,h);

function vs_str_Callback(hO, ~, h)
h.m.vstart = str2num(h.vs_str.String)/100;
h.slider.Children(1).Position(1) = h.m.vstart * .625;
h.UpdateH.BackgroundColor = [1 0 0];
guidata(hO,h);

function ve_str_Callback(hO, ~, h)
h.m.vend = str2num(h.ve_str.String)/100;
h.slider.Children(2).Position(1) = h.m.vend * .625 + .1875;
h.UpdateH.BackgroundColor = [1 0 0];
guidata(hO,h);

function ExportAudio_Callback(hO, ~, h)
UpdateH_Callback(hO, [], h)
if strcmp(h.check_fmt_1.Checked,'on') % Stream
    h.St.String = 'Writing Audio stream...';
    outinds = round(h.m.vstart*size(h.H,2))+1:round(h.m.vend*size(h.H,2));
    tmp = zeros(1,size(h.H,1)); tmp(h.m.Wshow) = 1;
    out = NeuralStream(h.H(h.m.W_sf & tmp,outinds),h.m,h.m.keys,fullfile(h.mlauvipath,'output',h.filename.String));
    if ~out
        h.St.String = 'ERROR: The number of components and note arrangement you have chosen is too broad. Please try using less components or a tighter note arrangement (e.g. scale)';
        return
    end
    h.St.String = 'Audio stream written...';
    
elseif strcmp(h.check_fmt_2.Checked,'on')
    h.St.String = 'Writing Dynamic Audio file...';
    if ~isempty(h.nd)
        nd_to_wav(fullfile(h.mlauvipath,'output',h.filename.String),h.nd,h);
    end
    h.St.String = 'Dynamic Audio file written.'; drawnow
    
elseif strcmp(h.check_fmt_3.Checked,'on')
    h.St.String = 'Writing MIDI...';
    midiout = matrix2midi_nic(h.Mfinal,300,[4,2,24,8],0);
    writemidi(midiout, fullfile(h.mlauvipath,'output',h.filename.String));
    h.St.String = 'MIDI file written'; drawnow
    h.combineAV.Enable = 'on';
else
    h.St.String = 'Please select an audio format in the edit menu drop down';
end
guidata(hO,h)

function ExportAVI_Callback(hO, ~, h)
UpdateH_Callback(hO, [], h)
h.St.String = 'Writing AVI file...'; drawnow
fn = h.filename.String; 
sc = 256/str2num(h.clim.String);
Wtmp = h.W(:,h.m.Wshow); Htmp = h.H(h.m.Wshow,:);
cmaptmp = h.cmap(h.m.Wshow,:);
vidObj = VideoWriter(fullfile(h.mlauvipath,'output',[fn '.avi']));
vidObj.FrameRate = h.m.framerate; open(vidObj)
outinds = round(h.m.vstart*size(h.H,2))+1:round(h.m.vend*size(h.H,2));
for i = outinds
    im = reshape(Wtmp*diag(Htmp(:,i).*h.m.W_sf(h.m.Wshow)')*cmaptmp,[h.m.ss(1:2) 3]);
    im = uint8(im*sc);
    frame.cdata = im;
    frame.colormap = [];
    writeVideo(vidObj,frame);
    pct_updt = 10;
    if mod(i,pct_updt) == 1
        h.St.String = ['Writing AVI file... ' mat2str(round(i*100/numel(outinds))) '% done'];
        drawnow
    end
end
h.St.String = 'AVI file written';
close(vidObj);

function combineAV_Callback(hO, ~, h)
fn = fullfile(h.mlauvipath,'output',h.filename.String); 

system(['ffmpeg -loglevel panic -i ' fn '.avi -i ' fn '.wav -codec copy -shortest ' fn '_audio.avi -y']);
if exist([fn '_audio.avi'])
    h.St.String = 'AVI w/ audio successfully written.';
else
    h.St.String = 'AVI w/ audio was unable to be written. Check to make sure you have the proper path to ffmpeg.exe in the ffmpegpath.txt file.';
end

function Savecfg_Callback(hO, ~, h)
save([h.filename.String '_cfg.mat'])
h.St.String = ['Config file saved as ' h.filename.String '_cfg.mat.'];

function targ = vF(targ) % visibility toggle
if strcmp(targ.Visible,'on')
    targ.Visible = 'off';
else
    targ.Visible = 'on';
end

function targ = eF(targ) % enable toggle
if strcmp(targ.Enable,'on')
    targ.Enable = 'off';
else
    targ.Enable = 'on';
end

%%%%%%%%%%%%%%%%%%%%%%%%%%% DROP DOWN CALLBACKS %%%%%%%%%%%%%%%%%%%%%%%%%%%

function check_fmt_1_Callback(hO, ~, h)
h.check_fmt_1.Checked = 'on';
h.check_fmt_2.Checked = 'off';
h.check_fmt_3.Checked = 'off';
guidata(hO,h)

function check_fmt_2_Callback(hO, ~, h)
h.check_fmt_1.Checked = 'off';
h.check_fmt_2.Checked = 'on';
h.check_fmt_3.Checked = 'off';
guidata(hO,h)

function check_fmt_3_Callback(hO, ~, h)
h.check_fmt_1.Checked = 'off';
h.check_fmt_2.Checked = 'off';
h.check_fmt_3.Checked = 'on';
guidata(hO,h)

function PlayNotes_Callback(hO,~,h)
if isfield(h.m,'keys')
    h.St.String = 'Playing keys...'; drawnow
    for i = 1:numel(h.m.keys)
        tic
        if strcmp(h.check_fmt_1.Checked,'on') % Stream
            freq = 16.35*2.^(h.m.keys(i)/12);
            if ~exist('t')
                t = 0:(1/16384):.5;
                g = [linspace(0,1,2000) ones(1,8193-4000) linspace(1,0,2000)];
            end
            y = g.*sin(2*pi*freq*t);
        else
            [note,ps] = notestr(h.m.keys(i)+1);
            y = loadnote(note,ps,0);
        end
        pause(.5-toc)
        sound(y,44100)
    end
    h.St.String = 'Done playing keys.';
else
end
guidata(hO,h)

%%%%%%%%%%%%%%%%%%%%%%%%%%%% UNUSED CALLBACKS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function doNothing_Callback(hO, ~, h)
function framerate_CreateFcn(hO, ~, h)
function Wshow_CreateFcn(hO, ~, h)
function thresh_CreateFcn(hO, ~, h)
function clim_CreateFcn(hO, ~, h)
function frameslider_CreateFcn(hO, ~, h)
function scale_CreateFcn(hO, ~, h)
function scale_Callback(hO, ~, h)
function filename_Callback(hO, ~, h)
function filename_CreateFcn(hO, ~, h)
function scaletype_Callback(hO, ~, h)
function scaletype_CreateFcn(hO, ~, h)
function addoct_Callback(hO, ~, h)
function addoct_CreateFcn(hO, ~, h)
function ve_str_CreateFcn(hO, ~, h)
function vs_str_CreateFcn(hO, ~, h)
