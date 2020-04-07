function [rmsC] = rmsContrast(matrix)

rmsC=sqrt( (sum(sum(matrix.^2)) - (sum(matrix(:)))^2/numel(matrix))/numel(matrix));

end

