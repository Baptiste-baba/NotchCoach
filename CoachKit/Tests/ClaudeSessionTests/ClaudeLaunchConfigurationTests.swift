import Foundation
import Testing
@testable import ClaudeSession

struct ClaudeLaunchConfigurationTests {
    let executable = URL(filePath: "/Users/test/.local/bin/claude")
    let workingDirectory = URL(filePath: "/Users/test/Library/Application Support/NotchCoach/ClaudeWorkingDirectory")

    func configuration(environment: [String: String] = [:]) -> ClaudeLaunchConfiguration {
        ClaudeLaunchConfiguration(
            executableURL: executable,
            options: ClaudeSessionOptions(systemPrompt: "Tu es un coach."),
            workingDirectory: workingDirectory,
            parentEnvironment: environment
        )
    }

    @Test func usesTheVerifiedIsolatedCommandLine() {
        #expect(configuration().arguments == [
            "-p",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--model", "haiku",
            "--tools", "",
            "--strict-mcp-config",
            "--setting-sources", "",
            "--no-session-persistence",
            "--system-prompt", "Tu es un coach.",
        ])
    }

    @Test func neverAllowsTools() {
        let arguments = configuration().arguments

        #expect(!arguments.contains("--dangerously-skip-permissions"))
        #expect(!arguments.contains("--allow-dangerously-skip-permissions"))
        #expect(!arguments.contains("bypassPermissions"))
        let toolsValue = arguments.firstIndex(of: "--tools").map { arguments[$0 + 1] }
        #expect(toolsValue == "")
    }

    @Test func keepsOnlyAllowedVariablesAndFixesPath() {
        let environment = configuration(environment: [
            "HOME": "/Users/test",
            "USER": "test",
            "LANG": "fr_FR.UTF-8",
            "PATH": "/opt/homebrew/bin:/usr/bin",
            "ANTHROPIC_API_KEY": "sk-ant-secret",
            "SSH_AUTH_SOCK": "/tmp/agent",
            "TMPDIR": "/var/folders/xx",
        ]).environment

        #expect(environment == [
            "HOME": "/Users/test",
            "USER": "test",
            "LANG": "fr_FR.UTF-8",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])
    }

    @Test func missingVariablesAreNotInvented() {
        #expect(configuration(environment: ["USER": "test"]).environment == [
            "USER": "test",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ])
    }

    @Test func passesExecutableAndWorkingDirectoryThrough() {
        let configuration = configuration()

        #expect(configuration.executableURL == executable)
        #expect(configuration.workingDirectory == workingDirectory)
    }
}
