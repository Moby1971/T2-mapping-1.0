function images = PCAdenoise(images,w)

% Image dimensions (NE, X, Y, Z, NR)
[~, ~, ~, nrSlices, nrDynamics] = size(images);

im = permute(images,[2 3 1 4 5]);

% Denoising window
window = [w w];
if window(1) > size(images,2)/2
    window(1) = round(size(images,2)/2);
end
if window(2) > size(images,3)/2
    window(2) = round(size(images,3)/2);
end

% Loop over all dynamics, echo times
im1 = zeros(size(im));
for dyn = 1:nrDynamics
    for slice = 1:nrSlices
        im1(:,:,:,slice,dyn) = denoise(double(squeeze(im(:,:,:,slice,dyn))),window);
    end
end

images = ipermute(im1,[2 3 1 4 5]);


    function denoised = denoise(image, window)
        % MP-PCA denoising
        %
        % input:
        % image:  images to be denoised. Must have 3 or 4 indices with MRI images
        %         along the last index and voxels in the first 2 or 3.
        % window: sliding window
        % mask:   is true for all voxels per default but can be manually set to
        %         mask out regions.
        %
        % output:
        % denoised: denoised images
        % S2:       map of estimated noise variance
        % P:        number of detected signal principal components


        %% adjust image dimensions and assert
        dimsOld = size(image);

        mask = true(size(image,1),size(image,2));

        [image,mask] = imageAssert(image,mask);

        dnwindow = [window(1), window(2), 1];

        dims = size(image);

        %% denoise image
        denoised = complex(zeros(size(image)));
        %P = zeros(dims(1:3));
        %S2 = zeros(dims(1:3));
        M = dims(1)-dnwindow(1)+1;
        N = dims(2)-dnwindow(2)+1;
        O = dims(3)-dnwindow(3)+1;
        count = zeros(dims(1:3));
        for index = 0:M*N*O-1
            k = 1 + floor(index/M/N);
            j = 1 + floor(mod(index,M*N)/M);
            i = 1 + mod(mod(index,M*N),M);
            rows = i:i-1+dnwindow(1);
            cols = j:j-1+dnwindow(2);
            slis = k:k-1+dnwindow(3);

            % Create X data matrix
            X = complex(reshape(image(rows,cols,slis,:),[],dims(4))');

            % remove masked out voxels
            maskX = reshape(mask(rows,cols,slis),[],1)';
            if nnz(maskX)==0 || nnz(maskX)==1
                continue
            end

            % denoise X
            [X(:,maskX),s2,p] = denoiseMatrix(X(:,maskX)); %#ok<ASGLU>

            % assign
            X(:,~maskX) = 0;
            denoised(rows,cols,slis,:) = denoised(rows,cols,slis,:) + reshape(X',[dnwindow dims(4)]);
            %P(rows,cols,slis) = P(rows,cols,slis) + p;
            %S2(rows,cols,slis) = S2(rows,cols,slis) + s2;
            count(rows,cols,slis) = count(rows,cols,slis) + 1;
        end
        skipped = count==0 | ~mask;
        denoised = denoised + image.*skipped; % Assign original data to denoisedImage outside of mask and at skipped voxels
        count(skipped) = 1;
        denoised = denoised./count;
        %P = P./count;
        %S2 = S2./count;
        %P(~mask) = nan;
        %S2(~mask) = nan;


        %% adjust output to match input dimensions
        denoised = reshape(abs(denoised),dimsOld);
        %P = reshape(P,dimsOld(1:end-1));
        %S2 = reshape(S2,dimsOld(1:end-1));


    end





    % X: denoised matrix, s2: original noise variance, p: number of signal components, s2_after: noise variance after denoising
    function [X_out,s2,p,s2_after] = denoiseMatrix(X_in)

        M = size(X_in,1);
        N = size(X_in,2);

        if M<N
            [U,lambda] = eig(X_in*X_in','vector');
        else
            [U,lambda] = eig(X_in'*X_in,'vector');
        end

        [lambda,order] = sort(lambda,'descend');
        U = U(:,order);
        csum = cumsum(lambda,'reverse');
        p = (0:length(lambda)-1)';
        p = -1 + find((lambda-lambda(end)).*(M-p).*(N-p) < 4*csum*sqrt(M*N),1);

        if p==0
            X_out = zeros(size(X_in));
        elseif M<N
            X_out = U(:,1:p(1))*U(:,1:p(1))'*X_in;
        else
            X_out = X_in*U(:,1:p(1))*U(:,1:p(1))';
        end

        s2 = csum(p(1)+1)/((M-p(1))*(N-p(1)));
        s2_after = s2 - csum(p(1)+1)/(M*N);

    end




    function [image_out,mask] = imageAssert(image_in,mask)
        % Want first image indices to discriminate between pixels and last
        % dimension to hold data for each pixel. This function puts the image data
        % on the form: row x col x slice x rest.

        dims = size(image_in);
        assert(length(dims)<=4,'image data array must not have more than 4 dimensions')

        % construct mask if not given
        if numel(mask)==0
            if sum(dims~=1)==1
                mask = true;
            else
                mask = true([dims(1:end-1) 1]);
            end
        end
        maskDims = size(mask);


        % voxel count must match
        assert(numel(mask)==prod(dims(1:end-1)),'mask dimensions does not match image dimensions')

        % if image only contains data from single pixel
        if (all(dims(1:end-1)==1) && length(dims)<4) || (dims(1)>1 && dims(2)==1 && length(dims)<3) % (1xn || 1x1xn) || (nx1)
            assert(numel(mask)==1,'mask dimensions does not match image dimensions')
            dummy = zeros(1,1,1,length(image_in(:)));
            dummy(1,1,1,:) = image_in;
            image_out = dummy;
        end

        % if image is on form rxcxn
        if length(dims)==3
            assert(all(maskDims==dims(1:end-1)),'mask dimensions does not match image dimensions')
            dummy = zeros(size(image_in,1),size(image_in,2),1,size(image_in,3));
            dummy(:,:,1,:) = image_in;
            image_out = dummy;
        end

        % if image is on form rxn
        if length(dims)==2 && dims(2)~=1
            assert(all(maskDims(1)==dims(1)),'mask dimensions does not match image dimensions')
            dummy = zeros(size(image_in,1),1,1,size(image_in,2));
            dummy(:,1,1,:) = image_in;
            image_out = dummy;
        end

    end




end % PCAdenoise