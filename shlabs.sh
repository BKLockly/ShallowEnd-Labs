#!/bin/bash
# Shallowend-Labs 环境管理脚本
# 生命周期: clean(清理) → up(启动) → inject(注入) → down(关闭)
#
# 环境自动发现：扫描 base/*/shlabs.yml，无硬编码环境表。
# shlabs.yml 约定（name/cve/port 必须是顶层标量，供本脚本 grep 解析）：
#   name: <别名>            # 可选，shlabs.sh 可用目录名或 name 定位
#   cve:  CVE-XXXX-YYYY
#   vuln: <一行漏洞描述>     # 可选，list/info 展示
#   port: <高位端口>
#   target: { kind: upstream|carrier, repo?, ref?, license? }
#   inject: { injector: <injectors/ 下的文件名>, endpoint: <路径> }
#   healthcheck: { path: / }
#
# 用法: ./shlabs.sh <command> [args...]

set -euo pipefail

LABS_ROOT="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$LABS_ROOT/base"
DEFAULT_KEY="mysecretkey"
WAIT_SECONDS="${SHLABS_WAIT:-60}"

# ── 环境发现与元信息 ────────────────────────────────────
yaml_field() {
    # yaml_field <shlabs.yml> <key> — 顶层标量；去引号，缺失输出空串
    local v=""
    v=$(grep -m1 -E "^${2}:" "$1" 2>/dev/null | sed -E "s/^${2}:[[:space:]]*//" | tr -d "\"'") || true
    printf '%s' "$v"
}

env_dirs() {
    local f
    shopt -s nullglob
    for f in "$BASE_DIR"/*/shlabs.yml; do
        dirname "${f#"$BASE_DIR"/}"
    done
    shopt -u nullglob
}

# 环境解析：优先目录名，其次 shlabs.yml name 别名；结果回写到 ENV_DIR
resolve_env() {
    local e="$1" d
    if [[ -f "$BASE_DIR/$e/shlabs.yml" ]]; then
        ENV_DIR="$e"
        return 0
    fi
    while IFS= read -r d; do
        if [[ "$(yaml_field "$BASE_DIR/$d/shlabs.yml" name)" == "$e" ]]; then
            ENV_DIR="$d"
            return 0
        fi
    done < <(env_dirs)
    return 1
}

env_port() { yaml_field "$BASE_DIR/$ENV_DIR/shlabs.yml" port; }
env_cve()  { yaml_field "$BASE_DIR/$ENV_DIR/shlabs.yml" cve; }
env_name() { yaml_field "$BASE_DIR/$ENV_DIR/shlabs.yml" name; }
env_vuln() { yaml_field "$BASE_DIR/$ENV_DIR/shlabs.yml" vuln; }

require_env() {
    if ! resolve_env "$ENV"; then
        echo "Error: unknown environment '$ENV'" >&2
        echo "Available:" >&2
        "$LABS_ROOT/shlabs.sh" list >&2
        exit 1
    fi
}

compose() {
    docker compose -f "$BASE_DIR/$ENV_DIR/docker-compose.yml" "$@"
}

# 构建失败（如 registry 不可达）时回退到本地缓存镜像
compose_up() {
    if compose up -d --build; then
        return 0
    fi
    local rc=$?
    echo "[!] Build failed (rc=$rc), falling back to cached image" >&2
    compose up -d
}

wait_healthy() {
    local url="$1" i
    for i in $(seq 1 "$WAIT_SECONDS"); do
        if curl -fsS -o /dev/null "$url/"; then return 0; fi
        sleep 1
    done
    return 1
}

usage() {
    cat <<EOF
Shallowend-Labs 环境管理脚本

生命周期:
  clean → up → inject → down

用法:
  ./shlabs.sh list                         列出所有可用环境（自动发现 base/*/shlabs.sh 同级元信息）
  ./shlabs.sh clean <env>                  清理环境（停止 + 删除容器/网络/卷/镜像）
  ./shlabs.sh up <env>                     启动环境（构建镜像 + 启动容器）
  ./shlabs.sh inject <env> [--key <key>] [--loader <file>]
                                           注入 payload（先过漏洞版本校验门）
  ./shlabs.sh test <env>                   全生命周期自测（clean → up → 健康检查 → inject → down）
  ./shlabs.sh down <env>                   关闭环境（停止并删除容器）
  ./shlabs.sh reset <env>                  重置环境（clean + up）
  ./shlabs.sh logs <env>                   查看日志
  ./shlabs.sh info <env>                   查看环境信息

env 可以是 base/ 下的目录名（如 CVE-2026-73649）或 shlabs.yml 的 name 别名。
EOF
}

CMD="${1:-help}"
ENV="${2:-}"

case "$CMD" in
    list|ls)
        echo "可用环境:"
        local_seen=0
        while IFS= read -r d; do
            ENV_DIR="$d"
            printf "  %-18s %-22s port %-5s %s\n" \
                "$d" "$(env_name)" "$(env_port)" "$(env_cve) $(env_vuln)"
            local_seen=1
        done < <(env_dirs)
        [[ "$local_seen" == "1" ]] || echo "  (none — base/ 下没有含 shlabs.yml 的环境)"
        ;;

    clean)
        require_env
        echo "[*] Cleaning $ENV_DIR (remove container/network/volume/image)..."
        compose down -v --rmi all
        echo "[+] $ENV_DIR cleaned"
        ;;

    up|start)
        require_env
        echo "[*] Starting $ENV_DIR..."
        compose_up
        echo "[+] $ENV_DIR started on http://127.0.0.1:$(env_port)"
        ;;

    down|stop)
        require_env
        echo "[*] Stopping $ENV_DIR..."
        compose down
        echo "[+] $ENV_DIR stopped"
        ;;

    reset)
        require_env
        echo "[*] Resetting $ENV_DIR (clean + up)..."
        compose down -v --rmi all
        compose_up
        echo "[+] $ENV_DIR reset — http://127.0.0.1:$(env_port)"
        ;;

    inject)
        require_env
        PORT=$(env_port)
        TARGET="http://127.0.0.1:$PORT"
        KEY="$DEFAULT_KEY"
        LOADER=""

        shift 2
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --key)     KEY="$2"; shift 2 ;;
                --loader)  LOADER="$2"; shift 2 ;;
                *) shift ;;
            esac
        done

        INJECT_SCRIPT="$BASE_DIR/$ENV_DIR/inject.sh"
        if [[ ! -x "$INJECT_SCRIPT" ]]; then
            echo "Error: inject.sh not found or not executable: $INJECT_SCRIPT" >&2
            exit 1
        fi

        ARGS=""
        [[ -n "$LOADER" ]] && ARGS="$ARGS --loader $LOADER"

        "$INJECT_SCRIPT" --target "$TARGET" --key "$KEY" $ARGS
        ;;

    test)
        require_env
        PORT=$(env_port)
        URL="http://127.0.0.1:$PORT"

        echo "========== [$ENV_DIR] 全生命周期自测 =========="
        echo "--- 1/4 clean ---"
        compose down -v --rmi all >/dev/null 2>&1 || true
        echo "[+] cleaned"

        echo "--- 2/4 up + 健康检查 ---"
        compose_up
        if ! wait_healthy "$URL"; then
            echo "[-] $ENV_DIR failed to become healthy within ${WAIT_SECONDS}s" >&2
            compose down
            exit 1
        fi
        echo "[+] up, HTTP 200 on $URL/"

        echo "--- 3/4 inject ---"
        "$BASE_DIR/$ENV_DIR/inject.sh" --target "$URL" --key "$DEFAULT_KEY"

        echo "--- 4/4 down ---"
        compose down
        echo "[+] down"
        echo "========== [$ENV_DIR] lifecycle test PASSED =========="
        ;;

    logs)
        require_env
        compose logs --tail=50 -f
        ;;

    info)
        require_env
        echo "Environment: $ENV_DIR"
        echo "  Name:        $(env_name)"
        echo "  CVE:         $(env_cve)"
        echo "  Vulnerability: $(env_vuln)"
        echo "  Port:        $(env_port)"
        echo "  URL:         http://127.0.0.1:$(env_port)"
        echo "  Default Key: $DEFAULT_KEY"
        ;;

    help|--help|-h|*)
        usage
        ;;
esac
