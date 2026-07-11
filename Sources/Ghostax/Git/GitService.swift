import Foundation

actor GitService {
    func status(at workspaceURL: URL) async throws -> GitStatusSnapshot {
        async let branch = runGit(["branch", "--show-current"], at: workspaceURL)
        async let porcelain = runGit(["status", "--porcelain=v1", "-uall"], at: workspaceURL)

        let branchName = try await branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let statusOutput = try await porcelain
        let files = statusOutput
            .split(separator: "\n")
            .compactMap(parseStatusLine)

        return GitStatusSnapshot(
            branch: branchName.isEmpty ? "detached" : branchName,
            files: files,
            error: nil
        )
    }

    func diff(file: GitChangedFile, at workspaceURL: URL) async throws -> String {
        if file.indexStatus == "?" {
            return try await runGit(["diff", "--no-index", "--", "/dev/null", file.path], at: workspaceURL, allowExitCodeOne: true)
        }

        let unstaged = try await runGit(["diff", "--", file.path], at: workspaceURL)
        if !unstaged.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return unstaged
        }
        return try await runGit(["diff", "--cached", "--", file.path], at: workspaceURL)
    }

    func openDiffInFileMerge(file: GitChangedFile, at workspaceURL: URL) async throws {
        let filePath = workspaceURL.appendingPathComponent(file.path).path

        if file.indexStatus == "?" {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [filePath]
            try process.run()
            return
        }

        let gitRef = file.hasStagedChanges && !file.hasUnstagedChanges ? "HEAD" : "HEAD"
        let original = try await runGit(["show", "\(gitRef):\(file.path)"], at: workspaceURL, allowExitCodeOne: true)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ghostax-diff")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let baseName = URL(fileURLWithPath: file.path).lastPathComponent
        let tempFile = tempDir.appendingPathComponent("HEAD_\(baseName)")
        try original.write(to: tempFile, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/opendiff")
        process.arguments = [tempFile.path, filePath]
        process.currentDirectoryURL = workspaceURL
        try process.run()
    }

    func stage(file: GitChangedFile, at workspaceURL: URL) async throws {
        _ = try await runGit(["add", "--", file.path], at: workspaceURL)
    }

    func unstage(file: GitChangedFile, at workspaceURL: URL) async throws {
        _ = try await runGit(["restore", "--staged", "--", file.path], at: workspaceURL)
    }

    func stageAll(at workspaceURL: URL) async throws {
        _ = try await runGit(["add", "--all"], at: workspaceURL)
    }

    func unstageAll(at workspaceURL: URL) async throws {
        _ = try await runGit(["restore", "--staged", "--", "."], at: workspaceURL)
    }

    private func parseStatusLine(_ line: Substring) -> GitChangedFile? {
        guard line.count >= 4 else { return nil }
        let index = String(line.prefix(1))
        let workTree = String(line.dropFirst().prefix(1))
        let rawPath = String(line.dropFirst(3))
        let path = rawPath.replacingOccurrences(of: "\"", with: "")
        return GitChangedFile(path: path, indexStatus: index, workTreeStatus: workTree)
    }

    private func runGit(_ arguments: [String], at workspaceURL: URL, allowExitCodeOne: Bool = false) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = arguments
            process.currentDirectoryURL = workspaceURL
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let output = stdout.fileHandleForReading.readDataToEndOfFile()
                let error = stderr.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0 || (allowExitCodeOne && process.terminationStatus == 1) {
                    continuation.resume(returning: String(decoding: output, as: UTF8.self))
                } else {
                    continuation.resume(throwing: GitServiceError(
                        message: String(decoding: error, as: UTF8.self)
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

struct GitServiceError: LocalizedError {
    var message: String

    var errorDescription: String? {
        message.isEmpty ? "Git command failed" : message
    }
}
