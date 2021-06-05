const std = @import("std");

pub fn main() !u8 {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try stdout.print("*** Hello, I am a real shell! ***\n", .{});
    try shellLoop(stdin, stdout);

    return 0; // We either crash or we are fine.
}

fn shellLoop(stdin: std.fs.File.Reader, stdout: std.fs.File.Writer) !void {
    while (true) {
        const max_input = 1024;
        const max_args = 10;
        const max_arg_size = 255;

        // Prompt
        try stdout.print("> ", .{});

        // Read STDIN into buffer
        var input_buffer: [max_input]u8 = undefined;
        var input_str = (try stdin.readUntilDelimiterOrEof(input_buffer[0..], '\n')) orelse {
            // No input, probably CTRL-d (EOF). Print a newline and exit!
            try stdout.print("\n", .{});
            return;
        };

        // Don't do anything for zero-length input (user just hit Enter).
        if (input_str.len == 0) continue;

        // The command and arguments are null-terminated strings. These arrays are
        // storage for the strings and pointers to those strings.
        var args: [max_args][max_arg_size:0]u8 = undefined;
        var args_ptrs: [max_args:null]?[*:0]u8 = undefined;

        // Split by a single space. The returned SplitIterator must be var because
        // it has mutable internal state.
        var tokens = std.mem.split(input_str, " ");

        // Copy each string "token" into the storage array and save a pointer to it.
        var i: usize = 0;
        while (tokens.next()) |tok| {
            std.mem.copy(u8, &args[i], tok);
            args[i][tok.len] = 0; // add sentinel 0
            args_ptrs[i] = &args[i];
            i += 1;
        }
        args_ptrs[i] = null; // add sentinel null

        // After calling fork(), TWO processes will continue running this
        // code! One is the parent, and the other is the new child.
        // The process can tell which one it is from the PID (Process ID)
        // value returned by fork();
        const fork_pid = try std.os.fork();

        // Who am I?
        if (fork_pid == 0) { // We are the child.

            // Make a null environment of the correct type.
            const env = [_:null]?[*:0]u8{null};

            // Execute command, replacing child process!
            const result = std.os.execvpeZ(args_ptrs[0].?, &args_ptrs, &env);

            // If we make it this far, the exec() call has failed!
            try stdout.print("ERROR: {}\n", .{result});
            return;

        } else { // We are the parent.

            // waitpid() waits for the child with specified PID and returns
            // a WaitPidResult with a u32 status field. The second parameter
            // is a u32 bitmask of options - 0 has no options turned on.
            const wait_result = std.os.waitpid(fork_pid, 0);

            // Anything but 0 is an error return status. Let's print it.
            if (wait_result.status != 0) {
                try stdout.print("Command returned {}.\n", .{wait_result.status});
            }
        }
    }
}
