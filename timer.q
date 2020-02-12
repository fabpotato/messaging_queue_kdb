\d .timer



debug:@[value;`debug;0b]                
logcall:@[value;`logcall;1b]                
nextscheduledefault:@[value;`nextscheduledefault;2h]


id:0
getID:{:1+count .timer.timer}
/*************
/when the getID function is called then the value of id increases by one each time, it amends the id variable
/*************
queue:([]
 time:`timestamp$();
 reportname:();
 location:();
 run_command:();
 externalargs:());

priorityQueue:([]
 time:`timestamp$();
 reportname:();
 location:();
 run_command:();
 externalargs:());

timer:([id:`int$()]         /- the id of the timer
 timerchange:`timestamp$();     /- when the function was added to the timer
 periodstart:`timestamp$();     /- the first time to fire the timer 
 periodend:`timestamp$();       /- the the last time to fire the timer  
 period:`timespan$();           /- how often the timer is run
 funcparam:();              /- the function and parameters to run
 lastrun:`timestamp$();         /- the last run time
 nextrun:`timestamp$();         /- the next scheduled run time
 active:`boolean$();            /- whether the timer is active
 nextschedule:`short$();        /- determines how the next schedule time should be calculated
 description:();
 status:(); / IDLE ENQUEUE RUNNING FAILED
 reportowner:`int$();
 run_command:();
 dow:();                        /- date of week
 location:());           /- a free text description
 /**************
 /setting the foundations for the timer table which will keep all information about the timer setup, all column types are set to a time related type
 /apart from active, description and funcparam
 /**************
  
/Users
users:([]
 psid:`long$();
 firstname:`$();
 lastname:`$();
 is_auth:`boolean$());

addUser:{[thisPsid; firstname; lastname]
    if[0 <> exec count i from .timer.users where psid=thisPsid;:`];
    `.timer.users upsert (thisPsid; firstname; lastname; 0b);
    saveUserTable`
    }

saveUserTable:{
    (`$":",((value `REPORTS_CONFIG_PATH),"../timer_config/.timer.users")) set 0!.timer.users
    }

check:{[fp;dupcheck]
    if[dupcheck;
        if[count select from timer where fp~/:funcparam;
                        '"duplicate timer already exists for function ",(-3!fp),". Use .timer.rep or .timer.one with dupcheck set to false to force the value"]];
    $[0=count fp; '"funcparam must not be an empty list";
      10h=type fp; '"funcparam must not be string.  Use (value;\"stringvalue\") instead";
      fp]}
 /***************
 /if dupcheck is of value 1, a second if statement is then performed which is a duplicate timer check. 
 /This tests what is supplied for fp against each funcparam in the table (each right). If the count is 1 that means that a timer already exists and a warning output is displayed
 /-3!fp returns the string representation of fp. If the variable fp contains no input then a warning statement is shown stating it must not be an empty list
 /If the type of the variable fp is a string (10h) then a warning statement is shown. If neither of these if conditions occur then fp is returned
 /****************
 
 
/- add a repeatingtimer
rep:{[start;end;period;funcparam;nextsch;descrip;data] 
    if[not nextsch in `short$til 3; '"nextsch mode can only be one of ",-3!`short$til 3];
    `.timer.timer upsert (getID[];.z.p;start:.z.p^start;0Wp^end;period;check[funcparam;data`dupcheck];0Np;start+period;1b;nextsch;descrip;`$"IDLE";data`reportowner;data`run_command;data`dow;data`location);}
/******************
/If the variable nextsch is not of a short typed number within 0 1 2h then the warning statement is outputted.
/The new timer information is upserted to the table. The timerID is increased by one due to the getID function
/The gmt timestamp is added to timerchange, the start variable can be any timestamp in the future and this is filled into the current .z.p 
/0Wp is the infitive timestamp and the end timestamp is filled to it and appended to period end. The check function is performed for funcparam where if passed then the fp variable is outputted. 
/Nextrun is the sum of the starting timestamp and the period of how often the timer runs. 
/******************


/- add a one off timer
one:{[runtime;funcparam;descrip;data] 
        `.timer.timer upsert (getID[];.z.p;.z.p;0Np;0Nn;check[funcparam;data`dupcheck];0Np;runtime;1b;0h;descrip;`$"IDLE";data`reportowner;data`run_command;data`dow;data`location);}
/********************
/the timer table is upserted to with:
/the ID being increased by one, the timerchange and the start is set to the current gmt timestamp, timer end is set to null timestamp, period is set to null timespan. 
/No last run has been performed so this is a null timestamp. Nextschedule is set to default 0h.
/********************


/- projection to add a default repeating timer.  Scheduling mode 2 is the safest - least likely to back up
repeat:rep[;;;;nextscheduledefault;;1b]
once:one[;;;1b]
/********************
/These will be the functions used to setup the timers
/********************


/- Remove a row from the timer 
remove:{[timerid] delete from `.timer.timer where id=timerid}
removefunc:{[fp] delete from `.timer.timer where fp~/:funcparam}
/********************
/To remove an entire row from the timer table, calling the remove function with a specific timer id will delete it
/If a function parameter needs deleting from the timer table then if fp is matched to any of the funcparams then it is removed
/********************

startSecondarySubs:{
    command: "start q ",(value `REPORTS_CONFIG_PATH),"../../q/src/q7100.q";
    system command;
 };

/- run a timer function and reschedule if required
run:{
    /- Pull out the rows to fire
    /- Assume we only use period start/end when creating the next run time
    /- sort asc by lastrun so the timers which are due and were fired longest ago are given priority
    if[0<>count .timer.queue; if[0D00:10 < .z.p - exec first time from .timer.queue; .timer.startSecondarySubs`]];
    if[0<>count .timer.priorityQueue; if[0D00:10 < .z.p - exec first time from .timer.priorityQueue; .timer.startSecondarySubs`]];
    torun:`lastrun xasc 0!select from timer where active,nextrun<x; 
    / runandreschedule each torun
    {[x].[enqueue;(x;"";`priority);0b]} each torun;
    (`$":",((value `REPORTS_CONFIG_PATH),"../timer_config/.timer.timer")) set 0!.timer.timer;}
/********************   
/Select the timer id in the table that has a nextrun less than the timestamp supplied.
/The 0! is to convert a keyed table to a standard primitive non-keyed table where the extracted rows are sorted by the lastrun column and the timer waiting 
/the longest is then ran. The runandreschedule method below is applied to each extracted row
/********************
 
runone:{
    // Pull out the rows to fire
    // Assume we only use period start/end when creating the next run time
    // sort asc by lastrun so the timers which are due and were fired longest ago are given priority
    torun:`lastrun xasc 0!select from timer where description like x; 
    .[enqueue;(first torun;y;`normal);0b]}

 /- run a timer function and reschedule it if required
runandrescheduleReference:{
    /- if debug mode, print out what we are doing   
    if[debug; -1"running timer ID ",(string x`id),". Function is ",-3!x`funcparam];
    start:.z.p;
    @[$[logcall;0;value];x`funcparam;{update active:0b from `.timer.timer where id=x`id; -2"timer ID ",(string x`id)," failed with error ",y,".  The function will not be rescheduled"}[x]];
    op:@[read0; hsym `$(x[`location],"result.txt");"0 "];
    if[not op~"0 ";{update active:0b from `.timer.timer where id=x`id; -2"timer ID ",(string x`id),". The function will not be rescheduled"}[x]];
    /- work out the next run time
    n:x[`period]+(x[`nextrun];start;.z.p) x`nextschedule;
    /- check if the next run time falls within the sceduled period
    /- either up the nextrun info, or switch off the timer
    $[n within x`periodstart`periodend;
        update lastrun:start,nextrun:n from `.timer.timer where id=x`id;
        [if[debug;-1"setting timer ID ",(string x`id)," to inactive as next schedule time is outside of scheduled period"];
         update lastrun:start,active:0b from `.timer.timer where id=x`id]];
    (`$":",((value `REPORTS_CONFIG_PATH),"../timer_config/.timer.timer")) set 0!.timer.timer;
    }

enqueue:{[x;y;z]
    start:.z.p;
    dateToday: 14h$start;
    n:x[`nextrun];
    while[n < start; n:n+x`period];
    $[n within x`periodstart`periodend;
        update lastrun:start,nextrun:n from `.timer.timer where id=x`id;
        [if[debug;-1"setting timer ID ",(string x`id)," to inactive as next schedule time is outside of scheduled period"];
         update lastrun:start,active:0b from `.timer.timer where id=x`id]];
    if[(z=`priority) and "0"=x[`dow] .z.D mod 7; show "unable to run as incorrect dow";:`dow_error];
    $[z=`priority;
    `.timer.priorityQueue upsert (.z.p;x`description;x`location;(x[`location],x[`run_command]);y);
    `.timer.queue upsert (.z.p;x`description;x`location;(x[`location],x[`run_command]);y)]
    update status:`ENQUEUE from `.timer.timer where id=x`id;
    1b
    }

popQueue:{
    if[(0 = count .timer.priorityQueue) and (0 = count .timer.queue); :()!()];
    $[0 <> count .timer.priorityQueue;
    [data:.timer.priorityQueue[0];
    .timer.priorityQueue:1_.timer.priorityQueue;
    update status:`RUNNING from `.timer.timer where description like data`reportname;
    :data];    
    [data:.timer.queue[0];
    .timer.queue:1_.timer.queue;
    update status:`RUNNING from `.timer.timer where description like data`reportname;
    :data]]
    }


loaded:1b

/- Set .z.ts
$[@[{value x;1b};`.z.ts;0b];
    .z.ts:{.timer.run[y]; x@y}[.z.ts];
    .z.ts:{.timer.run[x]}];

if[not system"t"; system"t 200"]
