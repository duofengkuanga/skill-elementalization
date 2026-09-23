<!-- gitnexus:start -->

# GitNexus — Code Intelligence

This project is indexed by GitNexus as **skill-elementalization** (1061 symbols, 2768 relationships, 93 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- CLI 检查使用 `Scripts/check-gitnexus-impact.sh <symbol>`；脚本会验证索引和结果字段。命令失败或结果不完整时先解决，不能把空输出视为已完成分析。直接调用 CLI 时目标符号是位置参数：`node .gitnexus/run.cjs impact Skill --direction upstream --repo skill-elementalization`。
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.
- NEVER EVER USE CLAUDE

## Resources

| Resource                                                | Use for                                  |
| ------------------------------------------------------- | ---------------------------------------- |
| `gitnexus://repo/skill-elementalization/context`        | Codebase overview, check index freshness |
| `gitnexus://repo/skill-elementalization/clusters`       | All functional areas                     |
| `gitnexus://repo/skill-elementalization/processes`      | All execution flows                      |
| `gitnexus://repo/skill-elementalization/process/{name}` | Step-by-step execution trace             |

## CLI

需要命令细节时运行 `node .gitnexus/run.cjs <command> --help`；先用 `status` 检查索引，过期时运行 `analyze`。

<!-- gitnexus:end -->
