function [output,index] = drawDataSample(array,npts)

target=linspace(min(array), max(array), npts);

for i=1:npts
    [~,index(i)]=min(abs(target(i)-array));
    output(i)=array(index(i));
end

end

