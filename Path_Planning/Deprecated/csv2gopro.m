clear;clc

altitude=200*.3048; %[m]

fileList=dir;
fileList={fileList(cellfun(@(fn) ~isempty(strfind(fn,'.csv')),{fileList.name}) & ...
                   cellfun(@(fn) ~isempty(strfind(fn,'flight')),{fileList.name})).name};
for fn=fileList
    data=csvread(fn{:});
    data=data(data(:,3)==0,:);
    fh=fopen([fn{:}(1:end-4) '.txt'],'w');
    fprintf(fh,'QGC WPL 110\r\n');
    for row=1:length(data)
        fprintf(fh,'%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%0.15f\t%0.15f\t%0.15f\t%d\r\n', ...
            row-1,       ... INDEX
            1*(row==1),  ... CURRENT WP
            0,           ... COORD FRAME
            16,          ... COMMAND
            0,           ... PARAM1
            0,           ... PARAM2
            0,           ... PARAM3
            0,           ... PARAM4
            data(row,1), ... LATITUDE
            data(row,2), ... LONGITUDE
            altitude,    ... PARAM7/Z/ALTITUDE
            1);            % AUTOCONTINUE
    end
    fclose(fh);
end