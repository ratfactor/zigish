const std = @import("std");

pub fn main() !u8 {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("*** Hello, I am a real shell! ***\n", .{});
    try shellLoop(stdin, stdout);

    return 0; // We are delighted.
}

fn shellLoop(stdin: std.fs.File.Reader, stdout: std.fs.File.Writer) !void {
    while (true) {
        const max_input = 1024;
        const max_args = 10;
        const max_arg_size = 255;

        // Input string buffer
        var input_buffer: [max_input]u8 = undefined;


        // Prompt and read stdin into buffer
        try stdout.print("> ", .{});
        var input_str = (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) orelse {
            // No input, probably CTRL-d (EOF). Print a newline and exit!
            try stdout.print("\n", .{});
            return;
        };

        // Don't do anything for zero-length input (user hit Enter).
        if (input_str.len == 0) continue;

        // The command and arguments are null-terminated strings.
        var args: [max_args][max_arg_size:0]u8 = undefined;// .{ .{0} ** max_arg_size } ** max_args;
        var args_ptrs: [max_args:null]?[*:0]u8 = undefined; // .{null} ** max_args;

        // Split by a single space. The returned SplitIterator must be var because
        // it has mutable internal state.
        var tokens = std.mem.split(input_str, " ");

        var i: usize = 0;
        while (tokens.next()) |tok| {
            std.mem.copy(u8, &args[i], tok);
            args[i][tok.len] = 0; // add sentinel 0
            args_ptrs[i] = &args[i];
            i += 1;
        }
        args_ptrs[i] = null; // add sentinel null


        // After calling fork(), TWO processed will continue running this
        // code! One is the parent, and the other is the new child.
        // The process can tell which one it is from the PID (Process ID)
        // value returned by fork();
        const fork_pid = try std.os.fork();

        // Who am I?
        if (fork_pid == 0) { // We are the child.

            //pub fn execvpeZ(
            //    file: [*:0]const u8,
            //    argv_ptr: [*:null]const ?[*:0]const u8,
            //    envp: [*:null]const ?[*:0]const u8,
            //) ExecveError {
            //    return execvpeZ_expandArg0(.no_expand, file, argv_ptr, envp);
            //}

            // EFAULT
            // https://sites.google.com/site/phillipfknaack/home/good-bugs/failed-exec
            const env = [_:null]?[*:0]u8{null};
            const result = std.os.execvpeZ(args_ptrs[0].?, &args_ptrs, &env);

            try stdout.print("ERROR: {}\n", .{result});
            return;
        } else { // We are the parent.
            // waitpid() waits for the child with specified PID and returns
            // a WaitPidResult with a u32 status field. The second parameter
            // is a u32 bitmask of options - 0 has no options turned on.
            const wait_result = std.os.waitpid(fork_pid, 0);
            if (wait_result.status != 0) {
                try stdout.print("Command returned {}.\n", .{wait_result.status});
            }
        }
    }
}
