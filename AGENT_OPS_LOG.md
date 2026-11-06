# Agent 操作日志

> 本仓库由多个 agent 协作维护（不同机器/系统，如 Windows 与 Ubuntu 26），
> 此文件记录**非主责 agent** 的操作，便于主责 agent 判断改动来源、避免相互干扰。
>
> - 用途：只记录操作轨迹，不承载项目文档
> - 写法：在文件末尾追加条目，尽量不改动他人条目，减少合并冲突
> - 格式：`## YYYY-MM-DD HH:mm` + 操作人/模型 + 操作内容 + 涉及文件/命令 + 结果
> - 纯问答、未触动仓库的操作无需记录

---

## 2026-11-06 会话初始化

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：读取 `temp/` 目录清单、检查 `.gitignore` 中的 `temp/` 规则（只读）
- 涉及文件：无修改
- 结果：确认 `temp/` 已被忽略；未对仓库代码做任何改动

## 2026-11-06 建立跨机器操作日志

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：将操作日志从 `temp/` 迁到版本控制的仓库根目录，供其他机器上的 agent 查看
- 涉及文件：新增 `AGENT_OPS_LOG.md`，删除 `temp/agent-ops-log.md`
- 结果：日志纳入 git

## 2026-11-06 统一 Markdown Raw 与代码查看器渲染

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：修复 Raw 模式与代码文件查看器两套独立实现导致的渲染/交互不一致
- 涉及文件：
  - 新增 `lib/src/ui/code_view.dart`（共用 `CodeView` / `CodeViewController`）
  - 改写 `lib/src/ui/code_viewer.dart`（改为复用 `CodeView`，读文件统一 `decodeTextBytes`）
  - 修改 `lib/src/ui/markdown_viewer.dart`（Raw 模式复用 `CodeView`，独立滚动、固定字号、默认不换行、大纲/查找/换行工具条）
  - 新增 `test/raw_code_view_test.dart`，补充 `test/code_viewer_test.dart` 的 GBK 用例
  - 同步更新 `AGENTS.md` 的代码查看章节
- 验证：`flutter analyze` 无问题；相关测试通过（`raw_code_view_test` / `code_viewer_test` / `reader_find_test` / `lazy_body_test`）
- 已知与本次无关：`test/widget_test.dart` 在基线提交上同样失败（停在 `BrandSplash`），非本次改动引入

## 2026-11-06 新增 Prerelease 发版支持

- 操作人：opencode / deepseek-v4.1-flash-free（Windows）
- 操作：`release.yml` 在 tag 带 SemVer 预发布后缀（如 `v1.12.0-rc1`）时创建 GitHub Prerelease；正式 tag 行为不变
- 涉及文件：`.github/workflows/release.yml`（版本校验支持 `-rc1` 后缀、`prerelease` 按 tag 名判断）、`AGENTS.md`（发版约定）
- 验证：未推送/未实际触发 workflow；YAML 仅文本修改
