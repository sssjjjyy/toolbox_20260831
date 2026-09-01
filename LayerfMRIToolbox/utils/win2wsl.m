function wslPath = win2wsl(winPath)

    winPath = regexprep(winPath, '^([A-Za-z]):', '/mnt/${lower($1)}');
    
    wslPath = strrep(winPath, '\', '/');
end