#!/bin/bash
# AI2 中文文档自动部署脚本
# 用法: ./scripts/auto-deploy.sh [commit_message]
#
# 功能：
# 1. 编译 Mintlify 静态站点
# 2. 推送到 GitHub Pages (fun123dotcn.github.io)
# 3. 自动检测代理配置

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== AI2 中文文档自动部署 ===${NC}"

# 配置
REPO_DIR="/Users/qpzhou/.qclaw/workspace/ai2-docs"
STATIC_DIR="$REPO_DIR/static_site"
GITHUB_REPO="https://github.com/fun123dotcn/fun123dotcn.github.io.git"
NODE20_PATH="/tmp/node-v20.18.0-darwin-arm64/bin/node"

# 检查代理
check_proxy() {
    if curl -s --proxy http://127.0.0.1:1087 -o /dev/null -w "%{http_code}" https://github.com | grep -q "200"; then
        echo -e "${GREEN}✓ 代理可用 (127.0.0.1:1087)${NC}"
        git config --global http.proxy http://127.0.0.1:1087
        git config --global https.proxy http://127.0.0.1:1087
        return 0
    else
        echo -e "${YELLOW}⚠ 代理不可用，尝试直连${NC}"
        git config --global --unset http.proxy 2>/dev/null || true
        git config --global --unset https.proxy 2>/dev/null || true
        return 1
    fi
}

# 检查 Node 20
check_node20() {
    if [ ! -f "$NODE20_PATH" ]; then
        echo -e "${YELLOW}下载 Node 20...${NC}"
        cd /tmp
        curl -sO https://nodejs.org/dist/v20.18.0/node-v20.18.0-darwin-arm64.tar.xz
        tar -xf node-v20.18.0-darwin-arm64.tar.xz
    fi
    echo -e "${GREEN}✓ Node 20 就绪${NC}"
}

# 编译静态站点
build_site() {
    echo -e "${YELLOW}编译中...${NC}"
    cd "$REPO_DIR"
    
    # 清理旧文件
    rm -rf static_site export.zip 2>/dev/null || true
    
    # 检查是否需要安装 mintlify
    if [ ! -d "node_modules/@mintlify" ]; then
        echo -e "${YELLOW}安装 Mintlify CLI...${NC}"
        PATH="/tmp/node-v20.18.0-darwin-arm64/bin:$PATH" \
        /tmp/node-v20.18.0-darwin-arm64/bin/node \
        /tmp/node-v20.18.0-darwin-arm64/lib/node_modules/npm/bin/npm-cli.js \
        install @mintlify/cli@4 --save-dev
    fi
    
    # 编译
    $NODE20_PATH node_modules/@mintlify/cli/bin/start.js export
    
    # 解压
    unzip -q export.zip -d static_site
    
    echo -e "${GREEN}✓ 编译完成${NC}"
}

# 部署到 GitHub Pages
deploy() {
    echo -e "${YELLOW}部署到 GitHub Pages...${NC}"
    
    cd "$STATIC_DIR"
    
    # 初始化 git
    git init 2>/dev/null || true
    git add .
    
    COMMIT_MSG="${1:-自动部署: $(date '+%Y-%m-%d %H:%M')}"
    git commit -m "$COMMIT_MSG" --allow-empty
    
    # 设置 remote
    git remote set-url origin "$GITHUB_REPO" 2>/dev/null || \
    git remote add origin "$GITHUB_REPO"
    
    # 推送
    git branch -M main
    git push -u origin main --force
    
    echo -e "${GREEN}✓ 部署完成${NC}"
    echo -e "${GREEN}访问: https://fun123dotcn.github.io/${NC}"
}

# 主流程
main() {
    check_proxy
    check_node20
    build_site
    deploy "$1"
}

main "$@"
