.global.iter:0;
.global.tolorance:15;

.z.ts:{
    if[(not `server7000 in key `.handle);.handle.server7000: @[{hopen `::7000};`;0N]];
    $[(.handle.server7000=0N) or @[{.handle.server7000({0b};`)};`;1b];.handle.server7000: @[{hopen `::7000};`;0N];dequeue`];
    check_idle`;
 };

dequeue:{
    data: .handle.server7000(".timer.popQueue`"); 
    if[data~()!(); check_idle`; show "No pending reports"; :`FIN]; 
    .global.iter:0;
    .handle.server7000({update status:`$"RUNNING" from `.timer.timer where description like x};data`reportname);  
    status: .[execute_report;(data`run_command;data`externalargs;data`location);0b];
    $[status;.handle.server7000({update status:`$"IDLE" from `.timer.timer where description like x};data`reportname);
    .handle.server7000({update status:`$"FAILED" from `.timer.timer where description like x};data`reportname)];
 };

/ params @command: execute command 
/ @externalargs: external argument dictionary -to be read by report
/ @location: location of the report
/ function to execute report
/ present at .timer.timer
execute_report:{[command; externalargs;location]
    command: command;
    / TODO:
    / Global dictionary fits here : 
    globalconfig: @[{globalconfigloc: "global_config.json";
    config: raze read0 hsym `$globalconfigloc;
    .j.k config};`;{show "error reading global config ", x;()!()}];
    externalargs: .j.j globalconfig, @[{[x] .j.k x};externalargs;{[externalargs; x] if[not externalargs~"";show "unable to jsonify : ",externalargs]; ()!()}[externalargs;]];
    `EXTERNALARGS setenv externalargs;
    system command;
    op:@[read0; hsym `$(location,"result.txt");"0nf "];
    if[0h = type op; op: raze op];
    op~"0 "
 };

check_idle:{
    port: system "p";
    if[port=7100i;:`master_port];
    .global.iter:.global.iter+1;
    if[.global.iter>.global.tolorance;exit 0];
 };


if[0=system "t"; system "t 2000"];