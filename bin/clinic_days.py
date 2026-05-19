#!/usr/bin/env python3
from datetime import date, timedelta

today = date.today()
last_day = date(2026, 6, 25)
end = last_day + timedelta(days=1)

mondays = sum(1 for i in range((end - today).days)
              if (today + timedelta(i)).weekday() == 0)
thursdays = sum(1 for i in range((end - today).days)
                if (today + timedelta(i)).weekday() == 3)

print(f"Until Thu Jun 25 2026 (last day): {mondays} Mondays, {thursdays} Thursdays ({mondays + thursdays} total)")
