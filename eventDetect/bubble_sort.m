function [Vec_out, Ind_out] = bubble_sort(Vec_in)
%function [Vec_out, Ind_out] = bubble_sort(Vec_in)
%
len = length(Vec_in);
A = Vec_in;
B = [1 : len];
for m = 0 : (len-2)
    for n = len : -1 : (m+2)
		if (A(n-1) > A(n))
            tmp = A(n-1);
            A(n-1) = A(n);
            A(n) = tmp;
            indtmp = B(n-1);
            B(n-1) = B(n);
            B(n) = indtmp;
        end
    end
end
Vec_out = A;
Ind_out = B;