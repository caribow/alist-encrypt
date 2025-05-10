# ---- Stage 1: Build ----
# 使用 Node.js 镜像作为构建环境
FROM node:gallium-alpine AS builder

# 设置 node-proxy 的工作目录
WORKDIR /app/node-proxy

# 复制 package.json 和 package-lock.json (如果存在)
# 这可以利用 Docker 缓存，如果这些文件没变，就不重新安装依赖
COPY node-proxy/package.json ./
COPY node-proxy/package-lock.json ./

# 安装所有依赖 (包括 devDependencies，因为构建需要它们)
RUN npm install --legacy-peer-deps

# 复制 node-proxy 目录下的所有其他源代码
COPY node-proxy/ ./

# 运行 webpack 构建命令
RUN npm run webpack
# 现在 /app/node-proxy/dist 文件夹应该已经生成了

# ---- Stage 2: Production ----
# 使用一个轻量的 Node.js 镜像作为生产环境
FROM node:gallium-alpine

# 设置生产环境的工作目录
WORKDIR /opt/app

# 复制生产依赖所需的 package 文件
COPY node-proxy/package.json node-proxy/package-lock.json ./
# 只安装生产依赖
RUN npm install --production --legacy-peer-deps

# 从 builder 阶段复制构建好的 dist 文件夹内容
COPY --from=builder /app/node-proxy/dist .
# 现在 /opt/app 目录结构应该是：
# - index.js (来自 dist)
# - PRGAThreadCom.js (来自 dist)
# - public/ (来自 dist)
# - package.json (来自 dist, 由 PkgConfig 生成)
# - node_modules/ (由上面的 npm install --production 生成)

# 设置时区
RUN rm -rf /etc/localtime && ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

EXPOSE 5344

# 入口点指向 dist 目录中由 app.js 生成的 index.js
ENTRYPOINT ["node", "index.js"]