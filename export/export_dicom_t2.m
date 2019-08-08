function export_dicom_t2(directory,m0map,t2map,parameters,tag)


% create folder if not exist, and clear

folder_name = [directory,['/M0map-DICOM-',tag]];
if (~exist(folder_name, 'dir')); mkdir(folder_name); end
delete([folder_name,'/*']);

folder_name = [directory,['/T2map-DICOM-',tag]];
if (~exist(folder_name, 'dir')); mkdir(folder_name); end
delete([folder_name,'/*']);

[nr_images,dimx,dimy] = size(t2map);

% export the dicom images

dcmid = dicomuid;   % unique identifier
dcmid = dcmid(1:50);



for i=1:nr_images
    dcm_header = generate_dicomheader_t2(parameters,i,dimx,dimy,dcmid);
    fn = ['0000',num2str(i)];
    fn = fn(size(fn,2)-4:size(fn,2));
    fname = [directory,'/M0map-DICOM-',tag,'/M0map_',fn,'.dcm'];
    image = rot90(squeeze(cast(round(m0map(i,:,:)),'uint16')));
    dicomwrite(image, fname, dcm_header);
end

for i=1:nr_images
    dcm_header = generate_dicomheader_t2(parameters,i,dimx,dimy,dcmid);
    fn = ['0000',num2str(i)];
    fn = fn(size(fn,2)-4:size(fn,2));
    fname = [directory,'/T2map-DICOM-',tag,'/T2map_',fn,'.dcm'];
    image = rot90(squeeze(cast(round(t2map(i,:,:)),'uint16')));
    dicomwrite(image, fname, dcm_header);
end




end