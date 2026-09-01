function map = videen(dataRange)


   n = size(get(gcf, 'Colormap'), 1);


values = [...
'00'; 'ff'; 'ff';  
'00'; 'ff'; '00';  
'00'; 'c8'; '10';  
'4b'; '7d'; '00';  
'7d'; '00'; 'a0';  
'4b'; '00'; '7d';  
'00'; '00'; 'aa';  
'00'; '00'; '50';  
'3c'; '00'; '00';  
'64'; '00'; '00';  % This color is for zero
'96'; '00'; '00';  
'c8'; '00'; '00';  
'ff'; '00'; '00';  
'ff'; '78'; '00';  
'ff'; 'c8'; '00';  
'ff'; 'ff'; '00'  
];

values = reshape(hex2dec(values), [3 numel(values)/6])' ./ 255;
zeroRelativePosition = (0 - dataRange(1)) / (dataRange(2) - dataRange(1));

zeroIndex = find(all(values == [hex2dec('00'), hex2dec('00'), hex2dec('50')]/255, 2));
P = size(values,1);

% We now split the colormap at the zeroIndex
positiveValues = values(zeroIndex:end, :);
negativeValues = values(1:zeroIndex, :);

% We need to ensure that the number of colors in the new map adds up to n
% Split the number of colors proportionally to the length of the positive and negative values
% numPos = ceil(n * length(positiveValues) / P);
% numNeg = n - numPos;
numNeg = floor(n * zeroRelativePosition);
numPos = n - numNeg;


% Generate the new map, ensuring that the zero color is at the middle
map = [interp1(1:size(negativeValues,1), negativeValues, linspace(1,size(negativeValues,1),numNeg), 'linear'); 
       interp1(1:size(positiveValues,1), positiveValues, linspace(1,size(positiveValues,1),numPos), 'linear')];

end
