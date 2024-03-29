function import_data
%% Import experiment JSON data into MATLAB
% Determine injection hemisphere
% Sort projections into ipsi- vs contralateral

% Projections variable names
proj = {'density','energy','intensity','volume'};
proj1 = strcat('projection_',proj);
load('structures','structures');
load('experiments','experiments');
load('nodelist','nodelist');

n = length(experiments.id);
if ~isfield(experiments,'injection_site')
    experiments.injection_site = cell(n,1);
end

% Number of already imported experiments
nm = length(dir(fullfile('Data','*.mat')));
fprintf('Importing %d experiment files into MATLAB...\n',n-nm);

tic;
for i = 1:n
    if exist(fullfile('Data',[experiments.id{i} '.mat']),'file')==2
        continue;
    end
    
    % Load data
    str = fileread(fullfile('Data',[experiments.id{i} '.json']));
    d = JSON.parse(str);
    d = d.msg; % data in struct format
    
    % Create empty data structure
    StructureID = [];
    StructureName = [];
    HemisphereID = 0;
    for p = 1:4
        hem(1).(proj{p}) = []; % Left hemisphere data
        hem(2).(proj{p}) = []; % Right hemisphere data
    end
    
    for j = 1:length(d)
        if ~ismember(d{j}.structure_id,structures.id) % ignore unknown structures
            continue;
        end
        found = find(d{j}.structure_id==StructureID,1);
        if isempty(found)
            StructureID = [StructureID;d{j}.structure_id];
            StructureName = [StructureName;structures.name(structures.id==d{j}.structure_id)];
            found = length(StructureID); % add new structure at end
            for h = 1:2
                for p = 1:4
                    hem(h).(proj{p})(found) = 0;
                end
            end
        end

        % add data to data structure
        h = d{j}.hemisphere_id;
        if d{j}.is_injection==1 % injection site: add or replace
            if HemisphereID == 0
                HemisphereID = h;
            end
            for p = 1:4
                hem(h).(proj{p})(found) = d{j}.(proj1{p});
            end
        elseif hem(h).density(found)==0 % other: only add, don't replace
            for p = 1:4
                hem(h).(proj{p})(found) = d{j}.(proj1{p});
            end
        end
    end
    
    % Divide projections into ipsi- vs contralateral
    ipsi = hem(HemisphereID);
    contra = hem(3-HemisphereID);
    
    % Determine injection site by maximum projection density and normalize
    [found,ix] = ismember(StructureName,nodelist);
    ix = ix(found);
    [~,jx] = max(ipsi.density(ix));
    experiments.injection_site(i) = nodelist(jx);
    ix = ix(jx);
    for p = 1:4
        ipsi.(proj{p}) = ipsi.(proj{p})' / ipsi.(proj{p})(ix);
        contra.(proj{p}) = contra.(proj{p})' / ipsi.(proj{p})(ix);
    end
    
    save(fullfile('Data',experiments.id{i}), ...
        'StructureID','StructureName','HemisphereID','ipsi','contra');
    
    % Display progress every minute
    if toc>60
        fprintf('\t%d/%d\n',i+nm,n);
        tic;
    end
end

save('experiments','experiments','-append');