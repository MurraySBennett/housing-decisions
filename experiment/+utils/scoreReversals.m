function rev = scoreReversals(trials)
%SCOREREVERSALS  Per pair: chose one option but priced the other higher.

rev = struct('pairIdx', {}, 'level', {}, 'choseMoney', {}, ...
             'pricedMoneyHigher', {}, 'reversal', {});

if isempty(trials), return; end
levels = unique([trials.level]);

for L = levels
    sub = trials([trials.level] == L);
    ch  = sub(strcmp({sub.taskType}, 'choice'));
    pr  = sub(strcmp({sub.taskType}, 'price'));

    for k = 1:numel(ch)
        if ch(k).timedOut || isnan(ch(k).choseMoney)
            continue
        end
        pIdx = ch(k).pairIdx;
        pp = pr([pr.pairIdx] == pIdx);
        if numel(pp) < 2, continue; end

        m = pp([pp.isMoneyOption]);
        q = pp(~[pp.isMoneyOption]);
        if isempty(m) || isempty(q) || isnan(m(1).price) || isnan(q(1).price)
            continue
        end

        pricedMoneyHigher = m(1).price > q(1).price;
        r = struct();
        r.pairIdx           = pIdx;
        r.level             = L;
        r.choseMoney        = ch(k).choseMoney;
        r.pricedMoneyHigher = pricedMoneyHigher;
        r.reversal          = (ch(k).choseMoney ~= pricedMoneyHigher);
        rev(end+1) = r; %#ok<AGROW>
    end
end

end

