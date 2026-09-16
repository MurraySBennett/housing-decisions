function fact = didYouKnow(seed)
%UTILS.DIDYOUKNOW  One "Did you know..." fact for the saving screen.
%
%   fact = utils.didYouKnow(seed)
%
%   Picked deterministically from `seed` (use run.seed) so the same run
%   always shows the same fact and nothing consumes the global RNG stream
%   -- utils.elicitVAS already draws on the global stream, and the auction
%   deliberately keeps a private one, so silently pulling a random number
%   here would be a real contamination rather than a stylistic quibble.
%
%   DELIBERATE OMISSION. None of these is about judgement under
%   uncertainty, anchoring, reference points, search, valuation or
%   willingness to pay. Those are the constructs this study measures, and
%   a "did you know" about anchoring shown between blocks is a strategy
%   hint wearing a friendly hat. Everything here is general psychology
%   with no mapping onto anything a participant is about to do.
%
%   Keep it that way when adding to the list. The test for a new fact is:
%   could a participant plausibly change how they price, bid, search or
%   choose after reading it? If yes, it does not belong here.

FACTS = { ...
    ['Your brain uses roughly 20% of your body''s energy, despite being ' ...
     'about 2% of your body weight.']
    ['The "cocktail party effect" is your ability to pick your own name ' ...
     'out of a conversation you were not even listening to.']
    ['Most people can hold only about four things in mind at once. The ' ...
     'famous "seven, plus or minus two" estimate is now thought to be ' ...
     'too generous.']
    ['Your eyes make several rapid jumps per second, called saccades. ' ...
     'You are functionally blind during each one, and your brain edits ' ...
     'out the blur so smoothly you never notice.']
    ['Reading this sentence involves your eyes fixating for roughly a ' ...
     'quarter of a second at a time, skipping most short words entirely.']
    ['Sleep does not just rest the brain -- it actively replays and ' ...
     'consolidates what you learned that day.']
    ['The "tip of the tongue" state is so consistent across languages ' ...
     'that most of them have their own idiom for it.']
    ['People are markedly better at recognising faces from their own ' ...
     'neighbourhood or community than from groups they see rarely. It is ' ...
     'a familiarity effect, not a perceptual limit.']
    ['Colour does not exist in the world -- only wavelengths do. Colour ' ...
     'is what your visual system constructs from them.']
    ['The McGurk effect: watching a mouth say "ga" while hearing "ba" ' ...
     'makes most people hear "da". Vision overrides hearing.']
    ['Infants can distinguish every speech sound in every language. By ' ...
     'about ten months they have narrowed to the ones around them.']
    ['Change blindness means people routinely miss large alterations to a ' ...
     'scene while looking straight at it -- including, in one study, the ' ...
     'person they were talking to being swapped for someone else.']
    ['Your sense of where your limbs are, without looking, is a distinct ' ...
     'sense called proprioception.']
    ['Practising a skill in short sessions spread over days beats one ' ...
     'long session, even when total practice time is identical.']
    ['Memory is reconstructive rather than a recording -- each time you ' ...
     'recall something, you subtly rewrite it.']
};

if nargin < 1 || isempty(seed) || ~isfinite(seed)
    seed = 0;
end

idx = mod(floor(abs(double(seed))), numel(FACTS)) + 1;
fact = FACTS{idx};

end
