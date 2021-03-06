function [energy,grad] = discrete_dna_penalty_en_grad_s(zvec)
% THIS FILE ONLY FUNCTIONS FOR A SEMICIRCULAR BOUNDARY CONDITIONS
% This file now has self contact gradient terms.
% This file neither constructs nor returns a hessian

global avgs_for_mer
global stiffs_for_mer
global r0
global rn
global q0
global qn
s = size(zvec);
zlen = s(1);
grad = zeros(zlen,1);
nbp = zlen/7+2; %zln/7 = #of unknown frames. total here is 2 knowns + th zlen/7 unknowns
penalty_weight=100;
njunc = nbp-1;


% Setup for building a sparse Hessian (ntriplies = number of times we'll put stuff in the Hessian)
ntriplets = 457*(njunc-2)+163;
I = zeros(ntriplets,1); J = zeros(ntriplets,1); X = zeros(ntriplets,1);

q = zeros(4,nbp);
r = zeros(3,nbp);
id = eye(4);

%assign values to the vectors q and r for all i along the rod
for i=2:nbp-1
    q(:,i)=zvec(4*(i-2)+1:4*(i-1),1);
    r(:,i)=zvec(4*(nbp-2)+3*(i-2)+1:4*(nbp-2)+3*(i-1),1);
end

%impose the boundary conditions.
r(:,end) = rn';
r(:,1) = r0';
q(:,end) = qn';
q(:,1) = q0';


%define the B matrices used in theta and a definitions
b = zeros(3,4,4);
b(1,1,4) = 1; b(1,2,3) = 1; b(1,3,2)=-1; b(1,4,1) = -1;
b(2,1,3) = -1; b(2,2,4) = 1; b(2,3,1) = 1; b(2,4,2) = -1;
b(3,1,2) = 1; b(3,2,1) = -1; b(3,3,4) = 1; b(3,4,3) = -1;
bq = zeros(3,4,nbp);
for i=1:3
    bi = zeros(4,4);
    for j1 = 1:4
        for j2 = 1:4
            bi(j1,j2)=b(i,j1,j2);
        end
    end
    for k = 1:nbp
        dum = bi*q(:,k);
        for j1=1:4
            bq(i,j1,k)=dum(j1);
        end
    end
end

%cay = thetas
%tr = a's (shift/slide/rise)
%dfac = qa * qb (q dot its neighbor)

cay = zeros(3,njunc);
tr = zeros(3,njunc);
dfac = zeros(1,njunc);
for i=1:njunc
    dfac(i) = q(:,i+1)'*q(:,i);
    for k=1:3
        bk = zeros(4,4);
        for j1 = 1:4
            for j2 = 1:4
                bk(j1,j2)=b(k,j1,j2);
            end
        end
        cay(k,i) = 2/dfac(i)*q(:,i+1)'*(bk*q(:,i));
        
    end
    dr = r(:,i+1)-r(:,i);
    dirs = compute_ds(q(:,i+1)+q(:,i));
    tr(1,i) = dr'*dirs(:,1);
    tr(2,i) = dr'*dirs(:,2);
    tr(3,i) = dr'*dirs(:,3);
end


%test why position 1 and 22 in cay are NaN
%seems we are dividing by 0 somewhere at the ends. likely due to me putting
%the wrong angles associated with q1 and q23
test = zeros(3,1);
for k=1:3
     bk = zeros(4,4);
     for j1 = 1:4
         for j2 = 1:4
             bk(j1,j2)=b(k,j1,j2);
         end
     end
     test(k,1) = 2/dfac(1)*q(:,2)'*(bk*q(:,1));
end
        
%disp(tr)

%energy function and gradients
%also define dj and dj derivatives
energy = 0.0;
for i=1:njunc
    for j1 = 1:3
        energy = energy+stiffs_for_mer(i,j1+3)*(cay(j1,i)-avgs_for_mer(i,j1+3))^2/2;
        energy = energy+stiffs_for_mer(i,j1)*(tr(j1,i)-avgs_for_mer(i,j1))^2/2;
    end
    energy = energy+penalty_weight*(q(:,i+1)'*q(:,i+1)-1)^2;
end

% self contact energy portion
global Q K
enq = 0;
xnorm = 0;

%exclude first and last to stop divide by zero comparison
%index j from i to nbp
for i=1:nbp
    for j=i:nbp
        if i==1 && j==nbp
            %nothing
        elseif abs(i-j) > nbp/10
            xnm = r(:,i) - r(:,j);
            xnorm = norm(xnm,2);
            enq = enq + exp(-K*xnorm) / xnorm;
        end
    end
end

%add the energy together
energy = energy + Q*enq;

%this makes the gradient.
for i=1:njunc-1
    dirs = compute_ds(q(:,i)+q(:,i+1));
    dirsnext = compute_ds(q(:,i+1)+q(:,i+2));
    ddirs = compute_dds(q(:,i)+q(:,i+1));
    ddirsnext = compute_dds(q(:,i+1)+q(:,i+2));
    for j = 1:3
        bj = zeros(4,4);
        ddjdq = zeros(3,4);
        ddjdqnext = zeros(3,4);
        dj = dirs(:,j);
        djnext = dirsnext(:,j);
        for j1 = 1:4
            for j2 = 1:4
                bj(j1,j2)=b(j,j1,j2);
            end
        end
        for j1 = 1:3
            for j2 = 1:4
                ddjdq(j1,j2) = ddirs(j,j1,j2);
                ddjdqnext(j1,j2) = ddirsnext(j,j1,j2);
            end
        end
        grad(4*(i-1)+1:4*i,1) = grad(4*(i-1)+1:4*i,1) + stiffs_for_mer(i,j+3)*(cay(j,i)-avgs_for_mer(i,j+3))*(-cay(j,i)/dfac(i)*q(:,i)+2/dfac(i)*bj*q(:,i));
        grad(4*(i-1)+1:4*i,1) = grad(4*(i-1)+1:4*i,1) + stiffs_for_mer(i+1,j+3)*(cay(j,i+1)-avgs_for_mer(i+1,j+3))*(-cay(j,i+1)/dfac(i+1)*q(:,i+2)-2/dfac(i+1)*bj*q(:,i+2));
        grad(4*(i-1)+1:4*i,1) = grad(4*(i-1)+1:4*i,1) + stiffs_for_mer(i,j)*(tr(j,i)-avgs_for_mer(i,j))*ddjdq'*(r(:,i+1)-r(:,i));
        grad(4*(i-1)+1:4*i,1) = grad(4*(i-1)+1:4*i,1) + stiffs_for_mer(i+1,j)*(tr(j,i+1)-avgs_for_mer(i+1,j))*ddjdqnext'*(r(:,i+2)-r(:,i+1));
        grad(4*(njunc-1)+3*(i-1)+1:4*(njunc-1)+3*i,1) = grad(4*(njunc-1)+3*(i-1)+1:4*(njunc-1)+3*i,1) + stiffs_for_mer(i,j)*(tr(j,i)-avgs_for_mer(i,j))*dj;
        grad(4*(njunc-1)+3*(i-1)+1:4*(njunc-1)+3*i,1) = grad(4*(njunc-1)+3*(i-1)+1:4*(njunc-1)+3*i,1) + stiffs_for_mer(i+1,j)*(tr(j,i+1)-avgs_for_mer(i+1,j))*(-djnext);
    end
    grad(4*(i-1)+1:4*i,1) = grad(4*(i-1)+1:4*i,1) + 2*penalty_weight*(q(:,i+1)'*q(:,i+1)-1)*2*q(:,i+1);
end


%now that the gradient above is purely the elastic portion, add the portion
%in the r terms for the electrostatic portion (the last 3/7th's of the
%array)


%e%m derivatives added

xnorm = 0;
sgn = 0;
elecgrad = zeros(zlen,1);
%ind = 0;
%multiply by Q somewhere
for k=1:(1/7)*zlen
    emder = zeros(3,1);

    %index j by i to nbp.
    for i=1:nbp
        for j=i:nbp
%            if i==1 && j==nbp
%                %nothing
%            elseif abs(i - j) > 1
            %    xnorm = norm(r(:,i)-r(:,j));
            %    xdiff = zeros(3,1);
            if abs(i-j) > nbp/10 && abs(i+(nbp-j)) > nbp/10
                if i == k+1
                    xnorm = norm(r(:,i)-r(:,j));
                    xdiff = r(:,k+1)-r(:,j);
                    emder = emder - exp(-K*xnorm)*(1+K*xnorm)*xdiff/(xnorm^3);
                elseif j == k+1
                    xnorm = norm(r(:,i)-r(:,j));
                    xdiff = -(r(:,i)-r(:,k+1));
                    emder = emder - exp(-K*xnorm)*(1+K*xnorm)*xdiff/(xnorm^3);
                end
                
                % emder = emder - exp(-K*xnorm)*(1+K*xnorm)*xdiff/(xnorm^3);
                %ind = ind + 1;
            end
        end
    end
    
    elecgrad(4*(njunc-1)+3*(k-1)+1:4*(njunc-1)+3*k,1) = Q*emder;
end

grad = grad + elecgrad;
