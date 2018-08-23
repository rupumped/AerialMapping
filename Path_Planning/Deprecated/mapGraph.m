function g = mapGraph(m,n)
A = zeros(m*n);
h=waitbar(0,'Generating Graph...');
for i = 1:m*n
    for j = i:m*n
        if any([1:m:m*n, m:m:m*n] == i) && any([1:m:m*n, m:m:m*n] == j)
            if j==i-m || j==i+m
                A(i,j) = 1;
            end
        else
            if j==i-m-1 || j==i-m+1 || j==i+m-1 || j==i+m+1
                A(i,j) = 0;%sqrt(2);
            elseif j==i-m || j==i-1 || j==i+1 || j==i+m
                A(i,j) = 1;
            end
        end
    end
    waitbar(i/(m*n),h)
end
close(h)
A = A + triu(A,1)';
% A = A + diag(ones(m*n-1,1),1) + diag(ones(m*n-1,1),m);
% A = A + triu(A,1)';
g = graph(A);
end