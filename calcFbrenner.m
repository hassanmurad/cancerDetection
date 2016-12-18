function fbrenner = calcFbrenner(s, r, c)
col = 0; row = 0;
for i=1:(r-2)

    for j=1:c
        col = col + (s(i,j) - s(i+2,j))^2;
    end
    row = col + row; 
    col = 0;
end

fbrenner = row;

end