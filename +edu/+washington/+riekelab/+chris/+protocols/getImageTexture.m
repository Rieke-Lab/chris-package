function mat = getImageTexture(img, sigma, randSeed, tag)
%GETIMAGETEXTURE Summary of this function goes here
%   create texture stimulus with the pixel histogram obtained from images
%   generate texture stimulus : tag = 1 -> skewed; tag = 0 -> normal
%   potential problem: after the receptive field those images no longer
%   similar ....
    sigma = round(sigma/2/3.3);
    % set random seed
    stream = RandStream('mt19937ar','Seed',randSeed);
    mat = double(rand(stream, size(img)));
    % make gaussian filter
    h = fspecial('gaussian',6*sigma,sigma);
    h = h ./ sum(h(:)); % normalize
    mat = imfilter(mat,h,'replicate');
    
% make histogram of pixel values uniform
% From Schwartz lab
    bins = [-Inf prctile(mat(:),1:0.5:100)];
    patchbins = [-Inf prctile(img(:), 1:0.5:100)];
    m_orig = mat;
    even_mat = mat;
    for bb=1:length(bins)-1
        mat(m_orig>bins(bb) & m_orig<=bins(bb+1)) = max(0,mean(patchbins(bb:bb+1)));%bb*(1/(length(bins)-1));
        even_mat(m_orig>bins(bb) & m_orig<=bins(bb+1)) = bb*(1/(length(bins)-1));
    end
    if tag == 0
        even_mat = even_mat - min(even_mat(:));
        meanIntensity = mean(img(:)); % should use the equivalent mean
        even_mat = 2* meanIntensity .* (even_mat ./ max(even_mat(:)));
        mat = even_mat;
    end
end

