from typing import Any, Callable, Union

import gencodeutil

import datetime
import unittest


class TestParseIso8601(unittest.TestCase):
    def assert_same_when_decoded(
            self, obj: Union[datetime.date, datetime.time, datetime.datetime]
    ) -> None:
        self.assertEqual(gencodeutil._parse_iso8601(obj.isoformat()), obj)

    def test_now(self) -> None:
        self.assert_same_when_decoded(datetime.datetime.now())

    def test_utcnow(self) -> None:
        self.assert_same_when_decoded(datetime.datetime.utcnow())

    def test_zulu_datetime(self) -> None:
        dtm = datetime.datetime(1988, 11, 27, 4, tzinfo=datetime.timezone.utc)
        iso = '1988-11-27T04:00:00Z'
        self.assertEqual(gencodeutil._parse_iso8601(iso), dtm)
        self.assert_same_when_decoded(dtm)

    def test_datetime_separator_letter(self) -> None:
        dtm = datetime.datetime(1988, 11, 27, 4, tzinfo=datetime.timezone.utc)
        iso = '1988-11-27T04:00:00Z'
        self.assertEqual(gencodeutil._parse_iso8601(iso), dtm)
        self.assert_same_when_decoded(dtm)

    def test_datetime_separator_space(self) -> None:
        dtm = datetime.datetime(1988, 11, 27, 4, tzinfo=datetime.timezone.utc)
        iso = '1988-11-27 04:00:00Z'
        self.assertEqual(gencodeutil._parse_iso8601(iso), dtm)
        self.assert_same_when_decoded(dtm)

    def test_time_no_zone(self) -> None:
        tm = datetime.time(12, 31, 21)
        iso = '12:31:21'
        self.assertEqual(gencodeutil._parse_iso8601(iso), tm)
        self.assert_same_when_decoded(tm)

    def test_time_with_zulu(self) -> None:
        tm = datetime.time(12, 31, 21, tzinfo=datetime.timezone.utc)
        iso = '12:31:21Z'
        self.assertEqual(gencodeutil._parse_iso8601(iso), tm)
        self.assert_same_when_decoded(tm)

    def test_time_with_positive_offset(self) -> None:
        offset = datetime.timedelta(hours=4, minutes=2)
        tzinfo = datetime.timezone(offset)
        tm = datetime.time(1, 15, 32, microsecond=1500, tzinfo=tzinfo)
        iso = '01:15:32.0015+04:02'
        self.assertEqual(gencodeutil._parse_iso8601(iso), tm)
        self.assert_same_when_decoded(tm)

    def test_time_with_negative_offset(self) -> None:
        offset = -datetime.timedelta(hours=4, minutes=2)
        tzinfo = datetime.timezone(offset)
        tm = datetime.time(1, 15, 32, microsecond=1500, tzinfo=tzinfo)
        iso = '01:15:32.001500-04:02'
        self.assertEqual(gencodeutil._parse_iso8601(iso), tm)
        self.assert_same_when_decoded(tm)

    def test_empty_is_error(self) -> None:
        with self.assertRaises(Exception):
            gencodeutil._parse_iso8601('')

    def test_nonsense_is_error(self) -> None:
        with self.assertRaises(Exception):
            gencodeutil._parse_iso8601("This isn't date or time related.")

# TODO: Test to_jsonable and from_jsonable

if __name__ == '__main__':
    unittest.main()
