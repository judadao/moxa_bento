"""Strict parsing of the observed FoodCourt reservation table; no network writes."""
from datetime import date, datetime, timedelta, timezone
from html.parser import HTMLParser
import re

TAIPEI = timezone(timedelta(hours=8))
WEEKDAYS = "一二三四五"
HEADERS = ("用餐日期", "餐別", "訂餐內容", "費用方式", "地點", "操作")


class UnrecognizedPage(ValueError):
    pass


class FoodCourtHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tables = []
        self.table = None
        self.row = None
        self.cell = None
        self.select = False
        self.option = None
        self.option_value = ""
        self.options = []
        self.logged_in = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if attrs.get("id") == "btnLogout":
            self.logged_in = True
        if tag == "table":
            self.table = []
        elif tag == "tr" and self.table is not None:
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = []
        elif tag == "select" and attrs.get("id") == "targetDay":
            self.select = True
        elif tag == "option" and self.select:
            self.option = []
            self.option_value = attrs.get("value", "")
        elif tag == "br" and self.cell is not None:
            self.cell.append(" / ")

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)
        if self.option is not None:
            self.option.append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.table.append(self.row)
            self.row = None
        elif tag == "table" and self.table is not None:
            self.tables.append(self.table)
            self.table = None
        elif tag == "option" and self.option is not None:
            self.options.append(self.option_value if re.fullmatch(r"\d{4}-\d{2}-\d{2}", self.option_value) else "".join(self.option).strip())
            self.option = None
        elif tag == "select":
            self.select = False


def option_date(text, today):
    full = re.search(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})", text)
    if full:
        return date(*map(int, full.groups()))
    short = re.search(r"(\d{1,2})/(\d{1,2})", text)
    if not short:
        return None
    month, day = map(int, short.groups())
    candidates = []
    for year in (today.year - 1, today.year, today.year + 1):
        try:
            candidates.append(date(year, month, day))
        except ValueError:
            pass
    return min(candidates, key=lambda d: abs((d - today).days)) if candidates else None


def parse_reservations(html, today):
    page = FoodCourtHTML()
    page.feed(html)
    if not page.logged_in:
        raise UnrecognizedPage("請先登入公司訂餐系統")
    matches = [t for t in page.tables if t and tuple(t[0]) == HEADERS]
    if len(matches) != 1 or not page.options:
        raise UnrecognizedPage("網站欄位無法辨識，暫時無法確認訂餐")
    available = {d for text in page.options if (d := option_date(text, today))}
    if not available:
        raise UnrecognizedPage("無法辨識可預約日期")
    lunches = set()
    reservations = []
    for row in matches[0][1:]:
        # The known empty-state row is safe only with an explicit empty message.
        if len(row) == 1 and re.fullmatch(r"(?:目前)?(?:尚無|沒有|無)(?:任何)?(?:預約|訂餐)?(?:資料|紀錄|記錄)", row[0]):
            continue
        if len(row) != len(HEADERS):
            raise UnrecognizedPage("預約清單格式有變動，暫停漏訂判斷")
        match = re.search(r"\d{4}-\d{2}-\d{2}", row[0])
        if not match or not row[1] or not row[2]:
            raise UnrecognizedPage("預約資料不完整，暫停漏訂判斷")
        if "午餐" in row[1]:
            day = date.fromisoformat(match.group())
            lunches.add(day)
            content = re.sub(r"^訂餐內容\s*[：:]\s*", "", row[2]).strip(" / ")
            reservations.append({"date": day.isoformat(), "meal_type": row[1],
                                 "content": content, "location": row[4]})
    return available, lunches, reservations


def parse_orders(html, today):
    available, lunches, _ = parse_reservations(html, today)
    return available, lunches


def week_status(available, lunches, today, offset=0):
    monday = today - timedelta(days=today.weekday()) + timedelta(weeks=offset)
    result = []
    for index in range(5):
        day = monday + timedelta(days=index)
        status = ("past" if day < today else "ordered" if day in lunches
                  else "missing" if day in available else "unknown")
        result.append({"date": day.isoformat(), "weekday": WEEKDAYS[index], "status": status})
    return result


def snapshot(html, today=None):
    today = today or datetime.now(TAIPEI).date()
    available, lunches, reservations = parse_reservations(html, today)
    return {"status": "ok", "checked_at": datetime.now(TAIPEI).isoformat(),
            "today": today.isoformat(),
            "today_lunch": [r for r in reservations if r["date"] == today.isoformat()],
            "weeks": [week_status(available, lunches, today, i) for i in (0, 1)]}
