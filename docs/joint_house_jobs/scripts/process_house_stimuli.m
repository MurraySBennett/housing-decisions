close all; clear; clc

opts = delimitedTextImportOptions("NumVariables", 14);
opts.DataLines = [2, Inf];
opts.Delimiter = ",";
opts.VariableNames = ["Zone", "Var2", "nBeds", "nBaths", "sqft", "lotSize", "yearBuilt", "listPrice", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"];
opts.SelectedVariableNames = ["Zone", "nBeds", "nBaths", "sqft", "lotSize", "yearBuilt", "listPrice", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"];
opts.VariableTypes = ["categorical", "string", "double", "double", "string", "double", "double", "double", "string", "string", "string", "string", "string", "string"];
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";
opts = setvaropts(opts, ["Var2", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Zone", "Var2", "extPic", "kitPic", "bedPic", "bathPic", "livPic", "outPic"], "EmptyFieldRule", "auto");
opts = setvaropts(opts, "listPrice", "TrimNonNumeric", true);
opts = setvaropts(opts, "listPrice", "ThousandsSeparator", ",");

house_path = ['..', filesep, 'experiment', filesep, 'stimuli', filesep, 'house_stimuli_list.csv'];
houses = readtable(house_path, opts);

houses.Zone = categorical(strrep(string(houses.Zone), " (Cedar Key's West)", ""));
houses.sqft = double(houses.sqft);
setPicPath = @(x) ".\stimuli\house_images\" + x + ".png";
houses.kitPic = setPicPath(houses.kitPic);
houses.bedPic = setPicPath(houses.bedPic);
houses.bathPic = setPicPath(houses.bathPic);
houses.livPic = setPicPath(houses.livPic);
houses.outPic = setPicPath(houses.outPic);
houses.extPic = setPicPath(houses.extPic);
clear opts house_path

writetable(houses, ['..', filesep, 'experiment', filesep, 'stimuli', filesep, 'house_stimuli.csv']);
