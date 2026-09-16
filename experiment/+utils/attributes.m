function A = attributes(domain)
%UTILS.ATTRIBUTES  Tiered attribute definitions for one domain.
%
%   A = utils.attributes('houses')
%   A = utils.attributes('jobs')
%
%   Four tiers, so the attribute-count manipulation is explicit rather than
%   an accident of table column order (the previous drawItemCard took the
%   first N columns, which meant Zone/Address and Industry/Title were being
%   counted as attributes):
%
%     identity : always shown, NOT counted toward the attribute level.
%                Without these the option isn't a coherent object.
%     core     : always shown, IS counted. Contains the value variable,
%                because that is the anchor the pricing model needs.
%     pool     : the attributes that scale with the 2/4/6 manipulation,
%                selected per participant from their importance ratings.
%     late     : held back until the highest attribute level, for variables
%                expected to dominate choice.

switch lower(char(domain))

    case 'houses'
        % All six photos are IDENTITY now, not pool attributes: always
        % shown regardless of attribute-count level, never counted toward
        % it. Two reasons. First, that's the actual design intent -- a
        % house's photos aren't optional information the way "lot size" is,
        % they're part of what makes it a coherent, recognizable option.
        % Second, and more concretely: when a photo WAS a selectable pool
        % attribute, the attribute-count manipulation could land on an
        % attribute-level where the only thing shown besides price was a
        % single photo -- zero NUMERIC non-value attributes on screen, so
        % utils.buildPairs had no quality dimension to construct a
        % money-vs-quality pair from at all. Moving photos out of the pool
        % means the pool is purely numeric, so a quality dimension always
        % exists.
        A.identity = struct( ...
            'var',   {'extPic','kitPic','bedPic','bathPic','livPic','outPic'}, ...
            'label', {'Exterior','Kitchen','Bedroom','Bathroom', ...
                      'Living room','Outdoor space'}, ...
            'kind',  {'image','image','image','image','image','image'}, ...
            'dir',   {0, 0, 0, 0, 0, 0});

        % dir = -1: for a buyer, a higher price is worse.
        % "Listed price", not "Price": the participant is about to state a
        % price of their own, and the card value must read unambiguously
        % as the advertised figure rather than as the answer.
        A.core = struct( ...
            'var',   {'listPrice'}, ...
            'label', {'Listed price'}, ...
            'kind',  {'currency'}, ...
            'dir',   {-1});

        A.pool = struct( ...
            'var',   {'nBeds','nBaths','sqft','lotSize','yearBuilt'}, ...
            'label', {'Bedrooms','Bathrooms','Square feet','Lot size (acres)', ...
                      'Year built'}, ...
            'kind',  {'count','count','number','number','year'}, ...
            'dir',   {1, 1, 1, 1, 1});

        % Zone is 2-level and confounded with lot size, square footage and
        % bedroom count, so its weight estimate absorbs variance from those.
        % Held to the top level deliberately.
        A.late = struct( ...
            'var',   {'Zone'}, ...
            'label', {'Region'}, ...
            'kind',  {'category'}, ...
            'dir',   {0});

        A.valueVar = 'listPrice';
        A.priceStyle = 'total';

    case 'jobs'
        % 'title' / 'Position' deliberately removed 2026-09-15. Under
        % JOBS_ARM = 'synthetic' the title column is a generated placeholder
        % ('title_001'), so every card header read "Healthcare - title_001";
        % under 'attenuated' it is a real title attached to another job's
        % wage, which is worse -- a recognizable occupation next to a wage
        % that occupation does not command. Restore by adding 'title' /
        % 'Position' / 'category' / 0 back to the four rows below. The
        % column stays in every prepared CSV either way.
        A.identity = struct( ...
            'var',   {'industry'}, ...
            'label', {'Industry'}, ...
            'kind',  {'category'}, ...
            'dir',   {0});

        % dir = +1: for a job seeker, a higher wage is better.
        % "Offered wage", not "Wage" -- see the houses note above.
        A.core = struct( ...
            'var',   {'wage'}, ...
            'label', {'Offered wage'}, ...
            'kind',  {'hourly'}, ...
            'dir',   {1});

        A.pool = struct( ...
            'var',   {'workLife','culture','compensationBenefits','management', ...
                      'jobSecurityAdvancement','commuteMinutes','ptoDays','hoursPerWeek'}, ...
            'label', {'Work-life balance','Culture','Benefits','Management', ...
                      'Job security & advancement','Commute (min)', ...
                      'Paid time off (days)','Hours per week'}, ...
            'kind',  {'rating','rating','rating','rating','rating', ...
                      'number','count','count'}, ...
            'dir',   {1, 1, 1, 1, 1, -1, 1, -1});

        % NOTE: this is a judgement call and worth revisiting. Zone's job
        % analogue isn't obvious -- industry is already a filter, and wage
        % has to stay in core because it's the anchor. Work arrangement is
        % the most plausible dominator left. It also has zero variance in
        % several industries under the realistic generation, so if you keep
        % it here, check the participant's industry set has variance in it.
        A.late = struct( ...
            'var',   {'workArrangement'}, ...
            'label', {'Work arrangement'}, ...
            'kind',  {'category'}, ...
            'dir',   {0});

        A.valueVar = 'wage';
        A.priceStyle = 'hourly';

    otherwise
        error('hw:attributes:unknownDomain', 'Unknown domain "%s".', domain);
end

A.domain    = lower(char(domain));
A.nCore     = numel(A.core);
A.nPool     = numel(A.pool);
A.maxLevel  = A.nCore + A.nPool;

end
