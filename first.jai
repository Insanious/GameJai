#import "Basic";
#import "Compiler";

OUTPUT_EXECUTABLE_NAME := "game";

#run {
    w := compiler_create_workspace("Target workspace");
    options := get_build_options();
    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;
    options.os_target = .LINUX;
    options.text_output_flags = 0;

    build_debug := false;

    args := options.compile_time_command_line;
    for arg: options.compile_time_command_line {
        if arg == {
          case "debug"; build_debug = true;
          case; compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug'.\n", it_index+1, arg));
        }
    }

    set_optimization(*options, .DEBUG);
    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("src/main.jai", w);
    add_build_string(tprint("DEBUG :: %;", build_debug), w);
    compiler_end_intercept(w);

    set_build_options_dc(.{do_output=false }); // dont create executable from this file
}
