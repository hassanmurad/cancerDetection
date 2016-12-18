function fval = calcFvar(sam, r, c)
col = 0; row = 0;
mui =  mean(mean(sam));
for i=1:r
    for j=1:c
        col = col + (sam(i,j) - mui)^2;
    end
    row = col + row; 
    col = 0;
end

fval = (1/(r*c*mean(sam(:))))*row;

end