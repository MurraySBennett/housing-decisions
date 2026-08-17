close all; clear; clc
opts = spreadsheetImportOptions("NumVariables", 11);
opts.DataRange = "A3:K130";

% Specify column names and types
opts.VariableNames = ["industry", "company", "title", "salary", "workLife", "compensationBenefits", "jobSecurityAdvancement", "management", "culture", "hours", "infoSource"];
opts.VariableTypes = ["categorical", "double", "categorical", "string", "double", "double", "double", "double", "double", "categorical", "string"];
opts = setvaropts(opts, ["salary", "infoSource"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["industry", "title", "salary", "hours", "infoSource"], "EmptyFieldRule", "auto");

jobs_path = ['..' filesep 'experiment' filesep 'stimuli' filesep 'job_stimuli_list.xlsx'];
jobs = readtable(jobs_path, opts, "UseExcel", false);
clear opts jobs_path


jobs.salaryRaw  = jobs.salary;
jobs.salaryClean= zeros(height(jobs), 1);
jobs.payRate    = repmat("NA", height(jobs), 1);
jobs.wage       = nan(height(jobs), 1); %/hr
jobs.salary     = nan(height(jobs), 1); %/yr

% note: you could round the salaries to the nearest 1000 or 5000, perhaps
sal2wage = @(x) round(x / 52 / 40, 0);
wage2sal = @(x) round(x * 40 * 52, 0);
day2wage = @(x) round(x / 8, 0);
month2sal= @(x) round(x * 12, 0);

nearestK = @(x) round(x / 1000) * 1000;

for j = 1:height(jobs)
    job = jobs.salaryRaw(j);
    value = str2double(regexprep(job, '[^\d.]', ''));
    jobs.salaryClean(j) = value;
    if contains(job, {'k'}, IgnoreCase=true)
        value = value * 1000;
    end
    if contains(job, {'month'}, IgnoreCase=true)
        jobs.payRate(j) = 'monthly';
        jobs.salary(j)  = nearestK(month2sal(value));
        jobs.wage(j)    = sal2wage(month2sal(value));
    elseif contains(job, {'year', 'yr'}, IgnoreCase=true) || value > 1000
        jobs.payRate(j) = 'yearly';
        jobs.salary(j)  = nearestK(value);
        jobs.wage(j)    = sal2wage(value);
    elseif contains(job, {'hr', 'hrly', 'hour'}, IgnoreCase=true)
        jobs.payRate(j) = 'hourly';
        jobs.wage(j)    = round(value, 0);
        jobs.salary(j)  = nearestK(wage2sal(value)); 
    elseif contains(job, {'day', 'd'}, IgnoreCase=true)
        jobs.payRate(j) = 'daily';
        jobs.wage(j)    = day2wage(value);
        jobs.salary(j)  = nearestK(wage2sal(day2wage(value)));
    end
end
jobs.payRate = categorical(jobs.payRate);

% determine median values (salary, for now)
medianSalary = groupsummary(jobs, "industry", "median", "salary");
jobs = outerjoin(jobs, medianSalary, Keys={'industry'}, MergeKeys=true);
jobs.subMedianSalary = jobs.salary < jobs.median_salary;

jobs = removevars(jobs, ["GroupCount", "median_salary"]);
jobs = sortrows(jobs, {'industry', 'title', 'company'});

clear j job value %wage2day wage2sal day2wage sal2wage nearestK medianSalary

%% save merged table for experiment
expJobs = jobs(:, ["industry", "title", "company", "workLife", "culture", "compensationBenefits", "management", "jobSecurityAdvancement", "wage"]);
writetable(expJobs, ['..', filesep, 'experiment', filesep, 'stimuli', filesep, 'job_stimuli.csv']);

% jobs1 = wideJobs(wideJobs.company == 1, :);
% jobs2 = wideJobs(wideJobs.company == 2, :);
% 
% original_names = jobs1.Properties.VariableNames;
% num_names = numel(original_names);
% 
% wideJobs = table();
% for i = 1:num_names
%     current_name = original_names{i};
%     if ismember(current_name, ["company"])
%         continue;
%     end
% 
%     j1_col = jobs1.(current_name);
%     j2_col = jobs2.(current_name);
% 
%     if ismember(current_name, ["industry", "title"])
%         wideJobs.(current_name) = j1_col;
%     else
%         wideJobs.([current_name, '1']) = j1_col;
%         wideJobs.([current_name, '2']) = j2_col;
%     end
% end


%% let's see some of it?

vars = ["salary", "workLife", "compensationBenefits", "jobSecurityAdvancement", "management", "culture"];

tiledlayout(1, length(vars));
for i = 1:length(vars)
    nexttile;
    scatter(jobs.(vars{i}), jobs.salary, "filled"); hold on;
    scatter(jobs.(vars{i})(jobs.subMedianSalary == 0), jobs.salary(jobs.subMedianSalary == 0), "filled");
    scatter(jobs.(vars{i})(jobs.subMedianSalary == 1), jobs.salary(jobs.subMedianSalary == 1), "filled");
    lsline;
    xlabel(vars{i}); 
    if i > 1
        xlim([1 5]); 
    else
        ylabel("Salary")
    end
    ylim([min(jobs.salary) - 1000, max(jobs.salary) + 1000]);
    axis square
end
clear vars i
% 
% for i = 1:length(vars)
%     nexttile;
%     job1 = jobs{jobs.company == 1, vars{i}};
%     job2 = jobs{jobs.company == 2, vars{i}};
% 
%     histogram(job1, FaceAlpha=0.5); hold on;
%     histogram(job2, FaceAlpha=0.5);
%     title(vars{i}); 
%     if i > 1
%         xlim([0 5]);
%     end
%     ylim([0 30])
% end


% tiledlayout(length(vars), length(vars))
% pltCounter = 0;
% 
% for x = 1:length(vars)
%     xData = jobs.(vars{x});
%     for y = 1:length(vars)
%         nexttile;
%         pltCounter = pltCounter + 1;
%         if y >= x
%             continue
%         end
% 
%         yData = jobs.(vars{y});
%         scatter(xData, yData, 'filled','o' ); hold on;
% 
%         lsline
%         if any([7, 13, 19, 25, 31] == pltCounter)
%             ylabel(vars{x})
%         end
%     end
%     if pltCounter > 30
%         xlabel(vars{y})
%     end
% end