import Foundation

struct ShellResult {
    let status: Int32
    let stdout: String
    let stderr: String

    var ok: Bool { status == 0 }

    /// Best human-readable message for a failed command.
    var message: String {
        let text = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        let out = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? "exit status \(status)" : out
    }
}

enum Shell {
    /// Runs an executable directly (no shell) and waits for it. Call off the main thread.
    @discardableResult
    static func run(_ executable: String, _ arguments: [String] = []) -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return ShellResult(status: -1, stdout: "", stderr: error.localizedDescription)
        }
        let out = outPipe.fileHandleForReading.readDataToEndOfFile()
        let err = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ShellResult(
            status: process.terminationStatus,
            stdout: String(decoding: out, as: UTF8.self),
            stderr: String(decoding: err, as: UTF8.self)
        )
    }

    /// Runs a command as root through the standard macOS administrator prompt.
    /// `arguments` are single-quoted for the shell, so paths with spaces are safe.
    static func runAsAdmin(_ arguments: [String], prompt: String) -> ShellResult {
        let command = arguments.map(shellQuote).joined(separator: " ")
        let script = "do shell script \(appleScriptString(command)) "
            + "with prompt \(appleScriptString(prompt)) with administrator privileges"
        let result = run("/usr/bin/osascript", ["-e", script])
        // osascript reports a cancelled prompt as error -128.
        if !result.ok, result.stderr.contains("-128") {
            return ShellResult(status: result.status, stdout: "", stderr: "Cancelled.")
        }
        return result
    }

    static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func appleScriptString(_ s: String) -> String {
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }
}
