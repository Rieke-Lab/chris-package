function [index,matrix] = generateMatrixAnnulus(matrix,innerRadius,outterRadius)
index=ones(size(matrix));
for i=1:size(matrix,1)
    for j=1:size(matrix,2)
        if sqrt((i-size(matrix,1)/2)^2+(j-size(matrix,2)/2)^2)>outterRadius ...,
                || sqrt((i-size(matrix,1)/2)^2+(j-size(matrix,2)/2)^2)< innerRadius
            index(i,j)=0;
        end
    end
matrix=matrix.*index;
end
