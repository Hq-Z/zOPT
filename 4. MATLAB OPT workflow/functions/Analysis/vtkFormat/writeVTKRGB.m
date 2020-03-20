function [] = writeVTKRGB(vol,vtkfile, RGB)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Usage: writeVTK(vol,vtkfile)
%
%   vol:     The 3D matrix to be saved to file
%   vtkfile: The output filename (string)
% 
% Erik Vidholm 2005
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% dimensions
volinfo = whos('vol');

sz = volinfo.size;

[X Y Z C]=size(vol);

fid = fopen(vtkfile,'w');

% write header
fprintf(fid, '%s\n', '# vtk DataFile Version 3.0');
fprintf(fid, '%s\n', 'created by writeVTK (Matlab implementation by Erik Vidholm)');
fprintf(fid, '%s\n', 'BINARY');  
fprintf(fid, '%s\n', 'DATASET STRUCTURED_POINTS');  
fprintf(fid, '%s%d%c%d%c%d\n', 'DIMENSIONS ', X, ' ', Y, ' ', Z);
fprintf(fid, '%s%f%c%f%c%f\n', 'ORIGIN ', 0, ' ', 0, ' ', 0); 
fprintf(fid, '%s%f%c%f%c%f\n', 'SPACING ', 1.0, ' ', 1.0, ' ', 1.0); 
fprintf(fid, '%s%d\n', 'POINT_DATA ', X*Y*Z);

tp = volinfo.class;
if C>2
   fprintf(fid, '%s\n', 'COLOR_SCALARS unsigned_charv 3');
elseif C==2
  fprintf(fid, '%s\n', 'COLOR_SCALARS unsigned_short 2');
elseif( strcmp(tp, 'uint8') > 0 )
  fprintf(fid, '%s\n', 'SCALARS image_data unsigned_char 1');
elseif( strcmp(tp, 'uint16') > 0 )
  fprintf(fid, '%s\n', 'SCALARS image_data unsigned_short');
elseif( strcmp(tp, 'uint32') > 0 )
  fprintf(fid, '%s\n', 'SCALARS image_data unsigned_int');
elseif( strcmp(tp, 'single') > 0 )
  fprintf(fid, '%s\n', 'SCALARS image_data float');
elseif( strcmp(tp, 'double') > 0 )
  fprintf(fid, '%s\n', 'SCALARS image_data double');

end
if C<3
 fprintf(fid, '%s\n', 'LOOKUP_TABLE default');
end

fwrite(fid,permute(vol,[4  1 2  3]),tp,'ieee-be');
nl = sprintf('\n');
fclose(fid);
 
 

