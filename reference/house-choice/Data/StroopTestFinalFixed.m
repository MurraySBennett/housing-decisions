words=['YELLOW ';'MAGENTA';'CYAN   ';'RED    ';'GREEN  ';'BLUE   ';'BLACK  ';]; %1
colors=[1 1 0;1 0 1;0 1 1;1 0 0;0 1 0;0 0 1;0 0 0]; %2
SHUFFLE1=0; %3
SHUFFLE2=1; %4
prob_size1=5; %5
prob_size2=15; %6

rtList = [];

subjectNum = 4;


StroopTest(words,colors,SHUFFLE2,prob_size1,1,11) % Arial Font, Font Size 11; Control Trial
WaitSecs(.2);
for n = 1:25
    respEntered = 0;
    t0 = GetSecs;
    while respEntered == 0
        [~,~,buttons] = GetMouse;
        if any(buttons)
            respEntered = 1;
        end
        
    end
    rt = GetSecs - t0;
    WaitSecs(.2);
    rtList = [rtList; rt];
end


StroopTest(words,colors,SHUFFLE2,prob_size1,2,22) % Arial Font increased by 100%, Font Size 22; Experimental Trial #1
%     fontsize(gcf,scale=2.0)
WaitSecs(.2);
for n = 1:25
    respEntered = 0;
    t0 = GetSecs;
    while respEntered == 0
        [~,~,buttons] = GetMouse;
        if any(buttons)
            respEntered = 1;
        end
        
    end
    rt = GetSecs - t0;
    WaitSecs(.2);
    rtList = [rtList; rt];
end

StroopTest(words,colors,SHUFFLE2,prob_size1,3,33) % Arial Font increased by 100%, Font Size 33; Experimental Trial #2
%     fontsize(gcf,scale=3.0)
WaitSecs(.2);
for n = 1:25
    respEntered = 0;
    t0 = GetSecs;
    while respEntered == 0
        [~,~,buttons] = GetMouse;
        if any(buttons)
            respEntered = 1;
        end
        
    end
    rt = GetSecs - t0;
    WaitSecs(.2);
    rtList = [rtList; rt];
end

csvwrite(['Data',num2str(subjectNum),'.csv'],rtList);
