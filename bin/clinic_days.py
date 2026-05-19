#!/usr/bin/env python3
from datetime import date, timedelta

today = date.today()
end = date(2026, 7, 1)

mondays = sum(1 for i in range((end - today).days)
              if (today + timedelta(i)).weekday() == 0)
thursdays = sum(1 for i in range((end - today).days)
                if (today + timedelta(i)).weekday() == 3)

print(f"Until July 1 2026: {mondays} Mondays, {thursdays} Thursdays ({mondays + thursdays} total)")
