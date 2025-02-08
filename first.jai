#import "Basic";
#import "Compiler";

OUTPUT_EXECUTABLE_NAME  := "game";
OUTPUT_SERVER_NAME      := "server";
OUTPUT_CLIENT_NAME      := "client";

#run {
    build_debug := false;
    build_server := false;
    build_client := false;

    options := get_build_options();
    options.os_target = .LINUX;
    options.backend = .X64;
    options.text_output_flags = 0;

    args := options.compile_time_command_line;
    for arg: options.compile_time_command_line {
        if arg == {
          case "debug"; build_debug = true;
          case; compiler_report(tprint("Command-line argument #%, '%', is invalid. Valid options are: 'debug'.\n", it_index+1, arg));
        }
    }

    // no networking
    {
        w := compiler_create_workspace("Target workspace2");

        options.output_executable_name = OUTPUT_EXECUTABLE_NAME;
        set_optimization(*options, .DEBUG);
        set_build_options(options, w);

        add_build_file("src/main.jai", w);
        add_build_string(tprint("DEBUG :: %;", build_debug), w);
        add_build_string("SERVER :: false;", w);
        add_build_string("CLIENT :: false;", w);
    }

    // server
    {
        w := compiler_create_workspace("Target workspace3");

        options.output_executable_name = OUTPUT_SERVER_NAME;
        set_optimization(*options, .DEBUG);
        set_build_options(options, w);

        add_build_file("src/main-server.jai", w);
        add_build_string(tprint("DEBUG :: %;", build_debug), w);
        add_build_string("SERVER :: true;", w);
        add_build_string("CLIENT :: false;", w);
    }

    // client
    {
        w := compiler_create_workspace("Target workspace4");

        options.output_executable_name = OUTPUT_CLIENT_NAME;
        set_optimization(*options, .DEBUG);
        set_build_options(options, w);

        add_build_file("src/main.jai", w);
        add_build_string(tprint("DEBUG :: %;", build_debug), w);
        add_build_string("SERVER :: false;", w);
        add_build_string("CLIENT :: true;", w);

    }

    set_build_options_dc(.{do_output=false }); // dont create executable from this file
}
