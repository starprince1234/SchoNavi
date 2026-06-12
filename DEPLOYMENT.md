# SchoNavi 部署说明

## 后端部署

后端由 `.github/workflows/deploy-backend.yml` 负责自动部署。

当前流程是：

1. GitHub Actions 拉取代码。
2. 在服务器上构建后端镜像。
3. 启动后端容器。
4. 保留服务器上的 `backend_agent/raw_data` 和 `backend_agent/data`。

服务器路径如下：

```text
/opt/schonavi
/opt/schonavi/backend_agent
/opt/schonavi/backend_agent/data/app.db
/opt/schonavi/backend_agent/data/chroma
/opt/schonavi/backend_agent/raw_data/*.db
```

## 环境变量

不要创建真实 `.env` 文件。

生产环境通过 Doppler 注入，常用配置项如下：

```text
PYTHON_BASE_IMAGE=m.daocloud.io/docker.io/library/python:3.12-slim
PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn
```

如果镜像源不可用，再在 Doppler `prd` 中替换。

## raw 数据文件

原始 SQLite 数据库文件不通过 GitHub Actions 上传，不参与自动部署。

请把它们手工放到服务器：

```text
/opt/schonavi/backend_agent/raw_data
```

## 推荐流程

如果你希望把向量库、图谱和 `app.db` 的构建压力放在本地，推荐这样做：

```powershell
.\scripts\build_backend_agent_data_local.ps1
.\scripts\upload_backend_agent_data.ps1
```

本地构建会生成：

```text
artifacts/backend_agent_data.tar.gz
```

上传脚本会把这个包安装到服务器的：

```text
/opt/schonavi/backend_agent/data
```

然后重启后端容器。

这条路线适合：

- raw 数据越来越多
- 向量库越来越大
- 云服务器 IO / 内存吃紧

## 服务器备用重建

如果你想在服务器上直接重建，也可以用备用脚本：

```bash
cd /opt/schonavi
./scripts/rebuild_backend_agent_indexes.sh
```

这个脚本不会要求你手工输入 Doppler token。

## 增量更新

向量索引是增量更新的：

- 没变化的条目会保留原来的 `vector_id`
- 新增或变化的条目会 `upsert` 到 Chroma

所以你以后只要：

1. 把新的 `raw_data/*.db` 放到本地或服务器
2. 重新跑本地构建脚本
3. 上传 `backend_agent_data.tar.gz`

就可以完成更新。

## 前端部署

Vercel 配置：

```text
Root Directory: web/frontend
Build Command: npm run build
Output Directory: dist
```

前端现在默认直接请求相对路径 `/api/...`，不再把后端地址写死在浏览器代码里。

线上部署时，`web/frontend/vercel.ts` 会在构建期读取环境变量并生成 rewrite：

- 优先读取 `BACKEND_ORIGIN`
- 没有时回退读取 `SERVER_HOST`
- 如果你只填了 IP 或主机名，默认会补成 `http://<host>:8000`
- 如果你直接填完整地址，也可以，例如 `https://api.example.com`

这意味着你可以把后端地址继续放在 Doppler 的 `prd` 里，再同步到 Vercel 构建环境。
浏览器本身不能直接读取 Doppler，所以真正生效的位置是 Vercel 的构建期，不是前端运行时。

补充说明：

- `VITE_API_BASE_URL` 不是必须项。当前前端默认走相对路径 `/api/...`，所以生产环境可以留空。
- `BACKEND_ORIGIN` 现在已经写入 Doppler 的 `prd`，值是 `8.156.88.100`。
- 你后续如果把后端换成域名，只需要更新 Doppler 和 Vercel 的同名值即可。

当前前端仓库已默认支持：

- 本地开发：Vite 代理到 `http://localhost:8000`
- 线上部署：Vercel 根据 `SERVER_HOST` / `BACKEND_ORIGIN` 生成 rewrite

## 备注

如果你只想更新后端代码，不需要重建索引，直接跑 workflow 即可。
如果你更新了 raw 数据并且想让新数据生效，走“本地构建 + 上传 data 包”这条路线最稳。
