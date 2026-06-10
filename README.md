# SchoNavi

SchoNavi 是一个 Flutter 应用。应用入口位于 `lib/main.dart`，应用壳位于 `lib/app.dart`。

## 模块

- `lib/core`：应用配置、路由、主题、依赖注入、AI 客户端、本地存储和外链能力。
- `lib/domain`：业务实体与 repository 接口。
- `lib/data`：mock 数据、本地持久化、AI repository 实现和 DTO。
- `lib/features`：首页、推荐、教授详情、聊天、邮件、对比、收藏和历史页面。
- `lib/shared`：跨页面复用组件。
- `test`：对应模块的测试。

## 架构

项目采用 Flutter UI + Riverpod 状态管理/依赖注入 + GoRouter 路由。业务层通过 `domain` 中的 repository 接口隔离，数据层在 `data` 中提供 mock、本地和 AI 等实现，由 `core` 中的配置与 provider 统一接线。

## VS Code 启动配置

可在 `.vscode/launch.json` 中使用以下配置。Mock 模式不传 `--dart-define`；AI 模式通过 VS Code 输入框传入 API Key，不在文件中写入真实密钥。

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "SchoNavi Flutter (mock)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart"
    },
    {
      "name": "SchoNavi Flutter (AI)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "toolArgs": [
        "--dart-define=LLM_API_KEY=${input:llmApiKey}",
        "--dart-define=LLM_BASE_URL=https://api.deepseek.com",
        "--dart-define=LLM_MODEL=deepseek-chat"
      ]
    }
  ],
  "inputs": [
    {
      "id": "llmApiKey",
      "type": "promptString",
      "description": "LLM API Key",
      "password": true
    }
  ]
}
```
