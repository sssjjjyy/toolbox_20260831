function layers_by_laynii(rim,nr_layers,equivol,iter_smooth)
%UNTITLED9 此处提供此函数的摘要
%   此处提供详细说明
if(equivol)
    command = ['LN2_LAYERS -rim ',rim,' -nr_layers ',num2str(nr_layers),' -equivol -iter_smooth ',num2str(iter_smooth)];
%     command = ['LN2_LAYERS -rim ',rim,' -nr_layers ',num2str(nr_layers),' -equivol'];

else
    command = ['LN2_LAYERS -rim ',rim,' -nr_layers ',num2str(nr_layers),' -iter_smooth ',num2str(iter_smooth)];
%     command = ['LN2_LAYERS -rim ',rim,' -nr_layers ',num2str(nr_layers)];

end
system(command);
end