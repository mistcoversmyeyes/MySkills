"""
init-report.py — 报告初始化辅助脚本

确定性操作：解析日期/周数、定位历史日报、输出正确的文件路径。
供 Report Maker agents 调用，避免 LLM 重复计算日期逻辑。

用法：
    python init-report.py --type daily --report-dir <report目录路径>
    python init-report.py --type weekly --report-dir <report目录路径>

输出（JSON）：
    {
        "today": "4.30",
        "week_number": 3,
        "week_dir": "第3周",
        "target_path": "report/第3周/4.30 日报.md",
        "latest_daily": "report/第2周/4.29 日报.md",
        "this_week_dailies": ["report/第3周/4.28 日报.md", ...]
    }
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path


def find_project_start_date(report_dir: Path) -> datetime:
    """从 report/ 目录下最早的日报文件推断项目起始日期（第一周的周一）。"""
    earliest = None
    pattern = re.compile(r"(\d{1,2})\.(\d{2})\s*日报\.md$")

    for root, dirs, files in os.walk(report_dir):
        for f in files:
            m = pattern.search(f)
            if m:
                month, day = int(m.group(1)), int(m.group(2))
                # 假设当前年份
                year = datetime.now().year
                try:
                    date = datetime(year, month, day)
                    if earliest is None or date < earliest:
                        earliest = date
                except ValueError:
                    continue

    if earliest is None:
        # 找不到任何日报，以当前周一为第一周起始
        today = datetime.now()
        return today - timedelta(days=today.weekday())

    # 返回最早日报所在周的周一
    return earliest - timedelta(days=earliest.weekday())


def get_week_number(project_start_monday: datetime, target_date: datetime) -> int:
    """计算 target_date 是项目的第几周（从 1 开始）。"""
    delta_days = (target_date - project_start_monday).days
    return delta_days // 7 + 1


def number_to_chinese(n: int) -> str:
    """将正整数转为中文数字（支持 1-99）。"""
    digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    if n <= 0:
        return str(n)
    if n < 10:
        return digits[n]
    if n == 10:
        return "十"
    if n < 20:
        return f"十{digits[n - 10]}"
    if n < 100:
        tens, ones = divmod(n, 10)
        return f"{digits[tens]}十" + (digits[ones] if ones else "")
    return str(n)


def find_latest_daily(report_dir: Path) -> str | None:
    """找到 report/ 下最新的日报文件路径。"""
    pattern = re.compile(r"(\d{1,2})\.(\d{2})\s*日报\.md$")
    all_dailies = []

    for root, dirs, files in os.walk(report_dir):
        for f in files:
            m = pattern.search(f)
            if m:
                month, day = int(m.group(1)), int(m.group(2))
                year = datetime.now().year
                try:
                    date = datetime(year, month, day)
                    full_path = os.path.join(root, f)
                    all_dailies.append((date, full_path))
                except ValueError:
                    continue

    if not all_dailies:
        return None

    all_dailies.sort(key=lambda x: x[0], reverse=True)
    return all_dailies[0][1]


def find_this_week_dailies(report_dir: Path, week_dir_name: str) -> list[str]:
    """找到本周目录下所有日报文件。"""
    week_path = report_dir / week_dir_name
    if not week_path.exists():
        return []

    pattern = re.compile(r"\d{1,2}\.\d{2}\s*日报\.md$")
    dailies = []
    for f in sorted(week_path.iterdir()):
        if pattern.search(f.name):
            dailies.append(str(f))

    return dailies


def main():
    parser = argparse.ArgumentParser(description="报告初始化辅助脚本")
    parser.add_argument("--type", choices=["daily", "weekly"], required=True,
                        help="报告类型")
    parser.add_argument("--report-dir", required=True,
                        help="report/ 目录路径")
    parser.add_argument("--date", default=None,
                        help="目标日期，格式 M.DD（默认为今天）")
    args = parser.parse_args()

    report_dir = Path(args.report_dir)
    if not report_dir.exists():
        print(json.dumps({"error": f"report目录不存在: {report_dir}"}), file=sys.stderr)
        sys.exit(1)

    # 解析目标日期
    today = datetime.now()
    if args.date:
        m = re.match(r"(\d{1,2})\.(\d{2})$", args.date)
        if m:
            today = datetime(today.year, int(m.group(1)), int(m.group(2)))
        else:
            print(json.dumps({"error": f"日期格式无效: {args.date}，应为 M.DD"}), file=sys.stderr)
            sys.exit(1)

    # 计算周数
    project_start = find_project_start_date(report_dir)
    week_number = get_week_number(project_start, today)
    week_dir_name = f"第{number_to_chinese(week_number)}周"

    # 格式化日期字符串
    date_str = f"{today.month}.{today.day:02d}"

    # 构建输出
    result = {
        "today": date_str,
        "week_number": week_number,
        "week_dir": week_dir_name,
    }

    if args.type == "daily":
        target_path = str(report_dir / week_dir_name / f"{date_str} 日报.md")
        result["target_path"] = target_path
        result["latest_daily"] = find_latest_daily(report_dir)
    elif args.type == "weekly":
        target_path = str(report_dir / week_dir_name / f"{week_dir_name} 周报.md")
        result["target_path"] = target_path
        result["this_week_dailies"] = find_this_week_dailies(report_dir, week_dir_name)

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
