function rawbytes=writemidi(midi,filename)

if ~isempty(filename)
    filename = [filename '.mid'];
else
    filename = 'MIDI.mid';
end
Ntracks = length(midi.track);

for i = 1:Ntracks
    databytes_track{i} = [];
    for j=1:length(midi.track(i).messages)
        msg = midi.track(i).messages(j);
        msg_bytes = encode_var_length(msg.deltatime);
        if (msg.midimeta==1)
            run_mode = msg.used_running_mode;
            msg_bytes = [msg_bytes; encode_midi_msg(msg, run_mode)];
        else
            msg_bytes = [msg_bytes; encode_meta_msg(msg)];
        end
        databytes_track{i} = [databytes_track{i}; msg_bytes];
    end
end

% HEADER
rawbytes = [77 84 104 100 0 0 0 6 ...
    encode_int(midi.format,2) ...
    encode_int(Ntracks,2) ...
    encode_int(midi.ticks_per_quarter_note,2) ...
    ]';

% TRACK_CHUCKS
for i=1:Ntracks
    tmp = [77 84 114 107 ...
        encode_int(length(databytes_track{i}),4) ...
        databytes_track{i}']';
    rawbytes(end+1:end+length(tmp)) = tmp;
end

% write to file
fid = fopen(filename,'w');
fwrite(fid,rawbytes,'uint8');
fclose(fid);

% return a _column_ vector
function A=encode_int(val,Nbytes)
for i=1:Nbytes
    A(i) = bitand(bitshift(val, -8*(Nbytes-i)), 255);
end

function bytes=encode_var_length(val)
val = round(val);

if val < 128
    bytes = val;
    return
end
binStr = dec2base(round(val),2);
Nbytes = ceil(length(binStr)/7);
binStr = ['00000000' binStr];
bytes = [];
for i=1:Nbytes
    if (i==1)
        lastbit = '0';
    else
        lastbit = '1';
    end
    B = bin2dec([lastbit binStr(end-i*7+1:end-(i-1)*7)]);
    bytes = [B; bytes];
end

function bytes=encode_midi_msg(msg, run_mode)
bytes = [];
if (run_mode ~= 1)
    bytes = msg.type;
    bytes = bytes + msg.chan;  
end
bytes = [bytes; msg.data];

function bytes=encode_meta_msg(msg)
bytes = 255;
bytes = [bytes; msg.type];
bytes = [bytes; encode_var_length(length(msg.data))];
bytes = [bytes; msg.data];