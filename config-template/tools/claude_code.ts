import { tool } from "@opencode-ai/plugin"

const MODELS = ["default", "sonnet", "opus", "haiku"] as const
const MODES = ["analyze", "edit"] as const

export default tool({
  description:
    "Delegate a bounded task to the official Claude Code CLI using the user's Claude subscription. Select default, sonnet, opus, or haiku. Use analyze for read-only work and edit only when the user requested file changes.",
  args: {
    task: tool.schema.string().min(1).max(20_000).describe("The complete task for Claude Code"),
    model: tool.schema.enum(MODELS).default("default").describe("Claude model alias"),
    mode: tool.schema.enum(MODES).default("analyze").describe("Read-only analysis or file editing"),
    maxTurns: tool.schema.number().int().min(1).max(30).default(12).describe("Maximum agentic turns"),
  },
  async execute(args, context) {
    if (!process.env.CLAUDE_CODE_OAUTH_TOKEN) {
      throw new Error("Claude Code is not authenticated. Configure CLAUDE_CODE_OAUTH_TOKEN in the OpenCode stack environment.")
    }

    const command = [
      "claude",
      "-p",
      "--output-format",
      "json",
      "--no-session-persistence",
      "--safe-mode",
      "--restricted",
      "--strict-mcp-config",
      "--no-chrome",
      "--max-turns",
      String(args.maxTurns),
      "--permission-mode",
      args.mode === "edit" ? "acceptEdits" : "plan",
      "--tools",
      args.mode === "edit" ? "Read,Edit,Write,Glob,Grep" : "Read,Glob,Grep",
      "--disallowedTools",
      "mcp__*",
      "--append-system-prompt",
      args.mode === "edit"
        ? "Work only on the requested task. You may inspect and edit files, but do not run shell commands. Report changed files and any verification OpenCode should run."
        : "Analyze only. Do not modify files. Return concise findings with file references when applicable.",
    ]

    if (args.model !== "default") command.push("--model", args.model)
    command.push("--", args.task)

    // Ensure Claude Code uses the subscription token even when OpenCode itself
    // uses an Anthropic API key or cloud provider.
    const claudeEnv = { ...process.env }
    for (const name of [
      "ANTHROPIC_API_KEY",
      "ANTHROPIC_AUTH_TOKEN",
      "ANTHROPIC_PROFILE",
      "ANTHROPIC_FEDERATION_RULE_ID",
      "ANTHROPIC_ORGANIZATION_ID",
      "CLAUDE_CODE_USE_BEDROCK",
      "CLAUDE_CODE_USE_VERTEX",
      "CLAUDE_CODE_USE_FOUNDRY",
    ]) {
      delete claudeEnv[name]
    }

    const child = Bun.spawn(command, {
      cwd: context.directory,
      env: claudeEnv,
      stdout: "pipe",
      stderr: "pipe",
    })

    const timeout = setTimeout(() => child.kill(), 30 * 60 * 1000)
    const [exitCode, stdout, stderr] = await Promise.all([
      child.exited,
      new Response(child.stdout).text(),
      new Response(child.stderr).text(),
    ])
    clearTimeout(timeout)

    if (exitCode !== 0) {
      const detail = stderr.trim().slice(-4_000) || stdout.trim().slice(-4_000)
      throw new Error(`Claude Code exited with status ${exitCode}${detail ? `: ${detail}` : ""}`)
    }

    try {
      const result = JSON.parse(stdout)
      if (result.is_error) throw new Error(result.result || "Claude Code returned an error")
      return String(result.result ?? stdout).trim()
    } catch (error) {
      if (error instanceof SyntaxError) return stdout.trim()
      throw error
    }
  },
})
