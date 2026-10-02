from datetime import date
import unittest

from companion.orders import HEADERS, UnrecognizedPage, parse_orders, snapshot, option_date, week_status


def page(rows=(), options=("2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07", "2026-10-08", "2026-10-09")):
    # Reproduces the observed .booked table; all meal content is synthetic.
    select = '<select id="targetDay">' + "".join(f'<option value="{d}">{d}</option>' for d in options) + '</select>'
    table = "<table class='table booked'><tbody><tr>" + "".join(f"<td>{h}</td>" for h in HEADERS) + "</tr>"
    table += "".join("<tr>" + "".join(f"<td>{cell}</td>" for cell in row) + "</tr>" for row in rows)
    return '<input id="btnLogout" type="button">' + select + table + '</tbody></table>'


def meal(day, kind="午餐"):
    return [day + " (星期五)", "便當屋-" + kind, "<span>訂餐內容：</span>測試餐 * 1<br>", "自費:100", "總部", ""]


class OrdersTest(unittest.TestCase):
    def test_current_day_and_next_week(self):
        result = snapshot(page([meal("2026-10-02")]), date(2026, 10, 2))
        self.assertEqual([d['status'] for d in result['weeks'][0]], ['past'] * 4 + ['ordered'])
        self.assertEqual([d['status'] for d in result['weeks'][1]], ['missing'] * 5)

    def test_single_missing_day(self):
        available = {date(2026, 10, i) for i in range(5, 10)}
        lunches = available - {date(2026, 10, 7)}
        days = week_status(available, lunches, date(2026, 10, 5))
        self.assertEqual([d['weekday'] for d in days if d['status'] == 'missing'], ['三'])

    def test_dinner_does_not_count(self):
        available, lunches = parse_orders(page([meal('2026-10-05', '晚餐')]), date(2026, 10, 5))
        self.assertIn(date(2026, 10, 5), available)
        self.assertEqual(lunches, set())

    def test_unavailable_date_is_unknown(self):
        days = week_status(set(), set(), date(2026, 10, 5))
        self.assertTrue(all(d['status'] == 'unknown' for d in days))

    def test_empty_orders_are_missing_only_on_available_days(self):
        result = snapshot(page(), date(2026, 10, 5))
        self.assertTrue(all(d['status'] == 'missing' for d in result['weeks'][0]))

    def test_login_page_never_means_missing(self):
        with self.assertRaises(UnrecognizedPage):
            parse_orders('<html>Sign in to Microsoft</html>', date(2026, 10, 5))

    def test_changed_headers_fail_closed(self):
        with self.assertRaises(UnrecognizedPage):
            parse_orders(page().replace('用餐日期', '日期'), date(2026, 10, 5))

    def test_truncated_row_fails_closed(self):
        with self.assertRaises(UnrecognizedPage):
            parse_orders(page([['2026-10-05', '午餐']]), date(2026, 10, 5))

    def test_missing_date_picker_fails_closed(self):
        with self.assertRaises(UnrecognizedPage):
            parse_orders(page(options=[]), date(2026, 10, 5))

    def test_year_rollover(self):
        self.assertEqual(option_date('1/2 (週五)', date(2026, 12, 30)), date(2027, 1, 2))
        days = week_status(set(), set(), date(2026, 12, 30), 1)
        self.assertEqual(days[0]['date'], '2027-01-04')

    def test_weekend_does_not_remind_past_days(self):
        days = week_status({date(2026, 10, 2)}, set(), date(2026, 10, 3))
        self.assertTrue(all(d['status'] == 'past' for d in days))

    def test_multiple_lunches_same_date(self):
        _, lunches = parse_orders(page([meal('2026-10-05'), meal('2026-10-05')]), date(2026, 10, 5))
        self.assertEqual(lunches, {date(2026, 10, 5)})

    def test_today_menu_excludes_dinner_and_other_days(self):
        result = snapshot(page([meal('2026-10-05'), meal('2026-10-05', '晚餐'), meal('2026-10-06')]), date(2026, 10, 5))
        self.assertEqual(len(result['today_lunch']), 1)
        self.assertEqual(result['today_lunch'][0]['content'], '測試餐 * 1')
        self.assertEqual(result['today_lunch'][0]['location'], '總部')

    def test_today_multiple_meals_keep_their_content(self):
        result = snapshot(page([meal('2026-10-05'), meal('2026-10-05')]), date(2026, 10, 5))
        self.assertEqual(len(result['today_lunch']), 2)


if __name__ == '__main__':
    unittest.main()
