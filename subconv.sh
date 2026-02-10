#!/usr/bin/env bash
set -e

OUT_DIR="CLIProxyAPI"
mkdir -p "$OUT_DIR"

echo "开始转换账号文件..."
echo "输出目录: $OUT_DIR"

HAS_JQ=0
HAS_PY=0

if command -v jq >/dev/null 2>&1; then
  HAS_JQ=1
else
  echo "未检测到 jq，尝试使用 python3..."
fi

if command -v python3 >/dev/null 2>&1; then
  HAS_PY=1
fi

if [ "$HAS_JQ" -eq 0 ] && [ "$HAS_PY" -eq 0 ]; then
  echo "错误：既没有 jq 也没有 python3，无法解析 JSON。"
  echo "请安装： sudo apt-get install jq 或 python3"
  exit 1
fi

for f in *.json; do
  [ -f "$f" ] || continue
  echo "处理文件: $f"

  if [ "$HAS_JQ" -eq 1 ]; then
    # 使用 jq 解析
    email=$(jq -r '.email' "$f")
    access_token=$(jq -r '.token.access_token' "$f")
    refresh_token=$(jq -r '.token.refresh_token' "$f")
    expires_in=$(jq -r '.token.expires_in' "$f")
    project_id=$(jq -r '.token.project_id' "$f")
    disabled=$(jq -r '.disabled' "$f")
    expiry_ts=$(jq -r '.token.expiry_timestamp' "$f")
    last_updated=$(jq -r '.quota.last_updated' "$f")

  else
    # 使用 python3 解析 JSON（作为回退方案）
    read email access_token refresh_token expires_in project_id disabled expiry_ts last_updated <<EOF
$(python3 - <<PY
import json,sys
j=json.load(open("$f"))
print(
    j["email"],
    j["token"]["access_token"],
    j["token"]["refresh_token"],
    j["token"]["expires_in"],
    j["token"]["project_id"],
    str(j["disabled"]).lower(),
    j["token"]["expiry_timestamp"],
    j["quota"]["last_updated"]
)
PY
)
EOF
  fi

  # 秒 -> 毫秒
  timestamp=$((last_updated * 1000))

  # 转为 +08:00 时间
  expired=$(TZ=Asia/Shanghai date -d "@$expiry_ts" +"%Y-%m-%dT%H:%M:%S%:z")

  # email 转文件名安全格式
  safe_email=$(echo "$email" | sed 's/[@.]/_/g')

  out_file="$OUT_DIR/antigravity-${safe_email}.json"

  cat > "$out_file" <<EOF
{
  "access_token": "$access_token",
  "disabled": $disabled,
  "email": "$email",
  "expired": "$expired",
  "expires_in": $expires_in,
  "project_id": "$project_id",
  "refresh_token": "$refresh_token",
  "timestamp": $timestamp,
  "type": "antigravity"
}
EOF

  echo "完成 -> $out_file"
done

echo "全部文件转换完成。"
