REPORTS_CONFIG_PATH: getenv[`REPORTS_HOME],"/reportHandler/report_config/";

/ params @dirpath: directory path for json report report_config
/ fetches all report in the config ! important ! ONLY WINDOWS ! important !
get_files:{[dirpath]
    command: "dir ",ssr[dirpath;"/";"\\"]," /b /o";
    result: system command;
    result
 };

/ params @filepath
/ q function to read json 
read_json:{[filepath]
    data: .j.k raze read0 hsym `$filepath;
    data
 };

/ param @filepath: filepath for the env
update_timer:{[filepath]
    data: read_json[REPORTS_CONFIG_PATH,filepath];
    start:-12h$data`start;
    end:-12h$data`end;
    period: -16h$data`period;
    the_reportowner:`int$data`reportowner;
    is_dup: exec count i from .timer.timer where reportowner=the_reportowner, description like data`descrip;
    if[is_dup>0; :`dup];
    .timer.rep[start;end;period;({});0h;data`descrip;(`dupcheck`reportowner`run_command`dow`location)!(0b; the_reportowner;data[`run_command];data[`dow];data[`location])];
 };

/ updates .timer.timer according to the report
/ setup function
set_timer:{
    files:get_files[REPORTS_CONFIG_PATH];
    update_timer each files;
 };