function retest_deadline()
global RETEST_TIMER
if ~isempty(RETEST_TIMER)&&toc(RETEST_TIMER)>30,error('Retest:Timeout','Recovery exceeds 30 seconds');end
end
